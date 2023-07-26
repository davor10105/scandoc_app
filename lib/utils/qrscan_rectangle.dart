import 'package:flutter/material.dart';

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
