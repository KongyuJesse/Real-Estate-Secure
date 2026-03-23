import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class LocalUploadFile {
  const LocalUploadFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final List<int> bytes;
}

class LocalUploadQualityReport {
  const LocalUploadQualityReport({
    required this.isAcceptable,
    required this.summary,
    this.issues = const <String>[],
    this.width,
    this.height,
    this.bytesLength,
  });

  final bool isAcceptable;
  final String summary;
  final List<String> issues;
  final int? width;
  final int? height;
  final int? bytesLength;
}

enum LocalImageQualityTarget { document, selfie, propertyPhoto }

Future<LocalUploadFile?> pickImageForUpload() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    withData: true,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  );
  return _mapPlatformFile(result?.files.singleOrNull);
}

Future<LocalUploadFile?> pickDocumentForUpload() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    withData: true,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
  );
  return _mapPlatformFile(result?.files.singleOrNull);
}

Future<LocalUploadFile?> captureImageForUpload({
  bool useFrontCamera = false,
}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: useFrontCamera
        ? CameraDevice.front
        : CameraDevice.rear,
    imageQuality: 92,
    maxWidth: 2400,
  );
  return _mapXFile(file);
}

Future<LocalUploadFile?> captureVideoForUpload() async {
  final picker = ImagePicker();
  final file = await picker.pickVideo(
    source: ImageSource.camera,
    maxDuration: const Duration(seconds: 12),
    preferredCameraDevice: CameraDevice.front,
  );
  return _mapXFile(file);
}

Future<LocalUploadQualityReport> assessImageForUpload(
  LocalUploadFile file, {
  required LocalImageQualityTarget target,
}) async {
  final bytes = Uint8List.fromList(file.bytes);
  final image = await _decodeImage(bytes);
  if (image == null) {
    return const LocalUploadQualityReport(
      isAcceptable: false,
      summary: 'We could not inspect this image locally. Capture it again.',
      issues: ['Image preview failed'],
    );
  }

  final minEdge = image.width < image.height ? image.width : image.height;
  final maxEdge = image.width > image.height ? image.width : image.height;
  final sizeKb = file.bytes.length / 1024;
  final issues = <String>[];

  if (target == LocalImageQualityTarget.document) {
    if (minEdge < 900 || maxEdge < 1400) {
      issues.add('Use a sharper document capture with more visible detail.');
    }
    if (sizeKb < 140) {
      issues.add(
        'The file looks heavily compressed. Recapture without zooming.',
      );
    }
  } else if (target == LocalImageQualityTarget.selfie) {
    if (minEdge < 720 || maxEdge < 960) {
      issues.add('Retake the selfie with the face closer and fully in frame.');
    }
    if (sizeKb < 100) {
      issues.add('The selfie file is too small to be reliable.');
    }
  } else {
    if (minEdge < 1080 || maxEdge < 1600) {
      issues.add(
        'Capture the property again with more visible detail and a steadier frame.',
      );
    }
    if (sizeKb < 180) {
      issues.add(
        'The listing image looks too compressed for a premium discovery card.',
      );
    }
  }

  return LocalUploadQualityReport(
    isAcceptable: issues.isEmpty,
    summary: issues.isEmpty
        ? 'Local quality checks passed.'
        : 'Local quality checks found items to improve.',
    issues: issues,
    width: image.width,
    height: image.height,
    bytesLength: file.bytes.length,
  );
}

LocalUploadFile? _mapPlatformFile(PlatformFile? file) {
  final bytes = file?.bytes;
  if (file == null || bytes == null || bytes.isEmpty) {
    return null;
  }
  return LocalUploadFile(
    name: file.name,
    mimeType: _mimeTypeForName(file.name),
    bytes: bytes,
  );
}

Future<LocalUploadFile?> _mapXFile(XFile? file) async {
  if (file == null) {
    return null;
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    return null;
  }
  return LocalUploadFile(
    name: file.name,
    mimeType: _mimeTypeForName(file.name),
    bytes: bytes,
  );
}

Future<ui.Image?> _decodeImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

String _mimeTypeForName(String fileName) {
  final normalized = fileName.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  if (normalized.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (normalized.endsWith('.mp4')) {
    return 'video/mp4';
  }
  if (normalized.endsWith('.mov')) {
    return 'video/quicktime';
  }
  return 'application/octet-stream';
}
