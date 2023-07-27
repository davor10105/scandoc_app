import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/main.dart';
import 'package:scandoc_app/utils/buttons.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    ScanDocAppState appState = context.watch<ScanDocAppState>();
    return Column(
      children: [
        Expanded(
          child: _createListFromStoredResults(appState),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: QRButton(
                  appState: appState,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ScanDocumentButton(
                  appState: appState,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _createListFromStoredResults(ScanDocAppState appState) {
    // create a displayable list from currently stored extraction results
    if (appState.storedExtractionData.isEmpty) {
      Widget noDataDisplay = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'images/scan_image.png',
                width: 250,
              ),
            ],
          ),
          const Flexible(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
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
    for (var storedSingleExtractionResult in appState.storedExtractionData) {
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

      Image? decodedFaceImage;
      if (storedSingleExtractionResult['ImageData']['FaceImage'] != null) {
        decodedFaceImage = Image.memory(
          base64Decode(storedSingleExtractionResult['ImageData']['FaceImage']),
          fit: BoxFit.fill,
        );
      }

      Widget faceImage = Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 30,
          child: decodedFaceImage ?? Container(),
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
              SizedBox(
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
            appState.removeExtractionData(result);
          }, itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(
                value: storedSingleExtractionResult,
                child: const Row(
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
            appState.setCurrentExtractionResult(storedSingleExtractionResult);
            appState.setCurrentPage(Pages.RESULTS);
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
}
