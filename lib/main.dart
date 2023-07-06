import 'dart:async';
import 'dart:html';
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'dart:convert';
import 'dart:async';

bool isNfcAvalible = false;

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  var availability = await FlutterNfcKit.nfcAvailability;
  isNfcAvalible = availability == NFCAvailability.available;

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  print(cameras.first.lensDirection);
  print(cameras);

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.light(),
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

Future<http.Response> callExtraction(
    String? frontDocumentImage, String? backDocumentImage) {
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
        'ShouldReturnFaceIfDetected': true,
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
  dynamic? currentNFCData;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  var capturedImageList = <XFile>[];
  String? frontDocumentImage;
  String? backDocumentImage;
  late Timer? _timer;
  bool shouldFlipImage = false;
  bool cameraRunning = false;
  dynamic currentExtractionResult;
  Map key_translate_dict = {
    "Name": "Name",
    "Surname": "Surname",
    "BirthDate": "Birth Date",
    "Gender": "Sex",
    "PlaceOfBirth": "Place of Birth",
    "Nationality": "Nationality",
    "DocumentNumber": "Document Number",
    "IssuedDate": "Date of Issue",
    "ExpiryDate": "Date of Expiry",
    "CountryOfIssue": "Country of Issue",
    "IssuingAuthority": "Issuing Authority",
    "AddressCountry": "Country",
    "AddressZip": "ZIP Code",
    "AddressCity": "City",
    "AddressCounty": "County",
    "AddressStreet": "Street",
    "PersonalIdentificationNumber": "Personal ID Number",
    "GivenName": "Given Name",
    "FamilyName": "Family Name",
    "MothersGivenName": "Mother's Given Name",
    "MothersFamilyName": "Mother's Family Name",
    "SecondLastName": "Second-Last Name",
    "Address": "Address",
    "PlaceOfIssue": "Place of Issue",
    "FathersGivenName": "Father's Given Name",
  };

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

  Future<void> processImages() async {
    var base64Images = [];
    var fullBase64Images = [];
    for (var capturedImage in capturedImageList) {
      img.Image? image = img.decodeImage(await capturedImage.readAsBytes());
      if (image != null) {
        print('Found image');
        Stopwatch stopwatch = Stopwatch()..start();

        if (shouldFlipImage) {
          image = img.flipHorizontal(image);
        }
        print('flip ${stopwatch.elapsed}');
        var resized = img.copyResize(image, width: 384);
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
    if (jsonValidationResult['Status'] == 200 &&
        jsonValidationResult['Validated']) {
      print('Boba');
      if (jsonValidationResult['Side'] == 'FRONT') {
        frontDocumentImage = fullBase64Images[jsonValidationResult['Index']];
      } else {
        backDocumentImage = fullBase64Images[jsonValidationResult['Index']];
      }

      print(jsonValidationResult['InfoCode']);
      print(jsonValidationResult['InfoCode'].runtimeType);
      if (jsonValidationResult['InfoCode'] == '1007') {
        if (frontDocumentImage == null || backDocumentImage == null) {
          print('Flip the document');
        } else {
          var extractionResult =
              await callExtraction(frontDocumentImage, backDocumentImage);
          frontDocumentImage = null;
          backDocumentImage = null;
          var jsonExtractionResult = jsonDecode(extractionResult.body);
          print(jsonDecode(extractionResult.body));
          setState(() {
            currentExtractionResult = jsonExtractionResult;
          });
        }
      } else if (jsonValidationResult['InfoCode'] == '1000') {
        print('Unisao');
        var extractionResult =
            await callExtraction(frontDocumentImage, backDocumentImage);
        frontDocumentImage = null;
        backDocumentImage = null;
        print(jsonDecode(extractionResult.body));
        var jsonExtractionResult = jsonDecode(extractionResult.body);
        setState(() {
          currentExtractionResult = jsonExtractionResult;
        });
      }
    }
  }

  Future<void> collectImagesWithTakePicture() async {
    if (!cameraRunning && currentExtractionResult == null) {
      cameraRunning = true;
      try {
        await _initializeControllerFuture;
        final currentImage = await _controller.takePicture();
        capturedImageList.add(currentImage);
      } catch (e) {
        print(e);
      }

      try {
        if (capturedImageList.length >= 1) {
          await processImages();
        }
      } catch (e) {
        print(e);
      }

      capturedImageList.clear();

      cameraRunning = false;
    }
  }

  void initializeCamera() async {
    _initializeControllerFuture = _controller.initialize();
    /*if (kIsWeb) {
      _timer =
          Timer.periodic(const Duration(milliseconds: 500), (_timer) async {
        collectImagesWithTakePicture();
      });
    } else {
      print('KURCINA');
      _controller.startImageStream((CameraImage image) {
        collectImagesWithImageStream(image);
      });
    }*/
    await _initializeControllerFuture;
    //_controller.setFocusMode(FocusMode.locked);
    //_controller.setFlashMode(FlashMode.off);

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_timer) async {
      await collectImagesWithTakePicture();
    });
  }

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    //_listenForNFCEvents();
    currentExtractionResult = null;
    shouldFlipImage =
        (widget.camera.lensDirection == CameraLensDirection.front ||
            widget.camera.lensDirection == CameraLensDirection.external);

    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
      enableAudio: false,
    );

    // Next, initialize the controller. This returns a Future.
    initializeCamera();
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
    var padding = MediaQuery.of(context).padding;
    var safeWidth =
        MediaQuery.of(context).size.width - padding.left - padding.right;
    var safeHeight =
        MediaQuery.of(context).size.height - padding.top - padding.bottom;
    if (currentExtractionResult == null) {
      _controller.resumePreview();
      return Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.white,
            toolbarHeight: safeHeight * 0.1,
            centerTitle: true,
            title: Container(
              child: SizedBox(
                height: safeHeight * 0.1 * 0.8,
                child: Image.asset('images/wide_scandoc.png'),
              ),
            )),
        // You must wait until the controller is initialized before displaying the
        // camera preview. Use a FutureBuilder to display a loading spinner until the
        // controller has finished initializing.
        body: Center(
          child: SizedBox(
            width: safeWidth,
            height: safeHeight,
            child: Container(
              color: Colors.lightBlue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Stack(
                      alignment: FractionalOffset.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                spreadRadius: 20,
                                blurRadius: 40,
                                offset:
                                    Offset(0, 0), // changes position of shadow
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: safeWidth * 0.8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30.0),
                              child: FutureBuilder<void>(
                                future: _initializeControllerFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.done) {
                                    // If the Future is complete, display the preview.
                                    if (shouldFlipImage) {
                                      return Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.rotationY(math.pi),
                                        child: CameraPreview(_controller),
                                      );
                                    }
                                    return CameraPreview(_controller);
                                  } else {
                                    // Otherwise, display a loading indicator.
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: safeWidth * 0.5,
                          height: safeWidth / 1.5 * 0.5,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: new BorderRadius.circular(10.0),
                            color: Color.fromARGB(28, 255, 255, 255),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              label: 'Camera',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.nfc_outlined),
              label: 'NFC',
            ),
          ],
          currentIndex: 0,
          selectedItemColor: const Color.fromARGB(255, 0, 26, 255),
          //onTap: _onItemTapped,
        ),
      );
    } else {
      print('Other site');
      _controller.pausePreview();

      List<Widget> extractedCards = [];
      for (var key in key_translate_dict.keys) {
        if (currentExtractionResult['Data'][key]['Read']) {
          bool validated = false;
          if (currentExtractionResult['Data'][key]['OCR']['Read'] &&
              currentExtractionResult['Data'][key]['MRZ']['Read']) {
            if (currentExtractionResult['Data'][key]['OCR']['Value']
                    .toString()
                    .toUpperCase() ==
                currentExtractionResult['Data'][key]['MRZ']['Value']
                    .toString()
                    .toUpperCase()) {
              validated = true;
            }
          }
          InkWell card = InkWell(
            onTap: () {
              print('Clicked');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return Column(
                    children: [
                      Text('OCR: ' +
                          currentExtractionResult['Data'][key]['OCR']['Value']
                              .toString()
                              .toUpperCase()),
                      Text('MRZ: ' +
                          currentExtractionResult['Data'][key]['MRZ']['Value']
                              .toString()
                              .toUpperCase())
                    ],
                  );
                }),
              );
            },
            child: Card(
              elevation: 5,
              color: Color.fromARGB(255, 255, 255, 255),
              child: Column(
                children: [
                  Text(
                    key_translate_dict[key].toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Color.fromARGB(255, 252, 122, 122),
                    ),
                  ),
                  Text(currentExtractionResult['Data'][key]['RecommendedValue'],
                      style: TextStyle(
                        fontFamily: 'Roboto',
                      )),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: validated
                          ? Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            )
                          : Icon(
                              Icons.close,
                              color: Colors.red,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
          extractedCards.add(card);
        }
      }

      return Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.white,
            toolbarHeight: safeHeight * 0.1,
            centerTitle: true,
            title: Container(
              child: SizedBox(
                height: safeHeight * 0.1 * 0.8,
                child: Image.asset('images/wide_scandoc.png'),
              ),
            )),
        body: Container(
          width: safeWidth,
          height: safeHeight,
          color: Colors.lightBlue,
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Column(
                    children: [
                      Container(
                        width: safeWidth * 0.6,
                        color: Color.fromARGB(255, 7, 39, 218),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CircleAvatar(
                            radius: safeHeight * 0.1,
                            backgroundImage: AssetImage(
                              'images/icons8-user-90.png',
                            ),
                          ),
                        ),
                      ),
                      Container(
                          width: safeWidth * 0.6,
                          color: Color.fromARGB(255, 255, 255, 255),
                          child: Column(
                            children: [
                              GridView.count(
                                shrinkWrap: true,
                                crossAxisCount: 3,
                                padding: const EdgeInsets.all(20),
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                children: extractedCards,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: FloatingActionButton(
                                  backgroundColor:
                                      Color.fromARGB(255, 7, 39, 218),
                                  onPressed: () {
                                    setState(() {
                                      currentExtractionResult = null;
                                      cameraRunning = false;
                                    });
                                  },
                                  child: Icon(
                                    Icons.keyboard_return,
                                  ),
                                ),
                              )
                            ],
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

/*  Widget _getNfcWidgets() {
    if (isNfcAvalible) {
      //For ios always false, for android true if running
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              currentNFCData != null
                  ? Container(
                      child: Column(
                        children: [
                          Card(
                            color: Colors.lightBlueAccent,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                      'Standard: ${currentNFCData['standard']}'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child:
                                      Text('Type: ${currentNFCData['type']}'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text('ID: ${currentNFCData['id']}'),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  : Container(),
            ],
          )
        ],
      );
    } else {
      if (Platform.isIOS) {
        //Ios doesnt allow the user to turn of NFC at all,  if its not avalible it means its not build in
        return const Text("Your device doesn't support NFC");
      } else {
        //Android phones can turn of NFC in the settings
        return const Text(
            "Your device doesn't support NFC or it's turned off in the system settings");
      }
    }
  }
  Future<void> _listenForNFCEvents() async {
    //Always run this for ios but only once for android
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        var tag = await FlutterNfcKit.poll(
            timeout: Duration(seconds: 5),
            iosMultipleTagMessage: "Multiple tags found!",
            iosAlertMessage: "Scan your tag");
        dynamic nfcData = json.decode(jsonEncode(tag));
        print(nfcData);
        if (tag.type == NFCTagType.iso7816) {
          var result = await FlutterNfcKit.transceive(
              "00A4000C"); // timeout is still Android-only, persist until next change
          print(result);
          setState(() {
            currentNFCData = nfcData;
          });
        }
      } catch (e) {
        print(e);
      }
      await FlutterNfcKit.finish();
      Timer(Duration(seconds: 2), () {
        _listenForNFCEvents();
      });
      //await FlutterNfcKit.finish(iosAlertMessage: "Success");
    }
  }
}*/








