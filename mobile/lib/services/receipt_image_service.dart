import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const int receiptImageMaxBytes = 8 * 1024 * 1024;
const double receiptImageMaxWidth = 2200;
const double receiptImageMaxHeight = 3200;
const int receiptImageQuality = 85;

final ImagePicker _receiptImagePicker = ImagePicker();

class ReceiptImageException implements Exception {
  const ReceiptImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<File?> pickReceiptFromCamera() {
  return _pickReceiptImage(
    source: ImageSource.camera,
    failureMessage:
        'Unable to open the camera. Please check camera permission and try again.',
  );
}

Future<File?> pickReceiptFromGallery() {
  return _pickReceiptImage(
    source: ImageSource.gallery,
    failureMessage:
        'Unable to open your photos. Please check photo permission and try again.',
  );
}

Future<File?> _pickReceiptImage({
  required ImageSource source,
  required String failureMessage,
}) async {
  try {
    final image = await _receiptImagePicker.pickImage(
      source: source,
      maxWidth: receiptImageMaxWidth,
      maxHeight: receiptImageMaxHeight,
      imageQuality: receiptImageQuality,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final file = File(image.path);
    final size = await file.length();
    if (size > receiptImageMaxBytes) {
      throw const ReceiptImageException(
        'Receipt image is too large. Please choose a smaller image or retake the photo closer to the receipt.',
      );
    }

    return file;
  } on ReceiptImageException {
    rethrow;
  } on PlatformException {
    throw ReceiptImageException(failureMessage);
  } catch (_) {
    throw ReceiptImageException(failureMessage);
  }
}
