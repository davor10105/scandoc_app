import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class InfoPanel extends StatefulWidget {
  final bool successExtraction;
  const InfoPanel({
    super.key,
    required this.successExtraction,
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
    return SizedBox(
      width: 100,
      child: Stack(children: [
        Container(
          alignment: Alignment.center,
          child: Image.asset(
            'images/icons8-checkmark-480.png',
            width: 70 - (pow(animation.value, 2) - 1) * 20,
          ),
        ),
        const SpinKitRing(
          color: Color.fromARGB(255, 227, 252, 198),
          size: 100.0,
        ),
      ]),
    );
  }
}
