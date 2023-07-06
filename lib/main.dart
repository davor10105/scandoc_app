import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

class MrtdData {
  EfCardAccess? cardAccess;
  EfCardSecurity? cardSecurity;
  EfCOM? com;
  EfSOD? sod;
  EfDG1? dg1;
  EfDG2? dg2;
  EfDG3? dg3;
  EfDG4? dg4;
  EfDG5? dg5;
  EfDG6? dg6;
  EfDG7? dg7;
  EfDG8? dg8;
  EfDG9? dg9;
  EfDG10? dg10;
  EfDG11? dg11;
  EfDG12? dg12;
  EfDG13? dg13;
  EfDG14? dg14;
  EfDG15? dg15;
  EfDG16? dg16;
  Uint8List? aaSig;
}

final Map<DgTag, String> dgTagToString = {
  EfDG1.TAG: 'EF.DG1',
  EfDG2.TAG: 'EF.DG2',
  EfDG3.TAG: 'EF.DG3',
  EfDG4.TAG: 'EF.DG4',
  EfDG5.TAG: 'EF.DG5',
  EfDG6.TAG: 'EF.DG6',
  EfDG7.TAG: 'EF.DG7',
  EfDG8.TAG: 'EF.DG8',
  EfDG9.TAG: 'EF.DG9',
  EfDG10.TAG: 'EF.DG10',
  EfDG11.TAG: 'EF.DG11',
  EfDG12.TAG: 'EF.DG12',
  EfDG13.TAG: 'EF.DG13',
  EfDG14.TAG: 'EF.DG14',
  EfDG15.TAG: 'EF.DG15',
  EfDG16.TAG: 'EF.DG16'
};

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
    return const MaterialApp(
      title: 'camerAwesome App',
      home: CameraPage(),
    );
  }
}

Future<http.Response> callValidation(List<dynamic> base64EncodedImages) {
  print("Call validation");
  return http.post(
    Uri.parse('http://192.168.1.11:4000/validation/'),
    headers: <String, String>{
      'Authorization': 'TOKEN',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'AcceptTermsAndConditions': true,
      'DataFields': {
        'Images': base64EncodedImages,
      },
      'Settings': {
        'SkipImageSizeCheck': true,
      }
    }),
  );
}

