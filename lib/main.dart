import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  print(cameras.first.lensDirection);
  print(cameras);

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

Future<http.Response> callValidation(List<dynamic> base64EncodedImages) {
  print("Call validation");
  return http.post(
    Uri.parse('http://localhost:4000/validation/'),
    headers: <String, String>{
      'Authorization': 'TOKEN',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'AcceptTermsAndConditions': true,
      'DataFields': {
        'Images': base64EncodedImages,
      },
      'Settings': {
        'SkipImageSizeCheck': true,
      }
    }),
  );
}

Future<http.Response> callExtraction(String? frontDocumentImage, String? backDocumentImage) {
  print("Call extraction");
  bool shouldSendBackImage = !(backDocumentImage == null);
  return http.post(
    Uri.parse('http://localhost:4000/extraction/'),
    headers: <String, String>{
      'Authorization': 'TOKEN',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'AcceptTermsAndConditions': true,
      'DataFields': {
        'BackImage': shouldSendBackImage ? backDocumentImage : '',
        'BackImageCropped': false,
        'BackImageType': 'base64',
        'FrontImage': frontDocumentImage,
        'FrontImageCropped': false,
        'FrontImageType': 'base64',
      },
      'Settings': {
        'IgnoreBackImage': !shouldSendBackImage,
        'ShouldReturnDocumentImage': false,
        'ShouldReturnFaceIfDetected': false,
        'ShouldReturnSignatureIfDetected': false,
        'ShouldValidate': true,
        'SkipImageSizeCheck': true,
        'SkipDocumentSizeCheck': true,
      },

    }),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  var capturedImageList = <XFile>[];
  String? frontDocumentImage;
  String? backDocumentImage;
  late Timer? _timer;
  bool shouldFlipImage = false;
  bool cameraRunning = false;
  dynamic currentExtractionResult;

   Future<Uint8List> testComporessList(Uint8List list) async {
    var result = await FlutterImageCompress.compressWithList(
      list,
      minHeight: 1920,
      minWidth: 1080,
      quality: 96,
      rotate: 135,
    );
    print(list.length);
    print(result.length);
    return result;
  }

  Future<void> processImages() async{
    if (!cameraRunning && currentExtractionResult == null){
      cameraRunning = true;
      try {
        await _initializeControllerFuture;
        final currentImage = await _controller.takePicture();
        capturedImageList.add(currentImage);
        if (capturedImageList.length >= 1) {
          var base64Images = [];
          var fullBase64Images = [];
          for (var capturedImage in capturedImageList) {
            img.Image? image = img.decodeImage(await capturedImage.readAsBytes());
            if (image != null){
              print('Found image');
              Stopwatch stopwatch = Stopwatch()..start();
              
              if (shouldFlipImage){
                image = img.flipHorizontal(image);
              }
              print('flip ${stopwatch.elapsed}');
              var resized = img.copyResize(image, width:384);
              print('resize ${stopwatch.elapsed}');
              var resizedJpg = Uint8List.fromList(img.encodePng(resized));
              var fullJpg = Uint8List.fromList(img.encodePng(image));
              print('png encode ${stopwatch.elapsed}');
              //var base64Image = base64Encode(await capturedImage.readAsBytes());
              var base64Image = base64Encode(resizedJpg);
              var fullBase64Image = base64Encode(fullJpg);
              //var base64Image = base64Encode(resized.getBytes());//base64Encode(resized.toUint8List());
              //var fullBase64Image = base64Encode(image.getBytes());//base64Encode(image.toUint8List());
              print('base64 encode ${stopwatch.elapsed}');
              base64Images.add(base64Image);
              fullBase64Images.add(fullBase64Image);
            }
          }
          var validationResult = await callValidation(base64Images);
          var jsonValidationResult = jsonDecode(validationResult.body);
          print(jsonValidationResult);
          print(jsonValidationResult['Index'].runtimeType);
          if (jsonValidationResult['Status'] == 200 && jsonValidationResult['Validated']) {
            print('Boba');
            if (jsonValidationResult['Side'] == 'FRONT'){
              frontDocumentImage = fullBase64Images[jsonValidationResult['Index']];
            }
            else {
              backDocumentImage = fullBase64Images[jsonValidationResult['Index']];
            }

            print(jsonValidationResult['InfoCode']);
            print(jsonValidationResult['InfoCode'].runtimeType);
            if (jsonValidationResult['InfoCode'] == '1007'){
              if (frontDocumentImage == null || backDocumentImage == null){
                print('Flip the document');
              } else {
                var extractionResult = await callExtraction(frontDocumentImage, backDocumentImage);
                frontDocumentImage = null;
                backDocumentImage = null;
                var jsonExtractionResult = jsonDecode(extractionResult.body);
                print(jsonDecode(extractionResult.body));
                setState(() {
                  currentExtractionResult = jsonExtractionResult;
                  capturedImageList.clear();
                });
              }
            } else if (jsonValidationResult['InfoCode'] == '1000') {
              print('Unisao');
              var extractionResult = await callExtraction(frontDocumentImage, backDocumentImage);
              frontDocumentImage = null;
              backDocumentImage = null;
              print(jsonDecode(extractionResult.body));
              var jsonExtractionResult = jsonDecode(extractionResult.body);
              setState(() {
                  currentExtractionResult = jsonExtractionResult;
                  capturedImageList.clear();
                });
            }
          }
          capturedImageList.clear();
        }
        } catch (e) {
          print(e);
        }
      cameraRunning = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    currentExtractionResult = null;
    shouldFlipImage = (widget.camera.lensDirection == CameraLensDirection.front || widget.camera.lensDirection == CameraLensDirection.external);

    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
      enableAudio: false,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_timer) async {
      processImages();
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    _timer?.cancel();
    _timer = null;
    cameraRunning = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentExtractionResult == null){
      return Scaffold(
        appBar: AppBar(title: const Text('Take a picture')),
        // You must wait until the controller is initialized before displaying the
        // camera preview. Use a FutureBuilder to display a loading spinner until the
        // controller has finished initializing.
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // If the Future is complete, display the preview.
              if (shouldFlipImage){
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: CameraPreview(_controller),
                );
              }
              return CameraPreview(_controller);
            } else {
              // Otherwise, display a loading indicator.
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
        
      );
    } else {
      _controller.pausePreview();
      return Scaffold(
        body: Column(
          children:
            [
              Text(currentExtractionResult.toString()),
              FloatingActionButton(onPressed: () {
                _controller.resumePreview();
                setState(() {
                  currentExtractionResult = null;
                });
              })
            ]
          ),
      );
      
  }
}
}