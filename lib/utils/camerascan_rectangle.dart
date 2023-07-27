import 'dart:math';

import 'package:flutter/material.dart';
import 'package:scandoc_app/utils/camerascan_infopanel.dart';

class RectangleDisplay extends StatefulWidget {
  final bool needsFlip;
  final bool successExtraction;

  const RectangleDisplay({
    super.key,
    required this.needsFlip,
    required this.successExtraction,
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
                  ? InfoPanel(
                      successExtraction: widget.successExtraction,
                    )
                  : Container(),
            ),
          ),
        ],
      ),
    );
  }
}
