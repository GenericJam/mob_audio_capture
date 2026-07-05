# mob_audio_capture — plan & status

## Why this exists

Device verification of the core `Mob.Audio` probes (mob#54) on a moto g power (2021),
Android 11, proved a normal app **cannot** tap the global output mix with a session-0
`Visualizer` — it fails `ERROR_NO_INIT` even with `RECORD_AUDIO` +
`MODIFY_AUDIO_SETTINGS`. So `Mob.Audio.output_level(source: :mix)` returns
`:unsupported_on_platform`, and "meter audio that bypasses `Mob.Audio`" (a game's own
`AudioTrack`, another app) moved here, to a consent-gated capture plugin shipped as a
test-environment dependency.

## Done (scaffold, host-green)

- Elixir API: `MobAudioCapture.start/2`, `output_level/0`, `stop/1` + pure
  `capture_opts/1`, `decode_level/1` (unit-tested).
- NIF stub `src/mob_audio_capture_nif.erl` (start/1, stop/0, level/0).
- Plugin manifest `priv/mob_plugin.exs` (Android zig NIF + Kotlin bridge + FGS/RECORD_AUDIO
  perms + iOS unsupported NIF + `host_requirements`).
- Android zig NIF `priv/native/jni/` — bridge method cache, consent/permission deliver
  thunk, length-coded level return. Modeled on the mob_screencast plugin NIF.
- Android Kotlin bridge `priv/native/android/MobAudioCaptureBridge.kt` —
  `MediaProjection` consent → typed foreground `AudioCaptureService` →
  `AudioPlaybackCaptureConfiguration` → `AudioRecord` → capture thread computing
  RMS/peak (dBFS).
- iOS `priv/native/ios/` — `:unsupported_on_platform` stub.

## TODO before a real release

1. **Device-verify on Android 11+** — ✅ **Done 2026-07-04** on a moto g power (2021),
   Android 11 / API 30, driven over dist RPC from a throwaway `--blank --android` host
   app with the plugin activated (see
   `decisions/2026-07-04-android-device-verification.md`):
   - ✅ host app boots with the plugin linked — the NIF loads (`output_level/0` returns
     `{:error, :not_capturing}` pre-start, so no native-table mismatch);
   - ✅ `start/1` raises the consent dialog; granting → `{:audio_capture, :permission,
     :granted}`;
   - ✅ with another app producing audio, `output_level/0` reads a non-silent
     `{rms, peak}` (rms ≈ −12…−18, peak ≈ −2…−8 dBFS), and `:silent` when nothing plays;
   - ✅ capture stops cleanly on `stop/1` (`{:error, :not_capturing}`). The FGS
     notification was not separately eyeballed; the service started (capture ran).
   - Not yet exercised: the `:denied` path.
2. **Verify the host-manifest service contribution.** The plugin manifest can't yet add
   an `AndroidManifest` `<service>` fragment, so `:host_requirements` warns the author.
   Confirm the SecurityException path when the service is missing, and document the
   exact snippet (done in README).
3. **PCM streaming mode (optional).** Beyond level metering, deliver raw PCM frames as
   `{:audio_capture, :frame, %{bytes: pcm, ...}}` (mirror mob_screencast's frame
   delivery) for callers that want the waveform, not just energy.
4. **Release plumbing:** `.github/workflows/release.yml`, `.githooks/pre-push`, the
   shared first-party signing key (`priv/mob_plugin.pub`) + CI signing, CHANGELOG. Copy
   from mob_screencast; not included in the scaffold.
5. **Decide default sample rate / channels.** Currently mono @ 44100 for cheap level
   computation; a streaming mode may want stereo + the device-native rate.

## Non-goals

- iOS capture — no public API; the plugin is Android-only by platform reality.
- Shipping in production apps — the consent dialog + FGS make this a dev/test tool.
- Capturing `VOICE_COMMUNICATION` or DRM-protected output — disallowed by the platform.
