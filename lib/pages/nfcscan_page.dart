import 'dart:async';
import 'dart:typed_data';
import 'package:dmrtd/dmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/main.dart';

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

class NFCScanPage extends StatefulWidget {
  const NFCScanPage({super.key});

  @override
  State<NFCScanPage> createState() => _NFCScanPageState();
}

class _NFCScanPageState extends State<NFCScanPage> {
  final NfcProvider _nfc = NfcProvider();
  MrtdData? _mrtdData;
  var progressValue = 0.0;
  var nfcStatusText = '';
  var _isNfcAvailable = false;
  var _isReading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _initPlatformState();

    // Update platform state every 3 sec
    Timer.periodic(const Duration(seconds: 3), (Timer t) {
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

  @override
  Widget build(BuildContext context) {
    ScanDocAppState appState = context.watch<ScanDocAppState>();
    if (_isNfcAvailable) {
      _readMRTD(appState);
    }
    return Column(
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
                onPressed: () {
                  addNFCData(appState);
                  appState.setCurrentPage(Pages.FACESCAN);
                },
                child: const Icon(Icons.forward),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _readMRTD(ScanDocAppState appState) async {
    print('START READING NFC');
    print(_isReading);
    print(appState.currentExtractionResult);

    bool readSuccessfully = false;
    if (!_isReading && mounted) {
      if (appState.currentExtractionResult == null) {
        throw Exception('MRZ data not read');
      }
      var _docNumber = appState.currentExtractionResult['Data']
          ['DocumentNumber']['RecommendedValue'];
      var _dob = DateFormat('dd.MM.yyyy').parse(appState
          .currentExtractionResult['Data']['BirthDate']['RecommendedValue']);
      var _doe = DateFormat('dd.MM.yyyy').parse(appState
          .currentExtractionResult['Data']['ExpiryDate']['RecommendedValue']);

      print('$_dob, $_doe, $_docNumber');
      _isReading = true;
      try {
        setState(() {
          nfcStatusText = 'Looking for an NFC Document...';
        });

        print('Prvisa');

        await _nfc.connect(
            iosAlertMessage: "Hold your phone near Biometric Passport");

        final passport = Passport(_nfc);

        setState(() {
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
          progressValue = 0.33;
          nfcStatusText = 'Reading DG1...';
        });

        if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
          mrtdData.dg1 = await passport.readEfDG1();
        }

        setState(() {
          progressValue = 0.66;
          nfcStatusText = 'Reading DG2...';
        });

        //uncomment to extract face image
        /*if (mrtdData.com!.dgTags.contains(EfDG2.TAG)) {
          mrtdData.dg2 = await passport.readEfDG2();
        }*/

        print('Procitao');

        print(mrtdData);

        _mrtdData = mrtdData;
        addNFCData(appState);
        readSuccessfully = true;

        setState(() {
          progressValue = 1.0;
          nfcStatusText = 'Finished.';
          appState.setCurrentPage(Pages.RESULTS);
        });
      } on Exception catch (e) {
        print(e);
        _isReading = false;
      } finally {
        await _nfc.disconnect(iosAlertMessage: 'Disconnected');
        _isReading = false;

        if (!readSuccessfully) {
          await _readMRTD(appState);
        }
      }
    }
  }

  void addNFCData(ScanDocAppState appState) {
    print('ADDING NFC DATA');
    print(_mrtdData);
    Map nfcDataTranslate = {};
    if (_mrtdData != null) {
      nfcDataTranslate = {
        "Name": _mrtdData!.dg1!.mrz.firstName,
        "Surname": _mrtdData!.dg1!.mrz.lastName,
        "BirthDate": DateFormat('dd.MM.yyyy')
            .format(_mrtdData!.dg1!.mrz.dateOfBirth)
            .toString(),
        "Gender": _mrtdData!.dg1!.mrz.gender,
        "Nationality": _mrtdData!.dg1!.mrz.nationality,
        "DocumentNumber": _mrtdData!.dg1!.mrz.documentNumber,
        "ExpiryDate": DateFormat('dd.MM.yyyy')
            .format(_mrtdData!.dg1!.mrz.dateOfExpiry)
            .toString(),
        "CountryOfIssue": _mrtdData!.dg1!.mrz.country,
      };
    }

    print(nfcDataTranslate);

    dynamic currentExtractionResult = appState.currentExtractionResult;
    for (var key in keyTranslateMap.keys) {
      bool readNFCKey = nfcDataTranslate.containsKey(key);
      var nfcDataField = {
        'Read': readNFCKey,
        'Value': readNFCKey ? nfcDataTranslate[key] : null,
        'Validated': readNFCKey,
      };

      currentExtractionResult['Data'][key]['NFC'] = nfcDataField;
    }
    appState.setCurrentExtractionResult(currentExtractionResult);
  }
}
