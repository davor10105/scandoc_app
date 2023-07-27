import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:dmrtd/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scandoc_app/constants/constants.dart';

import 'package:scandoc_app/main.dart';
import 'package:scandoc_app/utils/face_oval.dart';
import 'package:scandoc_app/utils/image_functions.dart';

class FaceScanPage extends StatefulWidget {
  const FaceScanPage({super.key});

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage> {
  bool processingImage = false;
  AnalysisController? analysisController;
  int consecutiveFaceSuccess = 0;
  Sensors currentSensor = Sensors.back;

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

  void _resetCurrentState() {
    setState(() {
      processingImage = false;
      consecutiveFaceSuccess = 0;
    });
  }

  void _addFaceScanData(ScanDocAppState appState) {
    // TODO: add face validation results to appState.currentExtractionResult
  }

  Future<void> _analyzeImage(
      AnalysisImage analysisImage, ScanDocAppState appState) async {
    if (processingImage) return;
    processingImage = true;
    await analysisImage.when(jpeg: (JpegImage image) async {
      ScanDocInputImage inputImage = ScanDocInputImage(
        imageHex: image.bytes.hex(),
        rotationAngle: getAngle(image.rotation),
      );

      // TODO: send captured image and NFC (or document) face image to face recognition endpoint
    });
    processingImage = false;
  }

  @override
  Widget build(BuildContext context) {
    ScanDocAppState appState = context.watch<ScanDocAppState>();
    return CameraAwesomeBuilder.previewOnly(
        sensor: currentSensor,
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
              const FaceDisplay(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FloatingActionButton(
                        onPressed: () {
                          setState(() {
                            state.switchCameraSensor();
                          });
                        },
                        child: const Icon(Icons.flip_camera_ios),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FloatingActionButton(
                        onPressed: () {
                          _addFaceScanData(appState);
                          appState.setCurrentPage(Pages.RESULTS);
                        },
                        child: const Icon(Icons.forward),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        });
  }
}
