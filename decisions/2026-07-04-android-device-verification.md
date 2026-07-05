# Android device verification — mob_audio_capture

- Date: 2026-07-04
- Status: accepted

## Context

`mob_audio_capture` shipped host-green but native-unverified (PLAN.md TODO #1 — the
gate, since a NIF/native-table mismatch is a silent boot crash). It is Android-only:
iOS has no public inter-app / system output-capture API, so the NIF is an
`:unsupported_on_platform` stub.

## What was verified

On a physical moto g power (2021), Android 11 / API 30, from a throwaway
`mix mob.new --blank --android` host app with `:mob_audio_capture` activated
(acknowledged unsigned) and the `AudioCaptureService` `<service>` added to the host
manifest. Driven over Erlang distribution (`:rpc`) from the Mac via a small device-side
probe GenServer — the plugin delivers its permission event to the *calling* process, so
a transient RPC process drops it; a persistent named process captures it.

- **NIF loads:** `output_level/0` returns `{:error, :not_capturing}` pre-start — the zig
  NIF + Kotlin bridge linked and respond (no native-table mismatch → no boot crash).
- **Consent:** `start/1` raised the MediaProjection dialog; accepting delivered
  `{:audio_capture, :permission, :granted}`.
- **Silence (negative control):** `output_level/0` → `:silent` (6/6 samples), nothing
  playing.
- **Live signal:** with a song playing in another app, `output_level/0` → `{rms, peak}`
  across 30 samples, rms ≈ −11.5…−17.7 dBFS, peak ≈ −1.7…−8.0 dBFS, fluctuating with the
  audio; back to `:silent` (5/5) on pause.
- **Teardown:** `stop/1` → `{:error, :not_capturing}`.

## Consequences

- PLAN.md TODO #1 is met; README / CHANGELOG updated to device-verified. The plugin is a
  real candidate to move off "host-green, not device-verified."
- Confirmed the plugin's `android.permissions` (RECORD_AUDIO + the two foreground-service
  perms) merge into the host manifest automatically (`mob_dev`
  `native_build.merge_android_permissions`, deduped). The only host manifest step is the
  `<service>` — already documented in README and `:host_requirements`.
- Added `MobAudioCapture.DemoScreen` (Start + a live meter), registered in the manifest's
  `:screens`, for manual spot-checks — sibling-plugin parity.
- Not covered: the consent `:denied` path, the FGS notification appearance (not separately
  eyeballed — the service started, so capture ran), and PCM streaming mode (PLAN #3).
  Release plumbing (signing key, CI, hooks — PLAN #4) remains.
