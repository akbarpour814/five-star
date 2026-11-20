# FiveStar

Flutter app (Android / iOS / Web) for controlling the FiveStar **GSA-212** SIM-card alarm over SMS.

## Architecture

Feature-first clean architecture with BLoC (`flutter_bloc`) and `get_it` DI.

```
lib/
  core/            theme, DI, storage, SMS gateways (Android native / composer), shared widgets
  features/
    auth/          app PIN (4 digits, salted SHA-256), biometric login, lock screen, reset app
    devices/       multi-device registry, device dashboard, message log, paste-reply page
    gsa212/        command builder + reply parser for every 212 SMS code, settings pages
```

- **Android**: commands are sent directly through `SmsManager`; replies from registered device numbers are
  captured by `SmsReceiver` (also while the app is closed) and processed automatically.
- **iOS / Web**: the messaging app opens with the command pre-filled; the user pastes the device reply into
  “ثبت پاسخ دستگاه”.
- The manual's two-minute gap between SMS to the device is enforced per device with a visible countdown.

## Build

pub.dev is not reachable from this network directly; use the Flutter China mirror:

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get
flutter test
flutter build apk --release
flutter build web --no-web-resources-cdn   # bundles CanvasKit instead of loading it from gstatic
```

Android compiles against SDK 37 (required by `permission_handler_android`).
App icons are generated from `assets/images/app_icon*.png` with `dart run flutter_launcher_icons`.
