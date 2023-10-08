import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:critter_sleuth/screens/preview_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;

import '../main.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

// class availableModels {
//   final List<String> models;

//   const availableModels({
//     required this.models,
//   });
//   factory availableModels.fromJson(Map<String, dynamic> json) {
//     List<String> modelsJSON = json['models'];
//     List<String> models = modelsJSON.map((model) => model['name']).toList();
//     return availableModels(models: models);
//   }

//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = new Map<String, dynamic>();
//     data['models'] = models.map((name) => {'name': name}).toList();
//     return data;
//   }
// }

class modelPrediction {
  final String name;

  final int hash;
  final List<List<dynamic>> pred;

  const modelPrediction({
    required this.name,
    required this.hash,
    required this.pred,
  });
  factory modelPrediction.fromJson(Map<String, dynamic> json) {
    List<dynamic> predJSON = json['pred'];
    List<List<dynamic>> pred = predJSON.map((p) => [p[0], p[1]]).toList();
    return modelPrediction(
      name: json['name'],
      hash: json['hash'],
      pred: pred,
    );
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = name;
    data['hash'] = hash;
    data['pred'] = pred.map((p) => [p[0], p[1]]).toList();
    return data;
  }
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;

  File? _imageFile;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isRearCameraSelected = true;
  bool _isRecordingInProgress = false;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];

  final resolutionPresets = ResolutionPreset.values;

  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      log('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      refreshAlreadyCapturedImages();
    } else {
      log('Camera Permission: DENIED');
    }
  }

  // Service service = Service();
  // final _addFormKey = GlobalKey<FormState>();
  // final _titleController = TextEditingController();

  // late File _image;
  // final picker = ImagePicker();

  refreshAlreadyCapturedImages() async {
    // final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    // setState(() {
    //   if (pickedFile != null) {
    //     _image = File(pickedFile.path);
    //   } else {
    //     print('No image selected.');
    //   }
    // });
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];

    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      if (recentFileName.contains('.mp4')) {
        _imageFile = null;
      } else {
        _imageFile = File('${directory.path}/$recentFileName');
      }

      setState(() {});
    }
  }

  // Camera Functions

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      // addImage(file.path);
      modelPrediction pred = await addImage(file.path);
      print("THIS RAN");
      print(pred.name);
      pred.pred
          .sort((a, b) => double.parse(b[0]).compareTo(double.parse(a[0])));

      List<String> formattedResults = [];
      for (int i = 0; i < pred.pred.length && i < 5; i++) {
        dynamic probability = pred.pred[i][0];
        if (probability is String) {
          probability = double.tryParse(probability);
          if (probability == null) {
            throw FormatException(
                'Unexpected format: probability is not a number');
          }
        }
        String className = pred.pred[i][1];
        String formattedProbability =
            '${(probability * 100).toStringAsFixed(2)}%';
        String formattedResult = '${i + 1}: $className ($formattedProbability)';
        formattedResults.add(formattedResult);
      }
      String resultsText = formattedResults.join('\n');

      results = resultsText;
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);

      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  // Rest API Functions
  final apiDomain = "https://crittersleuthbackend.keshuac.com/";
  // Future<availableModels> fetchAvailableModels() async {
  //   final response = await http.get(Uri.parse(api + '/available_models'));

  //   if (response.statusCode == 200) {
  //     // If the server did return a 200 OK response,
  //     // then parse the JSON.
  //     return availableModels.fromJson(jsonDecode(response.body));
  //   } else {
  //     // If the server did not return a 200 OK response,
  //     // then throw an exception.
  //     throw Exception('Failed to load album');
  //   }
  // }
  var results = "";

  List<modelPrediction> parsePredictionsList(String responseBody) {
    final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();
    return parsed
        .map<modelPrediction>((json) => modelPrediction.fromJson(json))
        .toList();
  }

  Future<modelPrediction> addImage(String filepath) async {
    String addimageUrl = apiDomain + 'api/v1/upload_json';
    Map<String, String> headers = {
      'Content-Type': 'multipart/form-data',
    };
    var request = http.MultipartRequest('POST', Uri.parse(addimageUrl))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('files', filepath));
    var response = await request.send();

    String responseBody = await response.stream.bytesToString();
    // print("THIS RAN");
    // print(responseBody);

    List<modelPrediction> parsed = parsePredictionsList(responseBody);
    return parsed[0];
  }

  Future<void> _dialogBuilder(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32.0)),
          ),
          title: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(0xFF4ADE80), Color(0xFF38BDF8)],
            ).createShader(bounds),
            child: Text('Prediction Results',
                style: GoogleFonts.varela(
                  textStyle: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                )),
          ),
          content: Text(results, style: GoogleFonts.varela()),
          actions: <Widget>[
            TextButton(
              child: Text('Close',
                  style: GoogleFonts.varela(
                    textStyle: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // TextButton(
            //   child: Text('OK'),
            //   onPressed: () {
            //     Navigator.of(context).pop(true);
            //   },
            // ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    // Hide the status bar in Android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    getPermissionStatus();
    // late Future<http.Response> availableModels = fetchAvailableModels();
    // logResponseJson(availableModels);

    super.initState();
  }

  void logResponseJson(Future<http.Response> responseFuture) async {
    http.Response response = await responseFuture;
    if (response.statusCode == 200) {
      String responseBody = response.body;
      print(responseBody);
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isCameraPermissionGranted
            ? _isCameraInitialized
                ? Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / controller!.value.aspectRatio,
                        child: Stack(
                          children: [
                            CameraPreview(
                              controller!,
                              child: LayoutBuilder(builder:
                                  (BuildContext context,
                                      BoxConstraints constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (details) =>
                                      onViewFinderTap(details, constraints),
                                );
                              }),
                            ),
                            // TODO: Uncomment to preview the overlay
                            // Center(
                            //   child: Image.asset(
                            //     'assets/camera_aim.png',
                            //     color: Colors.greenAccent,
                            //     width: 150,
                            //     height: 150,
                            //   ),
                            // ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16.0,
                                8.0,
                                16.0,
                                8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                          right: 8.0,
                                        ),
                                        child: DropdownButton<ResolutionPreset>(
                                          dropdownColor: Colors.black87,
                                          underline: Container(),
                                          value: currentResolutionPreset,
                                          items: [
                                            for (ResolutionPreset preset
                                                in resolutionPresets)
                                              DropdownMenuItem(
                                                child: Text(
                                                  preset
                                                      .toString()
                                                      .split('.')[1]
                                                      .toUpperCase(),
                                                  style: GoogleFonts.varela(
                                                    textStyle: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                                value: preset,
                                              )
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              currentResolutionPreset = value!;
                                              _isCameraInitialized = false;
                                            });
                                            onNewCameraSelected(
                                                controller!.description);
                                          },
                                          hint: Text("Select item"),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8.0, top: 16.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          _currentExposureOffset
                                                  .toStringAsFixed(1) +
                                              'x',
                                          style: GoogleFonts.varela(
                                            textStyle:
                                                TextStyle(color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: Container(
                                        height: 30,
                                        child: Slider(
                                          value: _currentExposureOffset,
                                          min: _minAvailableExposureOffset,
                                          max: _maxAvailableExposureOffset,
                                          activeColor: Color(0xFF4ADE80),
                                          inactiveColor: Colors.white30,
                                          onChanged: (value) async {
                                            setState(() {
                                              _currentExposureOffset = value;
                                            });
                                            await controller!
                                                .setExposureOffset(value);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Slider(
                                          value: _currentZoomLevel,
                                          min: _minAvailableZoom,
                                          max: _maxAvailableZoom,
                                          activeColor: Color(0xFF4ADE80),
                                          inactiveColor: Colors.white30,
                                          onChanged: (value) async {
                                            setState(() {
                                              _currentZoomLevel = value;
                                            });
                                            await controller!
                                                .setZoomLevel(value);
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              _currentZoomLevel
                                                      .toStringAsFixed(1) +
                                                  'x',
                                              style: GoogleFonts.varela(
                                                textStyle: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isCameraInitialized = false;
                                          });
                                          onNewCameraSelected(cameras[
                                              _isRearCameraSelected ? 1 : 0]);
                                          setState(() {
                                            _isRearCameraSelected =
                                                !_isRearCameraSelected;
                                          });
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Colors.black38,
                                              size: 60,
                                            ),
                                            Icon(
                                              _isRearCameraSelected
                                                  ? Icons.camera_front
                                                  : Icons.camera_rear,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          XFile? rawImage = await takePicture();
                                          File imageFile = File(rawImage!.path);

                                          int currentUnix = DateTime.now()
                                              .millisecondsSinceEpoch;

                                          final directory =
                                              await getApplicationDocumentsDirectory();

                                          String fileFormat =
                                              imageFile.path.split('.').last;

                                          print(fileFormat);

                                          await imageFile.copy(
                                            '${directory.path}/$currentUnix.$fileFormat',
                                          );
                                          _dialogBuilder(context);
                                          refreshAlreadyCapturedImages();
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Colors.white,
                                              size: 80,
                                            ),
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  LinearGradient(
                                                colors: [
                                                  Color(0xFF4ADE80),
                                                  Color(0xFF38BDF8)
                                                ],
                                              ).createShader(bounds),
                                              child: Icon(
                                                Icons.circle,
                                                color: Colors.white,
                                                size: 65,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _imageFile != null
                                            ? () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PreviewScreen(
                                                      imageFile: _imageFile!,
                                                      fileList: allFileList,
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            image: _imageFile != null
                                                ? DecorationImage(
                                                    image:
                                                        FileImage(_imageFile!),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                              color: Colors.black,
                              width: 2.0,
                            )),
                          ),
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16.0, 16.0, 16.0, 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          if (_currentFlashMode ==
                                              FlashMode.off) {
                                            setState(() {
                                              _currentFlashMode =
                                                  FlashMode.always;
                                            });
                                            await controller!.setFlashMode(
                                              FlashMode.always,
                                            );
                                          } else {
                                            setState(() {
                                              _currentFlashMode = FlashMode.off;
                                            });
                                            await controller!.setFlashMode(
                                              FlashMode.off,
                                            );
                                          }
                                        },
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return LinearGradient(
                                              colors: _currentFlashMode !=
                                                      FlashMode.off
                                                  ? [Colors.black, Colors.black]
                                                  : [
                                                      Color(0xFF4ADE80),
                                                      Color(0xFF38BDF8)
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              tileMode: TileMode.clamp,
                                            ).createShader(bounds);
                                          },
                                          child: Icon(
                                            Icons.flash_off,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          setState(() {
                                            _currentFlashMode = FlashMode.auto;
                                          });
                                          await controller!.setFlashMode(
                                            FlashMode.auto,
                                          );
                                        },
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return LinearGradient(
                                              colors: _currentFlashMode !=
                                                      FlashMode.auto
                                                  ? [Colors.black, Colors.black]
                                                  : [
                                                      Color(0xFF4ADE80),
                                                      Color(0xFF38BDF8)
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              tileMode: TileMode.clamp,
                                            ).createShader(bounds);
                                          },
                                          child: Icon(
                                            Icons.flash_auto,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          setState(() {
                                            _currentFlashMode =
                                                FlashMode.always;
                                          });
                                          await controller!.setFlashMode(
                                            FlashMode.always,
                                          );
                                        },
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return LinearGradient(
                                              colors: _currentFlashMode !=
                                                      FlashMode.always
                                                  ? [Colors.black, Colors.black]
                                                  : [
                                                      Color(0xFF4ADE80),
                                                      Color(0xFF38BDF8)
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              tileMode: TileMode.clamp,
                                            ).createShader(bounds);
                                          },
                                          child: Icon(
                                            Icons.flash_on,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          setState(() {
                                            _currentFlashMode = FlashMode.torch;
                                          });
                                          await controller!.setFlashMode(
                                            FlashMode.torch,
                                          );
                                        },
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return LinearGradient(
                                              colors: _currentFlashMode !=
                                                      FlashMode.torch
                                                  ? [Colors.black, Colors.black]
                                                  : [
                                                      Color(0xFF4ADE80),
                                                      Color(0xFF38BDF8)
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              tileMode: TileMode.clamp,
                                            ).createShader(bounds);
                                          },
                                          child: Icon(
                                            Icons.highlight,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      'LOADING',
                      style: GoogleFonts.varela(
                        textStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(),
                  Text(
                    'Permission denied',
                    style: GoogleFonts.varela(
                      textStyle: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      getPermissionStatus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Give permission',
                        style: GoogleFonts.varela(
                          textStyle:
                              TextStyle(color: Colors.white, fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
