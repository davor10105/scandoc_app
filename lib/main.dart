import 'dart:async';
import 'dart:math';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:expandable/expandable.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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

enum Pages {
  CAMERASCAN,
  NFCSCAN,
  RESULTS,
  HOMEPAGE,
  QRSCAN,
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
  var runningCamera = true;
  AnalysisController? analysisController;
  var progressValue = 0.0;
  var nfcStatusText = '';
  Pages currentPage = Pages.HOMEPAGE;
  var needsFlip = false;
  var successExtraction = false;
  int consecutiveValidationSuccess = 0;
  bool enableSaveButton = true;

  var storedExtractionData = [];

  final NfcProvider _nfc = NfcProvider();
  // ignore: unused_field
  late Timer _timerStateUpdater;
  var _alertMessage = "";
  final _log = Logger("mrtdeg.app");
  var _isNfcAvailable = false;
  var _isReading = false;
  final _mrzData = GlobalKey<FormState>();

  // mrz data
  var _docNumber; //'117118381';
  var _dob; // = DateTime.utc(1996, 8, 7); // date of birth
  var _doe; // = DateTime.utc(2028, 2, 15); // date of doc expiry

  MrtdData? _mrtdData;

  Map keyTranslateMap = {
    "Name": "Name",
    "Surname": "Surname",
    "BirthDate": "Birth Date",
    "Gender": "Sex",
    "PlaceOfBirth": "Place of Birth",
    "Nationality": "Nationality",
    "DocumentNumber": "Document Number",
    "IssuedDate": "Date of Issue",
    "ExpiryDate": "Date of Expiry",
    "CountryOfIssue": "Country of Issue",
    "IssuingAuthority": "Issuing Authority",
    "AddressCountry": "Country",
    "AddressZip": "ZIP Code",
    "AddressCity": "City",
    "AddressCounty": "County",
    "AddressStreet": "Street",
    "PersonalIdentificationNumber": "Personal ID Number",
    "GivenName": "Given Name",
    "FamilyName": "Family Name",
    "MothersGivenName": "Mother's Given Name",
    "MothersFamilyName": "Mother's Family Name",
    "SecondLastName": "Second-Last Name",
    "Address": "Address",
    "PlaceOfIssue": "Place of Issue",
    "FathersGivenName": "Father's Given Name",
  };

  Map documentTypeMap = {
    'ID': 'Identity Document',
    'PASS': 'Passport',
    'DL': "Driver's Licence",
    'RP': 'Residence Permit',
  };

  void resetState() {
    setState(() {
      frontDocumentImage = null;
      backDocumentImage = null;
      processingImage = false;
      currentExtractionResult = null;
      runningCamera = true;
      progressValue = 0.0;
      _mrtdData = null;
      nfcStatusText = '';
      var _docNumber = null;
      var _dob = null;
      var _doe = null;
      currentPage = Pages.HOMEPAGE;
      needsFlip = false;
      successExtraction = false;
      consecutiveValidationSuccess = 0;
      enableSaveButton = true;
    });
  }

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

