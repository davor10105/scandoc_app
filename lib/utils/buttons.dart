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
