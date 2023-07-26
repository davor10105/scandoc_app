import 'dart:async';
import 'dart:math';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:scandoc_app/pages/camerascan_page.dart';
import 'package:scandoc_app/pages/homepage.dart';
import 'package:scandoc_app/utils/image_functions.dart';
import 'package:uuid/uuid.dart';

import 'package:expandable/expandable.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../lib/constants/constants.dart';

String formatEfCom(final EfCOM efCom) {
  var str = "version: ${efCom.version}\n"
      "unicode version: ${efCom.unicodeVersion}\n"
      "DG tags:";

  for (final t in efCom.dgTags) {
    try {
      str += " ${dgTagToString[t]!}";
    } catch (e) {
      str += " 0x${t.value.toRadixString(16)}";
    }
  }
  return str;
}

String formatMRZ(final MRZ mrz) {
  return "MRZ\n"
          "  version: ${mrz.version}\n" +
      "  doc code: ${mrz.documentCode}\n" +
      "  doc No.: ${mrz.documentNumber}\n" +
      "  country: ${mrz.country}\n" +
      "  nationality: ${mrz.nationality}\n" +
      "  name: ${mrz.firstName}\n" +
      "  surname: ${mrz.lastName}\n" +
      "  gender: ${mrz.gender}\n" +
      "  date of birth: ${DateFormat.yMd().format(mrz.dateOfBirth)}\n" +
      "  date of expiry: ${DateFormat.yMd().format(mrz.dateOfExpiry)}\n" +
      "  add. data: ${mrz.optionalData}\n" +
      "  add. data: ${mrz.optionalData2}";
}

String formatDG15(final EfDG15 dg15) {
  var str = "EF.DG15:\n"
      "  AAPublicKey\n"
      "    type: ";

  final rawSubPubKey = dg15.aaPublicKey.rawSubjectPublicKey();
  if (dg15.aaPublicKey.type == AAPublicKeyType.RSA) {
    final tvSubPubKey = TLV.fromBytes(rawSubPubKey);
    var rawSeq = tvSubPubKey.value;
    if (rawSeq[0] == 0x00) {
      rawSeq = rawSeq.sublist(1);
    }

    final tvKeySeq = TLV.fromBytes(rawSeq);
    final tvModule = TLV.decode(tvKeySeq.value);
    final tvExp = TLV.decode(tvKeySeq.value.sublist(tvModule.encodedLen));

    str += "RSA\n"
        "    exponent: ${tvExp.value.hex()}\n"
        "    modulus: ${tvModule.value.hex()}";
  } else {
    str += "EC\n    SubjectPublicKey: ${rawSubPubKey.hex()}";
  }
  return str;
}

String formatProgressMsg(String message, int percentProgress) {
  final p = (percentProgress / 20).round();
  final full = "🟢 " * p;
  final empty = "⚪️ " * (5 - p);
  return message + "\n\n" + full + empty;
}

void main() {
  runApp(const CameraAwesomeApp());
}

class CameraAwesomeApp extends StatelessWidget {
  const CameraAwesomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      title: 'camerAwesome App',
      theme: ThemeData(
        primaryColor: Colors.lightBlue[800],

        // Define the default font family.
        fontFamily: 'Roboto',

        // Define the default `TextTheme`. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        textTheme: const TextTheme(
            displayLarge: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            titleLarge: TextStyle(fontSize: 36, fontStyle: FontStyle.italic),
            bodyMedium: TextStyle(
              fontSize: 18,
            ),
            bodySmall: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 99, 135, 255))),
      ),
      home: CameraPage(),
    );
  }
}

class ScanDocAppState extends ChangeNotifier {
  // stores data used between pages
  Pages currentPage = Pages.HOMEPAGE;
  dynamic currentExtractionResult;
  List<dynamic> storedExtractionData = [];

  void setCurrentPage(Pages newPage) {
    currentPage = newPage;
    notifyListeners();
  }

  void setCurrentExtractionResult(dynamic newExtractionResult) {
    currentExtractionResult = newExtractionResult;
    notifyListeners();
  }

  void storeExtractionData(dynamic extractionData) {
    storedExtractionData.add(extractionData);
    notifyListeners();
  }

