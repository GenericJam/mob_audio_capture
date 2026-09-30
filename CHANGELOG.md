# Changelog

## 0.1.1 - 2026-09-30

### Changed
- **Re-signed with plugin envelope v2** (MOB-287). mob_dev 0.7.2+ verifies
  this signature before evaluating the manifest. mob_dev 0.7.0 / 0.7.1 can't
  read v2 signatures and report this release as `invalid signature` —
  upgrade the host app to `{:mob_dev, "~> 0.7.2", only: :dev, runtime: false}`.
  No plugin code changes.

## 0.1.0 - 2026-07-05

- **Android device-verified** on a moto g power (2021), Android 11 / API 30: the full
  `start/1` → consent → `output_level/0` (silent / live `{rms, peak}`) → `stop/1`
  lifecycle over dist RPC. See `decisions/2026-07-04-android-device-verification.md`.
- Add `MobAudioCapture.DemoScreen` (Start + a live meter) and register it in the
  plugin manifest's `:screens`, matching sibling plugins.
- Initial scaffold. Elixir API (`MobAudioCapture.start/2`, `output_level/0`, `stop/1`),
  plugin manifest, and native skeletons: Android `MediaProjection` +
  `AudioPlaybackCapture` capture (zig NIF + Kotlin bridge), iOS unsupported stub.