Future<http.Response> callExtraction(
    String? frontDocumentImage, String? backDocumentImage) {
  print("Call extraction");
  bool shouldSendBackImage = !(backDocumentImage == null);
  return http.post(
    Uri.parse('http://192.168.1.11:4000/extraction/'),
    headers: <String, String>{
      'Authorization': 'TOKEN',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'AcceptTermsAndConditions': true,
      'DataFields': {
        'BackImage': shouldSendBackImage ? backDocumentImage : '',
        'BackImageCropped': false,
        'BackImageType': 'base64',
        'FrontImage': frontDocumentImage,
        'FrontImageCropped': false,
        'FrontImageType': 'base64',
      },
      'Settings': {
        'IgnoreBackImage': !shouldSendBackImage,
        'ShouldReturnDocumentImage': false,
        'ShouldReturnFaceIfDetected': true,
        'ShouldReturnSignatureIfDetected': false,
        'ShouldValidate': true,
        'SkipImageSizeCheck': true,
        'SkipDocumentSizeCheck': true,
      },
    }),
  );
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  var frontDocumentImage;
  var backDocumentImage;
  var currentExtractionResult;
  var processingImage = false;

  final NfcProvider _nfc = NfcProvider();
  // ignore: unused_field
  late Timer _timerStateUpdater;
  var _alertMessage = "";
  final _log = Logger("mrtdeg.app");
  var _isNfcAvailable = false;
  var _isReading = false;
  final _mrzData = GlobalKey<FormState>();

  // mrz data
  final _docNumber = TextEditingController();
  final _dob = TextEditingController(); // date of birth
  final _doe = TextEditingController(); // date of doc expiry

  MrtdData? _mrtdData;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _initPlatformState();

    // Update platform state every 3 sec
    _timerStateUpdater = Timer.periodic(Duration(seconds: 3), (Timer t) {
      _initPlatformState();
    });
  }

  Future<void> _initPlatformState() async {
    bool isNfcAvailable;
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      isNfcAvailable = status == NfcStatus.enabled;
    } on PlatformException {
      isNfcAvailable = false;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _isNfcAvailable = isNfcAvailable;
    });
  }

  DateTime? _getDOBDate() {
    if (_dob.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_dob.text);
  }

  DateTime? _getDOEDate() {
    if (_doe.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_doe.text);
  }

  void _readMRTD() async {
    try {
      setState(() {
        _mrtdData = null;
        _alertMessage = "Waiting for Passport tag ...";
        _isReading = true;
      });

      await _nfc.connect(
          iosAlertMessage: "Hold your phone near Biometric Passport");
      final passport = Passport(_nfc);

      setState(() {
        _alertMessage = "Reading Passport ...";
      });

      final mrtdData = MrtdData();

      try {
        mrtdData.cardAccess = await passport.readEfCardAccess();
      } on PassportError {
        //if (e.code != StatusWord.fileNotFound) rethrow;
      }

      try {
        mrtdData.cardSecurity = await passport.readEfCardSecurity();
      } on PassportError {
        //if (e.code != StatusWord.fileNotFound) rethrow;
      }

      final bacKeySeed =
          DBAKeys(_docNumber.text, _getDOBDate()!, _getDOEDate()!);
      await passport.startSession(bacKeySeed);

      mrtdData.com = await passport.readEfCOM();

      if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
        mrtdData.dg1 = await passport.readEfDG1();
      }

      if (mrtdData.com!.dgTags.contains(EfDG2.TAG)) {
        mrtdData.dg2 = await passport.readEfDG2();
      }

      // To read DG3 and DG4 session has to be established with CVCA certificate (not supported).
      // if(mrtdData.com!.dgTags.contains(EfDG3.TAG)) {
      //   mrtdData.dg3 = await passport.readEfDG3();
      // }

      // if(mrtdData.com!.dgTags.contains(EfDG4.TAG)) {
      //   mrtdData.dg4 = await passport.readEfDG4();
      // }

      if (mrtdData.com!.dgTags.contains(EfDG5.TAG)) {
        mrtdData.dg5 = await passport.readEfDG5();
      }

      if (mrtdData.com!.dgTags.contains(EfDG6.TAG)) {
        mrtdData.dg6 = await passport.readEfDG6();
      }

      if (mrtdData.com!.dgTags.contains(EfDG7.TAG)) {
        mrtdData.dg7 = await passport.readEfDG7();
      }

      if (mrtdData.com!.dgTags.contains(EfDG8.TAG)) {
        mrtdData.dg8 = await passport.readEfDG8();
      }

      if (mrtdData.com!.dgTags.contains(EfDG9.TAG)) {
        mrtdData.dg9 = await passport.readEfDG9();
      }

      if (mrtdData.com!.dgTags.contains(EfDG10.TAG)) {
        mrtdData.dg10 = await passport.readEfDG10();
      }

      if (mrtdData.com!.dgTags.contains(EfDG11.TAG)) {
        mrtdData.dg11 = await passport.readEfDG11();
      }

      if (mrtdData.com!.dgTags.contains(EfDG12.TAG)) {
        mrtdData.dg12 = await passport.readEfDG12();
      }

      if (mrtdData.com!.dgTags.contains(EfDG13.TAG)) {
        mrtdData.dg13 = await passport.readEfDG13();
      }

      if (mrtdData.com!.dgTags.contains(EfDG14.TAG)) {
        mrtdData.dg14 = await passport.readEfDG14();
      }

      if (mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
        mrtdData.dg15 = await passport.readEfDG15();
        mrtdData.aaSig = await passport.activeAuthenticate(Uint8List(8));
      }

      if (mrtdData.com!.dgTags.contains(EfDG16.TAG)) {
        mrtdData.dg16 = await passport.readEfDG16();
      }

      mrtdData.sod = await passport.readEfSOD();

      setState(() {
        _mrtdData = mrtdData;
      });

      setState(() {
        _alertMessage = "";
      });
    } on Exception catch (e) {
      final se = e.toString().toLowerCase();
      String alertMsg = "An error has occurred while reading Passport!";
      if (e is PassportError) {
        if (se.contains("security status not satisfied")) {
          alertMsg =
              "Failed to initiate session with passport.\nCheck input data!";
        }
        _log.error("PassportError: ${e.message}");
      } else {
        _log.error(
            "An exception was encountered while trying to read Passport: $e");
      }

      if (se.contains('timeout')) {
        alertMsg = "Timeout while waiting for Passport tag";
      } else if (se.contains("tag was lost")) {
        alertMsg = "Tag was lost. Please try again!";
      } else if (se.contains("invalidated by user")) {
        alertMsg = "";
      }

      setState(() {
        _alertMessage = alertMsg;
      });
    } finally {
      if (_alertMessage.isNotEmpty) {
        await _nfc.disconnect(iosErrorMessage: _alertMessage);
      } else {
        await _nfc.disconnect(
            iosAlertMessage: formatProgressMsg("Finished", 100));
      }
      setState(() {
        _isReading = false;
      });
    }
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.previewOnly(
        previewFit: CameraPreviewFit.contain,
        onImageForAnalysis: (img) => _analyzeImage(img),
        imageAnalysisConfig: AnalysisConfig(
          androidOptions: const AndroidAnalysisOptions.jpeg(
            width: 384,
          ),
          maxFramesPerSecond: 1,
        ),
        builder: (state, previewSize, previewRect) {
          return Container();
        },
      ),
    );
  }

  Future _analyzeImage(AnalysisImage analysisImage) async {
    if (processingImage) return;
    processingImage = true;
    await analysisImage.when(jpeg: (JpegImage image) async {
      //return handleJpeg(image);

      //print('KITA');
      //print(image.width);
      var dartImage = img.decodeImage(image.bytes);
      var angle = getAngle(image.rotation);
      //print(image.rotation);
      dartImage = img.copyRotate(dartImage!, angle: angle);
      String base64Image =
          base64Encode(Uint8List.fromList(img.encodeJpg(dartImage)));
      try {
        dynamic result = await callValidation([base64Image]);
        var jsonValidationResult = jsonDecode(result.body);
        print(jsonValidationResult);
        if (jsonValidationResult['Status'] == 200 &&
            jsonValidationResult['Validated']) {
          if (jsonValidationResult['Side'] == 'FRONT') {
            frontDocumentImage = base64Image;
          } else {
            backDocumentImage = base64Image;
          }
          if (jsonValidationResult['InfoCode'] == '1007') {
            if (frontDocumentImage == null || backDocumentImage == null) {
              print('Flip the document');
            } else {
              var extractionResult =
                  await callExtraction(frontDocumentImage, backDocumentImage);
              frontDocumentImage = null;
              backDocumentImage = null;
              var jsonExtractionResult = jsonDecode(extractionResult.body);
              for (var key in ['DocumentNumber', 'ExpiryDate', 'BirthDate']) {
                print(jsonExtractionResult['Data'][key]['RecommendedValue']);
              }
              setState(() {
                currentExtractionResult = jsonExtractionResult;
              });
            }
          } else if (jsonValidationResult['InfoCode'] == '1000') {
            var extractionResult =
                await callExtraction(frontDocumentImage, backDocumentImage);
            frontDocumentImage = null;
            backDocumentImage = null;
            var jsonExtractionResult = jsonDecode(extractionResult.body);
            for (var key in ['DocumentNumber', 'ExpiryDate', 'BirthDate']) {
              print(jsonExtractionResult['Data'][key]['RecommendedValue']);
            }
            setState(() {
              currentExtractionResult = jsonExtractionResult;
            });
          }
        }
      } catch (e) {
        print('No validation endpoint');
      }
    }, yuv420: (Yuv420Image image) {
      //return handleYuv420( image);
    }, nv21: (Nv21Image image) {
      //return handleNv21(image);
    }, bgra8888: (Bgra8888Image image) {
      //return handleBgra8888(image);
    });
    processingImage = false;
  }
}

int getAngle(InputAnalysisImageRotation rotation) {
  switch (rotation) {
    case InputAnalysisImageRotation.rotation0deg:
      return 0;

    case InputAnalysisImageRotation.rotation90deg:
      return 90;

    case InputAnalysisImageRotation.rotation180deg:
      return 180;

    case InputAnalysisImageRotation.rotation270deg:
      return 270;

    default:
      return 0;
  }
}
