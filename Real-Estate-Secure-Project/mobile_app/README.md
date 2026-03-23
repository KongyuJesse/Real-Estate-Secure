# Real Estate Secure Mobile App

Flutter Android client for the Real Estate Secure marketplace.

## Local Development

```powershell
cd mobile_app
flutter pub get
flutter run
```

## Google Maps

The mobile app reads the Android Google Maps key from `mobile_app/.env`.

1. Copy `mobile_app/.env.example` to `mobile_app/.env`
2. Set `GOOGLE_MAPS_API_KEY=your_android_maps_sdk_key`
3. Enable `Maps SDK for Android` in Google Cloud
4. Restrict the key to package `com.example.real_estate_secure`
5. Add the SHA-1 fingerprint for the keystore you use to run the app
6. Run `flutter pub get`
7. Run `flutter run`

The Android build injects that key into the app manifest automatically.
Use a restricted Android key in Google Cloud with your package name and SHA-1 fingerprint.

## Backend Connection

The app now resolves its API base URL automatically:

- Android emulator debug builds: `http://10.0.2.2:8080/v1`
- USB-connected physical Android debug builds: `http://127.0.0.1:8080/v1`
- Release builds: `https://api.realestatesecure.cm/v1`

For a USB-connected Android phone, the Gradle debug build now runs
`adb reverse tcp:8080 tcp:8080` automatically so the app can reach the backend
without relying on laptop LAN routing or Windows firewall exceptions.

To override that explicitly:

```powershell
flutter run --dart-define=RES_API_BASE_URL=http://10.0.2.2:8080/v1
```

## Authentication

- Mobile registration is limited to: `buyer`, `seller`, `landlord`, `tenant`, `lawyer`, and `agent`
- `admin` and `super_admin` accounts are intentionally blocked from the Android app
- Successful sign-in persists only auth/session values required by the app

## Checks

```powershell
flutter analyze
flutter test --no-pub test/widget_test.dart
```