  // resets the "current" type variables and enables a new scan
  void resetCurrentData() {
    currentExtractionResult = null;
    currentPage = Pages.HOMEPAGE;
    notifyListeners();
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  //var currentExtractionResult;
  var processingImage = false;
  var runningCamera = true;
  AnalysisController? analysisController;
  var progressValue = 0.0;
  var nfcStatusText = '';
  //Pages currentPage = Pages.HOMEPAGE;
  var needsFlip = false;
  var successExtraction = false;
  int consecutiveValidationSuccess = 0;
  bool enableSaveButton = true;
  dynamic currentQR;

  final _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  //var storedExtractionData = [];

  void resetState() {
    setState(() {
      processingImage = false;
      //currentExtractionResult = null;
      runningCamera = true;
      progressValue = 0.0;
      _mrtdData = null;
      nfcStatusText = '';
      var _docNumber = null;
      var _dob = null;
      var _doe = null;
      //currentPage = Pages.HOMEPAGE;
      needsFlip = false;
      successExtraction = false;
      consecutiveValidationSuccess = 0;
      enableSaveButton = true;
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  List<Widget> _extractionResultList() {
    List<Widget> retVal = [];

    if (currentExtractionResult['ImageData']['FaceImage'] != null) {
      var faceImage = Image.memory(
        base64Decode(currentExtractionResult['ImageData']['FaceImage']),
        height: 150,
        fit: BoxFit.fill,
        //gaplessPlayback: true,
      );
      var faceContainer = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          child: faceImage,
        ),
      );
      retVal.add(faceContainer);
    }

    for (var key in keyTranslateMap.keys) {
      var value = currentExtractionResult['Data'][key]['RecommendedValue'];
      if (value != null) {
        //var nfcValue = _mrtdData.dg1.mrz.
        bool validated = currentExtractionResult['Data'][key]
                ['RecommendedValue'] ==
            currentExtractionResult['Data'][key]['NFC']['Value'];
        Widget listElement = SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color.fromARGB(50, 0, 0, 0),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: SingleChildScrollView(
                child: ExpandablePanel(
                  header: Row(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              keyTranslateMap[key].toString().toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              currentExtractionResult['Data'][key]
                                  ['RecommendedValue'],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: validated
                          ? [
                              Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                            ]
                          : [
                              Icon(
                                Icons.close,
                                color: Colors.red,
                              ),
                              Text(
                                'Unverified',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                    ),
                  ]),
                  collapsed: Text(''),
                  expanded: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        for (var sourceKey in ['OCR', 'MRZ', 'NFC'])
                          if (currentExtractionResult['Data'][key][sourceKey]
                                  ['Value'] !=
                              null)
                            Row(
                              children: [
                                Text(
                                  '${sourceKey}: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.lightBlue,
                                  ),
                                ),
                                Flexible(
                                  child: Text(currentExtractionResult['Data']
                                      [key][sourceKey]['Value']),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        retVal.add(listElement);
      }
    }

    if (currentExtractionResult['ImageData']['Signature'] != null) {
      var signatureImage = Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIGNATURE',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  child: Image.memory(
                    base64Decode(
                        currentExtractionResult['ImageData']['Signature']),
                    height: 50,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      retVal.add(signatureImage);
    }

    if (currentExtractionResult['ImageData']['Documents'] != null) {
      List<Widget> documentImageWidgets = [];
      documentImageWidgets.add(
        Text(
          'DOCUMENT IMAGES',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
      for (var documentImageBase64 in currentExtractionResult['ImageData']
          ['Documents']) {
        var documentImage = Padding(
          padding: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  child: Image.memory(
                    base64Decode(documentImageBase64),
                    width: double.infinity,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
        );

        documentImageWidgets.add(documentImage);
      }
      retVal.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: documentImageWidgets,
      ));
    }

    return retVal;
  }

  @override
  Widget build(BuildContext context) {
    /*if (analysisController != null) {
      if (analysisController?.enabled && !runningCamera) {
        analysisController?.stop();
      } else if (!analysisController?.enabled && runningCamera) {
        analysisController?.start();
      }
    }*/
    Widget? page;
    switch (currentPage) {
      case Pages.CAMERASCAN:
        page = CameraScanPage(
          currentExtractionResult: currentExtractionResult,
          currentPage: currentPage,
        );
        break;
      case Pages.NFCSCAN:
        page = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  'images/nfc_signal.gif',
                  width: 100,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                nfcStatusText,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LinearProgressIndicator(
                value: progressValue,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  FloatingActionButton(
                    // btn Read MRTD
                    onPressed: () {
                      addNFCData();
                      setState(() {
                        currentPage = Pages.RESULTS;
                      });
                    },
                    child: const Icon(Icons.forward),
                  ),
                  FloatingActionButton(
                    // btn Read MRTD
                    onPressed: resetState,
                    child: const Icon(Icons.exit_to_app),
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      case Pages.RESULTS:
        page = CustomScrollView(slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: _extractionResultList(), //_mrtdDataWidgets(),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (currentQR != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: FloatingActionButton(
                            onPressed: () async {
                              await _uploadToWeb();
                            },
                            child: const Icon(Icons.upload),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FloatingActionButton(
                          onPressed: () {
                            if (enableSaveButton) {
                              storedExtractionData.add(currentExtractionResult);
                            }
                            resetState();
                          },
                          child: const Icon(Icons.exit_to_app),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]);
        break;
      case Pages.HOMEPAGE:
        page = HomePage(
          currentExtractionResult: currentExtractionResult,
          enableSaveButton: enableSaveButton,
          storedExtractionData: storedExtractionData,
          currentPage: currentPage,
          parentRefresh: childRefresh,
        );
        break;
      case Pages.QRSCAN:
        page = CameraAwesomeBuilder.previewOnly(
          previewFit: CameraPreviewFit.cover,
          onImageForAnalysis: (img) => _analyzeQRImage(img),
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
                    child: FloatingActionButton(
                      // btn Read MRTD
                      onPressed: () {
                        setState(() {
                          currentPage = Pages.HOMEPAGE;
                        });
                      },
                      child: const Icon(Icons.keyboard_return),
                    ),
                  ),
                ),
              ],
            );
          },
        );
        break;
      default:
        page = Placeholder();
    }

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Container(
                height: 40,
                child: Image.asset(
                  'images/wide_scandoc.png',
                ),
              ),
            ),
          ),
        ),
        body: page);
  }

