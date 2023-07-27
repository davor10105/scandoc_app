import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:dmrtd/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import 'package:scandoc_app/main.dart';
import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/settings.dart';
import 'package:scandoc_app/utils/buttons.dart';
import 'package:scandoc_app/utils/camerascan_rectangle.dart';
import 'package:scandoc_app/utils/image_functions.dart';

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({
    super.key,
  });

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  bool processingImage = false;
  AnalysisController? analysisController;
  var frontDocumentImage;
  var backDocumentImage;

  var needsFlip = false;
  var successExtraction = false;
  int consecutiveValidationSuccess = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    super.dispose();
    analysisController?.close();
  }

  // reset current variables
  void _resetCurrentState() {
    setState(() {
      processingImage = false;
      frontDocumentImage = null;
      backDocumentImage = null;
      needsFlip = false;
      successExtraction = false;
      consecutiveValidationSuccess = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    ScanDocAppState appState = context.watch<ScanDocAppState>();

    // create image stream to main scandoc service
    return CameraAwesomeBuilder.previewOnly(
      previewFit: CameraPreviewFit.cover,
      onImageForAnalysis: (img) => _analyzeImage(img, appState),
      imageAnalysisConfig: AnalysisConfig(
        androidOptions: const AndroidAnalysisOptions.jpeg(
          width: 1024,
        ),
        maxFramesPerSecond: 1,
      ),
      builder: (state, previewSize, previewRect) {
        analysisController = state.analysisController;
        // include document rectangle and button to return
        return Stack(
          children: [
            RectangleDisplay(
              needsFlip: needsFlip,
              successExtraction: successExtraction,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ReturnButton(
                  appState: appState,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future _analyzeImage(
      AnalysisImage analysisImage, ScanDocAppState appState) async {
    if (processingImage) return;
    processingImage = true;
    await analysisImage.when(
        jpeg: (JpegImage image) async {
          ScanDocInputImage inputImage = ScanDocInputImage(
              imageHex: image.bytes.hex(),
              rotationAngle: getAngle(image.rotation));
          try {
            print(consecutiveValidationSuccess);
            dynamic result = await callValidation(inputImage);
            var jsonValidationResult = jsonDecode(result.body);
            print(jsonValidationResult);
            if (jsonValidationResult['Status'] == 200 &&
                jsonValidationResult['Validated']) {
              if (consecutiveValidationSuccess >= 2) {
                consecutiveValidationSuccess = 0;
                if (jsonValidationResult['Side'] == 'FRONT') {
                  frontDocumentImage = inputImage;
                } else {
                  backDocumentImage = inputImage;
                }
                if (jsonValidationResult['InfoCode'] == '1007') {
                  if (frontDocumentImage == null || backDocumentImage == null) {
                    print('Flip the document');
                    if (!needsFlip) {
                      setState(() {
                        needsFlip = true;
                      });
                    }
                  } else {
                    await _processFrontBack(appState);
                  }
                } else if (jsonValidationResult['InfoCode'] == '1000') {
                  await _processFrontBack(appState);
                }
              } else {
                consecutiveValidationSuccess += 1;
              }
            } else {
              consecutiveValidationSuccess = 0;
            }
          } catch (e) {
            print(e);
            print('No validation endpoint');
          }
        },
        yuv420: (Yuv420Image image) {
          //return handleYuv420( image);
        },
        nv21: (Nv21Image image) async {},
        bgra8888: (Bgra8888Image image) {
          //return handleBgra8888(image);
        });
    processingImage = false;
  }

  Future<http.Response> callValidation(ScanDocInputImage inputImage) {
    print("Call validation");
    return http.post(
      Uri.parse('$SCANDOC_URL/validation/'),
      headers: <String, String>{
        'Authorization': 'TOKEN',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'AcceptTermsAndConditions': true,
        'DataFields': {
          'Images': [inputImage.imageHex],
          'ImageMetadata': {
            'Type': 'bytes',
            'Rotation': 360 - inputImage.rotationAngle,
          },
        },
        'Settings': {
          'SkipImageSizeCheck': true,
        }
      }),
    );
  }

  Future<http.Response> callExtraction(ScanDocInputImage? frontDocumentImage,
      ScanDocInputImage? backDocumentImage) {
    print("Call extraction");
    bool shouldSendBackImage = !(backDocumentImage == null);
    return http.post(
      Uri.parse('$SCANDOC_URL/extraction/'),
      headers: <String, String>{
        'Authorization': 'TOKEN',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'AcceptTermsAndConditions': true,
        'DataFields': {
          'BackImage': shouldSendBackImage ? backDocumentImage.imageHex : '',
          'BackImageCropped': false,
          'BackImageType': 'bytes',
          'BackImageRotation': shouldSendBackImage
              ? 360 - backDocumentImage.rotationAngle
              : null,
          'FrontImage': frontDocumentImage!.imageHex,
          'FrontImageCropped': false,
          'FrontImageType': 'bytes',
          'FrontImageRotation': 360 - frontDocumentImage.rotationAngle,
        },
        'Settings': {
          'IgnoreBackImage': !shouldSendBackImage,
          'ShouldReturnDocumentImage': true,
          'ShouldReturnFaceIfDetected': true,
          'ShouldReturnSignatureIfDetected': true,
          'ShouldValidate': true,
          'SkipImageSizeCheck': true,
          'SkipDocumentSizeCheck': true,
        },
      }),
    );
  }

  Future _processFrontBack(ScanDocAppState appState) async {
    setState(() {
      successExtraction = true;
    });
    var extractionResult =
        await callExtraction(frontDocumentImage, backDocumentImage);
    frontDocumentImage = null;
    backDocumentImage = null;
    dynamic jsonExtractionResult = jsonDecode(extractionResult.body);
    if (jsonExtractionResult['Status'] == 200) {
      appState.setCurrentExtractionResult(jsonExtractionResult);
      appState.setCurrentPage(Pages.NFCSCAN);
    } else {
      // TODO: implement a way of informing the user
      _resetCurrentState();
      print('Could not read document, please try againg');
    }
  }
}
