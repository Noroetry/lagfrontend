Background image for LAG frontend

Where to put the file
- Add your chosen image to: `assets/images/background.jpg` (or `.png`).
- Then update `lib/config/app_config.dart` and set `backgroundImagePath = 'assets/images/background.jpg';`
- Ensure `pubspec.yaml` has the assets declared under `flutter:` section, e.g.:

  assets:
    - assets/images/background.jpg

Recommended dimensions & format
- Use a wide image suitable for background wallpapers. Recommended sizes:
  - 1920x1080 (Full HD) as minimum
  - 2560x1440 or 3840x2160 for higher-res screens
- Use JPEG for photographic images; PNG if you need transparency.
- Keep file size under ~1.5MB for good initial load on mobile.

Design notes
- The app uses a dark grayscale UI. Choose an image that is dark overall (mostly dark grays/black) so the UI remains readable.
- If you want the fog/texture effect but with photograph, pick a subtle dark texture or blurred night scene.

How to test
- After placing the image and updating `app_config.dart`, run:

```bash
flutter pub get
flutter run
```

Troubleshooting
- If the asset doesn't appear, ensure the path matches exactly and that `pubspec.yaml` includes the asset and `flutter pub get` was run.
- If the image looks too bright, reduce its brightness in an editor or change the overlay opacity in `AppBackground`.