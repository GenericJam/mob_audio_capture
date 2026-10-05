# Changelog

## 0.1.2 - 2026-10-05

### Fixed
- **One pending consent at a time; stale consent results are dropped** (MOB-396).
  `start/2` while another request is still waiting on its MediaProjection
  consent no longer opens a second dialog: the caller gets
  `{:audio_capture, :start_error, :busy}`. Each request keeps its own caller
  and usages, so the permission outcome goes to the process that asked.
  `stop/1` cancels a pending request: granting consent afterwards starts
  nothing, sends nothing and never acquires a MediaProjection. Before, a
  late consent could start capture after `stop/1` or report to the wrong
  caller. Once `stop/1` returns, no outcome message for the request it
  cancelled can still arrive.
- **Consent survives activity recreation** (MOB-396). If the host activity
  is recreated while the consent dialog is up, the bridge registers its
  result callback again on the new activity. Before, the result was lost.
  Registry keys now carry a per-process nonce, so a result parked by a dead
  process can't be delivered to a new request.
- **Android lint clean** (MOB-396). The API 29 capture path is
  `@RequiresApi`-gated (`NewApi`), and `AudioRecord` is built only after an
  explicit `RECORD_AUDIO` check (`MissingPermission`), so a host's
  `:app:lintRelease` no longer fails on the bridge.

### Changed
- The Android bridge's `audio_capture_start` now returns an `int` result code
  (JNI signature `(JLjava/lang/String;)I`). The pre-dialog `:denied` outcomes
  (API < 29, no `RECORD_AUDIO`, no activity) are now sent by `start/2` itself
  instead of from the NIF thread; the message is unchanged.

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