    if (_isNfcAvailable != isNfcAvailable) {
      setState(() {
        _isNfcAvailable = isNfcAvailable;
      });
    }
  }

  Future<void> _readMRTD() async {
    print('START READING NFC');
    bool readSuccessfully = false;
    if (!_isReading && currentPage == Pages.NFCSCAN) {
      _isReading = true;
      try {
        setState(() {
          nfcStatusText = 'Looking for an NFC Document...';
        });

        await _nfc.connect(
            iosAlertMessage: "Hold your phone near Biometric Passport");
        final passport = Passport(_nfc);

        setState(() {
          _alertMessage = "Reading Passport ...";
          nfcStatusText = 'Found the NFC Document. Acquiring data...';
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

        print('PRIJE DBAKEYS');

        final bacKeySeed = DBAKeys(_docNumber, _dob, _doe);
        await passport.startSession(bacKeySeed);

        mrtdData.com = await passport.readEfCOM();

        setState(() {
          progressValue = 0.0625;
          nfcStatusText = 'Reading DG1...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
          mrtdData.dg1 = await passport.readEfDG1();
        }

        setState(() {
          progressValue = 0.0625 * 2;
          nfcStatusText = 'Reading DG2...';
        });

        /*if (mrtdData.com!.dgTags.contains(EfDG2.TAG)) {
          mrtdData.dg2 = await passport.readEfDG2();
        }

        setState(() {
          progressValue = 0.0625 * 3;
          nfcStatusText = 'Reading DG5...';
        });

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

        setState(() {
          progressValue = 0.0625 * 4;
          nfcStatusText = 'Reading DG6...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG6.TAG)) {
          mrtdData.dg6 = await passport.readEfDG6();
        }

        setState(() {
          progressValue = 0.0625 * 5;
          nfcStatusText = 'Reading DG7...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG7.TAG)) {
          mrtdData.dg7 = await passport.readEfDG7();
        }

        setState(() {
          progressValue = 0.0625 * 6;
          nfcStatusText = 'Reading DG8...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG8.TAG)) {
          mrtdData.dg8 = await passport.readEfDG8();
        }

        setState(() {
          progressValue = 0.0625 * 7;
          nfcStatusText = 'Reading DG9...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG9.TAG)) {
          mrtdData.dg9 = await passport.readEfDG9();
        }

        setState(() {
          progressValue = 0.0625 * 8;
          nfcStatusText = 'Reading DG10...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG10.TAG)) {
          mrtdData.dg10 = await passport.readEfDG10();
        }

        setState(() {
          progressValue = 0.0625 * 9;
          nfcStatusText = 'Reading DG11...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG11.TAG)) {
          mrtdData.dg11 = await passport.readEfDG11();
        }

        setState(() {
          progressValue = 0.0625 * 10;
          nfcStatusText = 'Reading DG12...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG12.TAG)) {
          mrtdData.dg12 = await passport.readEfDG12();
        }

        setState(() {
          progressValue = 0.0625 * 11;
          nfcStatusText = 'Reading DG13...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG13.TAG)) {
          mrtdData.dg13 = await passport.readEfDG13();
        }

        setState(() {
          progressValue = 0.0625 * 12;
          nfcStatusText = 'Reading DG14...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG14.TAG)) {
          mrtdData.dg14 = await passport.readEfDG14();
        }

        setState(() {
          progressValue = 0.0625 * 13;
          nfcStatusText = 'Reading DG15...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
          mrtdData.dg15 = await passport.readEfDG15();
          mrtdData.aaSig = await passport.activeAuthenticate(Uint8List(8));
        }

        setState(() {
          progressValue = 0.0625 * 14;
          nfcStatusText = 'Reading DG16...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG16.TAG)) {
          mrtdData.dg16 = await passport.readEfDG16();
        }

        setState(() {
          progressValue = 0.0625 * 15;
          nfcStatusText = 'Reading EFSOD...';
        });

        mrtdData.sod = await passport.readEfSOD(); */

        print('Procitao');

        print(mrtdData);

        _mrtdData = mrtdData;
        addNFCData();
        readSuccessfully = true;

        setState(() {
          progressValue = 1.0;
          nfcStatusText = 'Finished.';
          currentPage = Pages.RESULTS;
        });

        setState(() {
          _alertMessage = "";
        });
      } on Exception catch (e) {
        print('NIJE BOBA');
        print('NIJE BOBA dva');
        print('NIJE BOBA tri');

        if (e is PlatformException) {
          print(e.code);
          if (e.code == 500) {
            print('Nije dobro ocitano');
          }
        }
        print(e);
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
          _isReading = false;
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
    if (!readSuccessfully) {
      await _readMRTD();
    }
  }

  Widget _makeMrtdDataWidget(
      {required String header,
      required String collapsedText,
      required dataText}) {
    return ExpandablePanel(
        theme: const ExpandableThemeData(
          headerAlignment: ExpandablePanelHeaderAlignment.center,
          tapBodyToCollapse: true,
          hasIcon: true,
          iconColor: Colors.red,
        ),
        header: Text(header),
        collapsed: Text(collapsedText,
            softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
        expanded: Container(
            padding: const EdgeInsets.all(18),
            color: Color.fromARGB(255, 239, 239, 239),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(dataText, textAlign: TextAlign.left)
                ])));
  }

  List<Widget> _mrtdDataWidgets() {
    List<Widget> list = [];
    if (_mrtdData == null) return list;

    if (_mrtdData!.cardAccess != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.CardAccess',
          collapsedText: '',
          dataText: _mrtdData!.cardAccess!.toBytes().hex()));
    }

    if (_mrtdData!.cardSecurity != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.CardSecurity',
          collapsedText: '',
          dataText: _mrtdData!.cardSecurity!.toBytes().hex()));
    }

    if (_mrtdData!.sod != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.SOD',
          collapsedText: '',
          dataText: _mrtdData!.sod!.toBytes().hex()));
    }

    if (_mrtdData!.com != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.COM',
          collapsedText: '',
          dataText: formatEfCom(_mrtdData!.com!)));
    }

    if (_mrtdData!.dg1 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG1',
          collapsedText: '',
          dataText: formatMRZ(_mrtdData!.dg1!.mrz)));
    }

    if (_mrtdData!.dg2 != null) {
      //img.JpegDecoder().decode(_mrtdData!.dg2!.toBytes().buffer.asUint8List());
      print('DECODED');
      //list.add(Image.memory(_mrtdData!.dg2!.toBytes()));
      /*list.add(_makeMrtdDataWidget(
          header: 'EF.DG2',
          collapsedText: '',
          dataText: _mrtdData!.dg2!.toBytes().hex()));*/
    }

    if (_mrtdData!.dg3 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG3',
          collapsedText: '',
          dataText: _mrtdData!.dg3!.toBytes().hex()));
    }

    if (_mrtdData!.dg4 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG4',
          collapsedText: '',
          dataText: _mrtdData!.dg4!.toBytes().hex()));
    }

    if (_mrtdData!.dg5 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG5',
          collapsedText: '',
          dataText: _mrtdData!.dg5!.toBytes().hex()));
    }

    if (_mrtdData!.dg6 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG6',
          collapsedText: '',
          dataText: _mrtdData!.dg6!.toBytes().hex()));
    }

    if (_mrtdData!.dg7 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG7',
          collapsedText: '',
          dataText: _mrtdData!.dg7!.toBytes().hex()));
    }

    if (_mrtdData!.dg8 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG8',
          collapsedText: '',
          dataText: _mrtdData!.dg8!.toBytes().hex()));
    }

    if (_mrtdData!.dg9 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG9',
          collapsedText: '',
          dataText: _mrtdData!.dg9!.toBytes().hex()));
    }

    if (_mrtdData!.dg10 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG10',
          collapsedText: '',
          dataText: _mrtdData!.dg10!.toBytes().hex()));
    }

    if (_mrtdData!.dg11 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG11',
          collapsedText: '',
          dataText: _mrtdData!.dg11!.toBytes().hex()));
    }

    if (_mrtdData!.dg12 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG12',
          collapsedText: '',
          dataText: _mrtdData!.dg12!.toBytes().hex()));
    }

    if (_mrtdData!.dg13 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG13',
          collapsedText: '',
          dataText: _mrtdData!.dg13!.toBytes().hex()));
    }

    if (_mrtdData!.dg14 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG14',
          collapsedText: '',
          dataText: _mrtdData!.dg14!.toBytes().hex()));
    }

    if (_mrtdData!.dg15 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG15',
          collapsedText: '',
          dataText: _mrtdData!.dg15!.toBytes().hex()));
    }

    if (_mrtdData!.aaSig != null) {
      list.add(_makeMrtdDataWidget(
          header: 'Active Authentication signature',
          collapsedText: '',
          dataText: _mrtdData!.aaSig!.hex()));
    }

    if (_mrtdData!.dg16 != null) {
      list.add(_makeMrtdDataWidget(
          header: 'EF.DG16',
          collapsedText: '',
          dataText: _mrtdData!.dg16!.toBytes().hex()));
    }

    return list;
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _storageResultList() {
    if (storedExtractionData.length == 0) {
      Widget noDataDisplay = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                child: Image.asset(
                  'images/scan_image.png',
                  width: 250,
                ),
              ),
            ],
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: 250,
                child: Text(
                  'Your scan history is empty, tap "Scan Document" to begin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      return noDataDisplay;
    }

    List<Widget> retVal = [];
    var divider = const Divider(
      height: 20,
      thickness: 1,
      indent: 8,
      endIndent: 8,
      color: Color.fromARGB(255, 194, 215, 253),
    );
    retVal.add(divider);
    for (var storedSingleExtractionResult in storedExtractionData) {
      String title = '';
      if (storedSingleExtractionResult['Data']['Name']['RecommendedValue'] !=
          null) {
        title +=
            storedSingleExtractionResult['Data']['Name']['RecommendedValue'];
      }
      if (storedSingleExtractionResult['Data']['Surname']['RecommendedValue'] !=
          null) {
        if (title != '') {
          title += ' ';
        }
        title +=
            storedSingleExtractionResult['Data']['Surname']['RecommendedValue'];
      }

      var decodedFaceImage = null;
      if (storedSingleExtractionResult['ImageData']['FaceImage'] != null) {
        decodedFaceImage = Image.memory(
          base64Decode(storedSingleExtractionResult['ImageData']['FaceImage']),
          fit: BoxFit.fill,
          //gaplessPlayback: true,
        );
      }

      Widget faceImage = Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: 30,
          child: decodedFaceImage != null ? decodedFaceImage : Container(),
        ),
      );

      bool hasReadNFC =
          storedSingleExtractionResult['Data']['Name']['NFC']['Read'];

      String documentType = documentTypeMap[
          storedSingleExtractionResult['Metadata'][0]['DocumentType']];

      var listElement = Padding(
        padding: const EdgeInsets.only(
          left: 8,
          right: 8,
        ),
        child: ListTile(
          leading: faceImage,
          tileColor: const Color.fromARGB(255, 255, 255, 255),
          title: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 3.0,
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                        Text(
                          documentType,
                          style: const TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                child: Column(
                  children: hasReadNFC
                      ? [
                          const Icon(
                            Icons.nfc,
                            color: Colors.green,
                          ),
                          const Text(
                            'NFC',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                        ]
                      : [
                          const Icon(
                            Icons.nfc,
                            color: Colors.red,
                          ),
                          const Text(
                            'No NFC',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                            ),
                          ),
                        ],
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton(onSelected: (result) {
            setState(() {
              storedExtractionData.remove(result);
            });
          }, itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(
                value: storedSingleExtractionResult,
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Remove'),
                    ),
                    Icon(Icons.delete),
                  ],
                ),
              )
            ];
          }),
          onTap: () {
            setState(() {
              currentExtractionResult = storedSingleExtractionResult;
              currentPage = Pages.RESULTS;
              enableSaveButton = false;
              print('Kita');
            });
          },
        ),
      );

      retVal.add(listElement);
      retVal.add(divider);
    }

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: retVal,
          ),
        ),
      ],
    );
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
        page = CameraAwesomeBuilder.previewOnly(
          previewFit: CameraPreviewFit.cover,
          onImageForAnalysis: (img) => _analyzeImage(img),
          imageAnalysisConfig: AnalysisConfig(
            androidOptions: const AndroidAnalysisOptions.jpeg(
              width: 640,
            ),
            maxFramesPerSecond: 1,
          ),
          builder: (state, previewSize, previewRect) {
            analysisController = state.analysisController;
            return RectangleDisplay(needsFlip, successExtraction);
          },
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
              child: Text(nfcStatusText),
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
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FloatingActionButton(
                          // btn Read MRTD
                          onPressed: () {
                            setState(() {
                              currentPage = Pages.QRSCAN;
                            });
                          },
                          child: const Icon(Icons.qr_code_2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FloatingActionButton(
                          // btn Read MRTD
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
        page = Column(
          children: [
            Expanded(
              child: _storageResultList(),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton.extended(
                  label: Text('Scan Document'),
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      currentPage = Pages.CAMERASCAN;
                    });
                  },
                ),
              ),
            ),
          ],
        );
        break;
      case Pages.QRSCAN:
        page = CameraAwesomeBuilder.previewOnly(
          previewFit: CameraPreviewFit.cover,
          onImageForAnalysis: (img) => _analyzeQRImage(img),
          imageAnalysisConfig: AnalysisConfig(
            androidOptions: const AndroidAnalysisOptions.jpeg(
              width: 640,
            ),
            maxFramesPerSecond: 1,
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
                          currentPage = Pages.RESULTS;
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

  Future _processFrontBack() async {
    setState(() {
      successExtraction = true;
    });
    var extractionResult =
        await callExtraction(frontDocumentImage, backDocumentImage);
    frontDocumentImage = null;
    backDocumentImage = null;
    var jsonExtractionResult = jsonDecode(extractionResult.body);
    if (jsonExtractionResult['Status'] == 200) {
      _docNumber =
          jsonExtractionResult['Data']['DocumentNumber']['RecommendedValue'];
      _dob = DateFormat('dd.MM.yyyy')
          .parse(jsonExtractionResult['Data']['BirthDate']['RecommendedValue']);
      _doe = DateFormat('dd.MM.yyyy').parse(
          jsonExtractionResult['Data']['ExpiryDate']['RecommendedValue']);
      for (var key in ['DocumentNumber', 'ExpiryDate', 'BirthDate']) {
        print(jsonExtractionResult['Data'][key]['RecommendedValue']);
      }
      setState(() {
        currentExtractionResult = jsonExtractionResult;
        _mrtdData = null;
        runningCamera = false;
        currentPage = Pages.NFCSCAN;
      });
      await _readMRTD();
    }
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
        print(consecutiveValidationSuccess);
        dynamic result = await callValidation([base64Image]);
        var jsonValidationResult = jsonDecode(result.body);
        print(jsonValidationResult);
        if (jsonValidationResult['Status'] == 200 &&
            jsonValidationResult['Validated']) {
          if (consecutiveValidationSuccess >= 2) {
            consecutiveValidationSuccess = 0;
            if (jsonValidationResult['Side'] == 'FRONT') {
              frontDocumentImage = base64Image;
            } else {
              backDocumentImage = base64Image;
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
                await _processFrontBack();
              }
            } else if (jsonValidationResult['InfoCode'] == '1000') {
              await _processFrontBack();
            }
          } else {
            consecutiveValidationSuccess += 1;
          }
        } else {
          consecutiveValidationSuccess = 0;
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

  Future _analyzeQRImage(AnalysisImage analysisImage) async {
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
      print('QR Kita');
    }, yuv420: (Yuv420Image image) {
      //return handleYuv420( image);
    }, nv21: (Nv21Image image) {
      //return handleNv21(image);
    }, bgra8888: (Bgra8888Image image) {
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

class RectangleDisplay extends StatefulWidget {
  var needsFlip;
  var successExtraction;

  RectangleDisplay(
    this.needsFlip,
    this.successExtraction, {
    super.key,
  });

  @override
  State<RectangleDisplay> createState() => _RectangleDisplayState();
}

class _RectangleDisplayState extends State<RectangleDisplay>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller =
        AnimationController(duration: const Duration(seconds: 3), vsync: this);
    animation = CurveTween(curve: Curves.easeInOut).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    //controller.forward();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    if (widget.needsFlip) {
      controller.forward();
    }
    return Align(
      alignment: Alignment.center,
      child: Stack(
        children: [
          Transform(
            transform: Matrix4.rotationY(animation.value * pi),
            alignment: Alignment.center,
            child: Container(
              width: screenWidth * 0.8,
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
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: widget.successExtraction
                  ? InfoPanel(widget.successExtraction)
                  : Container(),
            ),
          ),
        ],
      ),
    );
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

class InfoPanel extends StatefulWidget {
  var successExtraction;
  InfoPanel(
    this.successExtraction, {
    super.key,
  });

  @override
  State<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<InfoPanel>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    animation = Tween<double>(begin: -1, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.successExtraction) {
      controller.forward();
    }
    return Container(
      width: 100,
      child: Stack(children: [
        Container(
          alignment: Alignment.center,
          child: Image.asset(
            'images/icons8-checkmark-480.png',
            width: 70 - (pow(animation.value, 2) - 1) * 20,
          ),
        ),
        SpinKitRing(
          color: Color.fromARGB(255, 227, 252, 198),
          size: 100.0,
        ),
      ]),
    );
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
