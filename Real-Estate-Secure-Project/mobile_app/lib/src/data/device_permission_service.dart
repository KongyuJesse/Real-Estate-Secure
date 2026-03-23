import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum ConsumerPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unavailable,
}

@immutable
class ConsumerCameraPermissionStatus {
  const ConsumerCameraPermissionStatus({
    this.state = ConsumerPermissionState.unavailable,
  });

  final ConsumerPermissionState state;

  bool get isGranted => state == ConsumerPermissionState.granted;

  bool get requiresSettings =>
      state == ConsumerPermissionState.permanentlyDenied ||
      state == ConsumerPermissionState.restricted;

  String get label {
    switch (state) {
      case ConsumerPermissionState.granted:
        return 'Camera ready';
      case ConsumerPermissionState.denied:
        return 'Camera blocked';
      case ConsumerPermissionState.permanentlyDenied:
        return 'Open settings';
      case ConsumerPermissionState.restricted:
        return 'Restricted';
      case ConsumerPermissionState.limited:
        return 'Limited';
      case ConsumerPermissionState.unavailable:
        return 'Unavailable';
    }
  }

  String get summary {
    switch (state) {
      case ConsumerPermissionState.granted:
        return 'Live capture is ready for KYC, listing photos, and evidence scans.';
      case ConsumerPermissionState.denied:
        return 'Camera access is required for live selfie, document, and property capture. You can allow it now.';
      case ConsumerPermissionState.permanentlyDenied:
        return 'Camera access was blocked at the system level. Open app settings to allow live capture again.';
      case ConsumerPermissionState.restricted:
        return 'Camera access is restricted on this device profile.';
      case ConsumerPermissionState.limited:
        return 'Camera access is only partially available on this device.';
      case ConsumerPermissionState.unavailable:
        return 'This device does not currently expose camera permission controls through the app.';
    }
  }
}

abstract interface class ConsumerDevicePermissionService {
  Future<ConsumerCameraPermissionStatus> getCameraStatus();

  Future<ConsumerCameraPermissionStatus> requestCameraAccess();

  Future<bool> openSystemSettings();
}

class PlatformConsumerDevicePermissionService
    implements ConsumerDevicePermissionService {
  const PlatformConsumerDevicePermissionService();

  @override
  Future<ConsumerCameraPermissionStatus> getCameraStatus() async {
    if (kIsWeb) {
      return const ConsumerCameraPermissionStatus();
    }
    return _mapStatus(await Permission.camera.status);
  }

  @override
  Future<ConsumerCameraPermissionStatus> requestCameraAccess() async {
    if (kIsWeb) {
      return const ConsumerCameraPermissionStatus();
    }
    return _mapStatus(await Permission.camera.request());
  }

  @override
  Future<bool> openSystemSettings() => openAppSettings();

  ConsumerCameraPermissionStatus _mapStatus(PermissionStatus status) {
    final state = switch (status) {
      PermissionStatus.granted => ConsumerPermissionState.granted,
      PermissionStatus.denied => ConsumerPermissionState.denied,
      PermissionStatus.permanentlyDenied =>
        ConsumerPermissionState.permanentlyDenied,
      PermissionStatus.restricted => ConsumerPermissionState.restricted,
      PermissionStatus.limited => ConsumerPermissionState.limited,
      PermissionStatus.provisional => ConsumerPermissionState.limited,
    };
    return ConsumerCameraPermissionStatus(state: state);
  }
}
