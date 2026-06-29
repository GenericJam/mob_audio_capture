# Changelog

## 0.1.0 (unreleased)

- Initial scaffold. Elixir API (`MobAudioCapture.start/2`, `output_level/0`, `stop/1`),
  plugin manifest, and native skeletons: Android `MediaProjection` +
  `AudioPlaybackCapture` capture (zig NIF + Kotlin bridge), iOS unsupported stub.
  Host-green; native paths not yet device-verified (see `PLAN.md`).