  Future _connectToWeb() async {
    print("Connect to web");
    print('http://192.168.1.5:6969/share/connect/$currentQR');
    return http.post(
      Uri.parse('http://192.168.1.5:6969/share/connect/$currentQR'),
      headers: <String, String>{
        'Accept': 'application/json',
      },
      body: {},
    );
  }

  Future _uploadToWeb() async {
    print("Upload to web kita");
    print('http://192.168.1.5:6969/share/send/$currentQR');
    return http.post(
      Uri.parse('http://192.168.1.5:6969/share/send/$currentQR'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'data': currentExtractionResult,
      }),
    );
  }

  Future _analyzeQRImage(AnalysisImage analysisImage) async {
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
              currentQR = qrUUID;
              await _connectToWeb();
              print("Connected with UUID: ${qrUUID}");
              setState(() {
                currentPage = Pages.HOMEPAGE;
              });
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

  void addNFCData() {
    print('ADDING NFC DATA');
    print(_mrtdData);
    Map nfcDataTranslate = {};
    if (_mrtdData != null) {
      nfcDataTranslate = {
        "Name": _mrtdData!.dg1!.mrz!.firstName,
        "Surname": _mrtdData!.dg1!.mrz!.lastName,
        "BirthDate": DateFormat('dd.MM.yyyy')
            .format(_mrtdData!.dg1!.mrz!.dateOfBirth)
            .toString(),
        "Gender": _mrtdData!.dg1!.mrz!.gender,
        "Nationality": _mrtdData!.dg1!.mrz!.nationality,
        "DocumentNumber": _mrtdData!.dg1!.mrz!.documentNumber,
        "ExpiryDate": DateFormat('dd.MM.yyyy')
            .format(_mrtdData!.dg1!.mrz!.dateOfExpiry)
            .toString(),
        "CountryOfIssue": _mrtdData!.dg1!.mrz!.country,
      };
    }

    print(nfcDataTranslate);

    for (var key in keyTranslateMap.keys) {
      bool readNFCKey = nfcDataTranslate.containsKey(key);
      var nfcDataField = {
        'Read': readNFCKey,
        'Value': readNFCKey ? nfcDataTranslate[key] : null,
        'Validated': readNFCKey,
      };
      currentExtractionResult['Data'][key]['NFC'] = nfcDataField;
    }
  }
}

class RectangleQRDisplay extends StatefulWidget {
  RectangleQRDisplay({
    super.key,
  });

  @override
  State<RectangleQRDisplay> createState() => _RectangleQRDisplayState();
}

class _RectangleQRDisplayState extends State<RectangleQRDisplay>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.center,
      child: Stack(
        children: [
          Container(
            width: screenWidth * 0.5,
            height: screenWidth * 0.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                width: 1,
                color: Colors.white,
              ),
              color: Color.fromARGB(50, 255, 255, 255),
            ),
          ),
        ],
      ),
    );
  }
}
