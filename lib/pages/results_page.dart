import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expandable/expandable.dart';
import 'package:http/http.dart' as http;

import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/main.dart';
import 'package:scandoc_app/settings.dart';
import 'package:scandoc_app/utils/buttons.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ScanDocAppState>();
    return CustomScrollView(slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: _extractionResultList(
                      appState, context), //_mrtdDataWidgets(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (appState.currentQRUUID != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FloatingActionButton(
                        onPressed: () async {
                          await _uploadToWeb(appState);
                        },
                        child: const Icon(Icons.upload),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ReturnButton(
                      appState: appState,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  dynamic _uploadToWeb(ScanDocAppState appState) async {
    print("Upload to web kita");
    String currentQRUUID = appState.currentQRUUID!;
    print('$SCANDOC_WEB_URL/share/send/$currentQRUUID');
    return http.post(
      Uri.parse('$SCANDOC_WEB_URL/share/send/$currentQRUUID'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'data': appState.currentExtractionResult,
      }),
    );
  }

  List<Widget> _extractionResultList(
      ScanDocAppState appState, BuildContext context) {
    List<Widget> retVal = [];
    dynamic currentExtractionResult = appState.currentExtractionResult;
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
            decoration: const BoxDecoration(
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
                              const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              const Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                            ]
                          : [
                              const Icon(
                                Icons.close,
                                color: Colors.red,
                              ),
                              const Text(
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
                                  style: const TextStyle(
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
                child: Image.memory(
                  base64Decode(
                      currentExtractionResult['ImageData']['Signature']),
                  height: 50,
                  fit: BoxFit.fill,
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
}
