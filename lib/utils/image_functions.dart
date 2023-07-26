import 'package:camerawesome/camerawesome_plugin.dart';

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
