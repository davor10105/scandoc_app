import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scandoc_app/pages/camerascan_page.dart';
import 'package:scandoc_app/pages/homepage.dart';
import 'package:scandoc_app/pages/qrscan_page.dart';
import 'package:scandoc_app/pages/results_page.dart';
import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/pages/nfcscan_page.dart';

void main() {
  runApp(const ScanDocApp());
}

class ScanDocApp extends StatelessWidget {
  const ScanDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ScanDocAppState(),
      child: MaterialApp(
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
              displayLarge:
                  TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
              titleLarge: TextStyle(fontSize: 36, fontStyle: FontStyle.italic),
              bodyMedium: TextStyle(
                fontSize: 18,
              ),
              bodySmall: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 99, 135, 255))),
        ),
        home: ScanDocPage(),
      ),
    );
  }
}

class ScanDocAppState extends ChangeNotifier {
  // stores data used between pages
  Pages currentPage = Pages.HOMEPAGE;
  dynamic currentExtractionResult;
  List<dynamic> storedExtractionData = [];
  String? currentQRUUID;

  void setCurrentPage(Pages newPage) {
    currentPage = newPage;
    notifyListeners();
  }

  void setCurrentExtractionResult(dynamic newExtractionResult) {
    currentExtractionResult = newExtractionResult;
    notifyListeners();
  }

  void storeExtractionData(dynamic extractionData) {
    if (extractionData != null &&
        !storedExtractionData.contains(extractionData)) {
      storedExtractionData.add(extractionData);
    }
    notifyListeners();
  }

  void removeExtractionData(dynamic extractionData) {
    storedExtractionData.remove(extractionData);
    notifyListeners();
  }

  // resets the "current" type variables and enables a new scan
  void resetCurrentData() {
    currentExtractionResult = null;
    currentPage = Pages.HOMEPAGE;
    notifyListeners();
  }

  void setCurrentQRUUID(String uuid) {
    currentQRUUID = uuid;
    notifyListeners();
  }
}

class ScanDocPage extends StatelessWidget {
  const ScanDocPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ScanDocAppState>();

    // set current page depending on the currentPage variable in state
    Widget? page;
    switch (appState.currentPage) {
      case Pages.HOMEPAGE:
        page = HomePage();
        break;
      case Pages.CAMERASCAN:
        page = CameraScanPage();
        break;
      case Pages.NFCSCAN:
        page = NFCScanPage();
        break;
      case Pages.RESULTS:
        page = ResultsPage();
        break;
      case Pages.QRSCAN:
        page = QRScanPage();
        break;
      default:
        page = const Placeholder();
    }

    // return page with banner
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
      body: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> primaryAnimation,
              Animation<double> secondaryAnimation) {
            return FadeThroughTransition(
              animation: primaryAnimation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
          child: page),
    );
  }
}
