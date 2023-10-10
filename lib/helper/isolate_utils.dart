import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imageLib;
import 'package:critter_sleuth/helper/image_utils.dart';
import 'package:critter_sleuth/helper/classifier_quant.dart';

// import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

/// Manages separate Isolate instance for inference
class IsolateUtils {
  static const String DEBUG_NAME = "InferenceIsolate";

  late Isolate _isolate;
  ReceivePort _receivePort = ReceivePort();
  late SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: DEBUG_NAME,
    );

    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final IsolateData isolateData in port) {
      if (isolateData != null) {
        ClassifierQuant _classifier = ClassifierQuant();

        imageLib.Image image = ImageUtils.convertCameraImage(
          isolateData.cameraImage,
        )!;
        TensorImage t_image = TensorImage.fromImage(image);
        var imageProcessor = ImageProcessorBuilder()
            .add(ResizeOp(299, 299, ResizeMethod.BILINEAR))
            .add(NormalizeOp(0, 255))
            .build();
        t_image = _convertToGrayscale(t_image);
        t_image = imageProcessor.process(t_image);

        // imageLib.Image image =
        //     ImageUtils.convertCameraImage(isolateData.cameraImage);

        Category results = _classifier.predictImage(t_image);
        isolateData.responsePort.send(results);
      }
    }
  }

  static TensorImage _convertToGrayscale(TensorImage tensorImage) {
    // Convert the image to grayscale.
    var pixels = tensorImage.getTensorBuffer().getIntList();
    for (int i = 0; i < pixels.length; i += 3) {
      var pixel =
          (0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2])
              .toInt();
      pixels[i] = pixel;
      pixels[i + 1] = pixel;
      pixels[i + 2] = pixel;
    }
    tensorImage.loadTensorBuffer(tensorImage.getTensorBuffer());
    return tensorImage;
  }
}

/// Bundles data to pass between Isolate
class IsolateData {
  CameraImage cameraImage;
  int interpreterAddress;
  late SendPort responsePort;

  IsolateData(
    this.cameraImage,
    this.interpreterAddress,
  );
}
