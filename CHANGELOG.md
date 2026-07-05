# Changelog

## 0.1.0 (unreleased)

- **Android device-verified** on a moto g power (2021), Android 11 / API 30: the full
  `start/1` → consent → `output_level/0` (silent / live `{rms, peak}`) → `stop/1`
  lifecycle over dist RPC. See `decisions/2026-07-04-android-device-verification.md`.
- Add `MobAudioCapture.DemoScreen` (Start + a live meter) and register it in the
  plugin manifest's `:screens`, matching sibling plugins.
- Initial scaffold. Elixir API (`MobAudioCapture.start/2`, `output_level/0`, `stop/1`),
  plugin manifest, and native skeletons: Android `MediaProjection` +
  `AudioPlaybackCapture` capture (zig NIF + Kotlin bridge), iOS unsupported stub.
