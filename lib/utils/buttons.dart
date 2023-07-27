import 'package:flutter/material.dart';
import 'package:scandoc_app/constants/constants.dart';
import 'package:scandoc_app/main.dart';

class ReturnButton extends StatelessWidget {
  // button that returns to homepage
  final ScanDocAppState appState;
  const ReturnButton({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        appState.storeExtractionData(appState.currentExtractionResult);
        appState.setCurrentPage(Pages.HOMEPAGE);
      },
      child: const Icon(Icons.keyboard_return),
    );
  }
}

class QRButton extends StatelessWidget {
  // button that redirects to qr scan page
  final ScanDocAppState appState;
  const QRButton({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.qr_code_2),
      onPressed: () {
        appState.setCurrentPage(Pages.QRSCAN);
      },
    );
  }
}

class ScanDocumentButton extends StatelessWidget {
  // button that redirects to camera scan page
  final ScanDocAppState appState;
  const ScanDocumentButton({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      label: const Text('Scan Document'),
      icon: const Icon(Icons.add),
      onPressed: () {
        appState.resetCurrentData();
        appState.setCurrentPage(Pages.CAMERASCAN);
      },
    );
  }
}
