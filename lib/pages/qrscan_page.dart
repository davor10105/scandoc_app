import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:provider/provider.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/main.dart';
import 'package:scandoc_app/settings.dart';
import 'package:scandoc_app/utils/buttons.dart';
import 'package:scandoc_app/utils/image_functions.dart';
import 'package:http/http.dart' as http;
import 'package:scandoc_app/utils/qrscan_rectangle.dart';
import 'package:uuid/uuid.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  AnalysisController? analysisController;
  bool processingImage = false;
  final _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  @override
  Widget build(BuildContext context) {
    ScanDocAppState appState = context.watch<ScanDocAppState>();

    return CameraAwesomeBuilder.previewOnly(
      previewFit: CameraPreviewFit.cover,
      onImageForAnalysis: (img) => _analyzeQRImage(img, appState),
      imageAnalysisConfig: AnalysisConfig(
        androidOptions: const AndroidAnalysisOptions.nv21(
          width: 1024,
        ),
        maxFramesPerSecond: 5,
      ),
      builder: (state, previewSize, previewRect) {
        analysisController = state.analysisController;
        return Stack(
          children: [
            RectangleQRDisplay(),
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

  Future _connectToWeb(ScanDocAppState appState) async {
    print("Connect to web");
    String currentQRUUID = appState.currentQRUUID!;
    print(SCANDOC_WEB_URL);
    print('${SCANDOC_WEB_URL}/share/connect/$currentQRUUID');
    return http.post(
      Uri.parse('$SCANDOC_WEB_URL/share/connect/$currentQRUUID'),
      headers: <String, String>{
        'Accept': 'application/json',
      },
      body: {},
    );
  }

  Future _analyzeQRImage(
      AnalysisImage analysisImage, ScanDocAppState appState) async {
    if (processingImage) return;
    processingImage = true;
    await analysisImage.when(
        jpeg: (JpegImage image) async {},
        yuv420: (Yuv420Image image) {
          //return handleYuv420( image);
        },
        nv21: (Nv21Image image) async {
          //return handleJpeg(image);

          //print('KITA');
          //print(image.width);
          //var dartImage = img.decodeImage(image.bytes);
          var angle = getAngle(image.rotation);
          //print(image.rotation);
          //dartImage = img.copyRotate(dartImage!, angle: angle);
          print('Usao u qr');
          print(image.width);
          print(image.height);

          try {
            var inputImage = InputImage.fromBytes(
              bytes: image.bytes,
              metadata: InputImageMetadata(
                size: Size(image.width.toDouble(), image.height.toDouble()),
                rotation: InputImageRotationValue.fromRawValue(
                    angle)!, // used only in Android
                format: InputImageFormat.nv21, // used only in iOS
                bytesPerRow: image.planes.first.bytesPerRow, // used only in iOS
              ),
            );
            var recognizedBarCodes =
                await _barcodeScanner.processImage(inputImage);
            for (Barcode barcode in recognizedBarCodes) {
              var qrUUID = Uuid.unparse(Uuid.parse(barcode.rawValue!));
              appState.setCurrentQRUUID(qrUUID);
              await _connectToWeb(appState);
              print("Connected with UUID: ${qrUUID}");
              appState.setCurrentPage(Pages.HOMEPAGE);
            }
          } catch (error) {
            print("...sending image resulted error $error");
          }
        },
        bgra8888: (Bgra8888Image image) {
          //return handleBgra8888(image);
        });
    processingImage = false;
  }
}
