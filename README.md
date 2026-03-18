# AgriDrone Guardian

Flutter control panel for AgriDrone mission control, Firebase telemetry, and backend/ESP32 developer tooling.

## Developer Tools

The app now includes a dedicated Developer Tools section with:
- ESP32 local controls using a persisted configurable IP address
- Backend multipart upload testing against `/predict_form`
- Latest backend debug image viewer for `/debug/latest.jpg`
- Firebase status and diagnostics panels

## Deployment Safety

Vercel routing is kept stable by:
- keeping `vercel.json` in the project root
- copying `vercel.json` into `build/web/vercel.json` during web builds
- deploying `build/web` instead of the repository root
- using a rewrite that sends all routes to `index.html`

## Local Run

```bash
flutter pub get
flutter run -d macos
```

## Web Build

```bash
./build_web.sh
```
