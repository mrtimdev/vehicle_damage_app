# Vehicle Damage Analyzer (Flutter)

An AI-assisted vehicle damage analysis app. Users capture photos, record
video, or upload existing media of a vehicle; the app sends it to a
**user-configurable AI provider** and returns a structured damage report
with bilingual (English/Khmer) part labels and per-finding confidence
scores.

## ⚠️ Important: on accuracy

**No current AI vision model can guarantee 100% accurate damage
detection.** Lighting, camera angle, dirt, reflections, and ambiguous
dents all introduce real error. This app is built around that fact
instead of hiding it:

- Every finding carries a `confidence` score (0–1) returned by the model itself.
- Findings under 60% confidence are flagged in the UI (`needsReview`) for
  manual human verification.
- The report always shows the raw AI summary alongside the structured
  findings, so nothing is silently discarded.

Treat this as a **decision-support tool**, not a certified/legal damage
assessment. For insurance or legal purposes, AI output should be reviewed
by a qualified human inspector.

## Features

- **Configurable AI provider** (Settings tab): choose OpenAI, Anthropic
  (Claude), Google Gemini, or a Custom/self-hosted endpoint — set your own
  Base URL, API key, and model name. Keys are stored in the platform
  Keychain/Keystore via `flutter_secure_storage`, never in plain prefs.
- **Capture, record, and upload**: take a photo, record a short video, or
  pick existing photos/videos from the gallery (`image_picker`).
- **Structured, bilingual report**: part name in English + Khmer, damage
  type, severity (minor/moderate/severe), confidence score, and notes.
- **Local history**: past reports are saved on-device with Hive so users
  can revisit them offline.

## Project structure

```
lib/
  models/            # AIProviderConfig, DamageReport, DamageItem
  providers/          # AIProvider interface + OpenAI/Anthropic/Gemini/Custom adapters
  services/           # ConfigService (secure storage), HistoryService (Hive), AnalysisService
  screens/            # Capture, Settings, Report, History, Home (tab shell)
  utils/              # media_utils.dart — video frame extraction hook
```

The AI backend is fully pluggable: every provider implements the same
`AIProvider.analyzeImages()` interface (see `lib/providers/ai_provider.dart`),
so switching providers is just picking a different adapter in
`provider_factory.dart` based on the user's saved config — no UI or
business-logic changes needed.

## Setup

1. Install Flutter (3.22+) and run:
   ```bash
   flutter pub get
   ```
2. Merge the platform permission snippets into your generated native
   projects (these are reference files, not drop-in replacements):
   - `android/app/src/main/AndroidManifest.xml` → merge `<uses-permission>`
     entries into your real manifest.
   - `ios/Runner/Info-additions.plist` → merge the `NSCameraUsageDescription`
     etc. keys into your real `ios/Runner/Info.plist`.
3. Generate Hive/JSON adapters if you extend the models with `@HiveType`/
   `@JsonSerializable` annotations:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. Run the app:
   ```bash
   flutter run
   ```
5. Open **Settings** in the app and enter your AI provider's Base URL,
   API key, and model name before running an analysis.

## Wiring up video analysis

Vision APIs (OpenAI, Anthropic, Gemini) currently accept still images, not
raw video. `lib/utils/media_utils.dart` has a documented `extractFrames()`
stub — plug in a plugin like `video_thumbnail` or `ffmpeg_kit_flutter` to
pull a handful of representative frames from a recorded clip; those frames
then flow through the exact same `AnalysisService.analyze()` path as
photos. This is left as a stub deliberately since the right plugin choice
depends on your target platforms and binary-size/licensing constraints.

## Extending to a new AI provider

1. Create `lib/providers/your_provider.dart` implementing `AIProvider`.
2. Add it to `AIProviderKind` in `lib/models/ai_provider_config.dart`.
3. Register it in `lib/providers/provider_factory.dart`.

Everything else (Settings UI, capture flow, report rendering) works
unchanged.

## Known limitations / next steps

- Video frame extraction is stubbed — see above.
- No authentication/user-accounts layer; this is a local-first app.
- No PDF export wired to a button yet (the `pdf` and `share_plus` packages
  are included in `pubspec.yaml` for you to build that with).
- Consider adding on-device image compression before upload to control
  API costs and latency for large photos.
