# mob_audio_capture

Global **device-audio capture** for [Mob](https://github.com/GenericJam/mob) apps —
meter or stream the device's output mix, including audio produced by *other* apps
and by native players (a game's own `AudioTrack`) that bypass `Mob.Audio`.

This is the capability `Mob.Audio.output_level(source: :mix)` deliberately does not
provide. A normal app cannot tap the global output mix with a session-0 `Visualizer`
(privileged — `ERROR_NO_INIT` on Android, device-verified), so this plugin uses the
consent-gated `MediaProjection` + `AudioPlaybackCapture` path (Android API 29+).

Because capture requires a per-session system consent dialog and a typed foreground
service, it is intended as a **test-environment dependency** for agent-driven
verification ("is the bundled game's audio actually producing signal?"), not a
capability you ship in a production app.

## Platform support

| Platform | Support |
|----------|---------|
| Android 10+ (API 29) | Full output-mix capture, subject to each source app's `allowAudioPlaybackCapture` (default-on for non-privileged API 29+ apps; `VOICE_COMMUNICATION` and DRM output never captured). |
| iOS | **Unsupported** — no public inter-app/system output capture API. Every call returns `{:error, :unsupported_on_platform}`. |

## Usage

```elixir
MobAudioCapture.start(socket)
# → handle_info({:audio_capture, :permission, :granted | :denied}, socket)

# once granted, while audio is playing anywhere on the device:
MobAudioCapture.output_level()
# => {-12.0, -3.4}   # {rms_db, peak_db}, or :silent

MobAudioCapture.stop(socket)
```

## Host setup

Add to the host app's `mob.exs` plugin list, and declare the capture service in the
host `AndroidManifest.xml` inside `<application>` (the native build also prints this
as a warning):

```xml
<service
    android:name="io.mob.audiocapture.AudioCaptureService"
    android:exported="false"
    android:foregroundServiceType="mediaProjection" />
```

`RECORD_AUDIO` must be granted at runtime before `start/1` (the manifest declaration
the plugin contributes is necessary but not sufficient — it's a runtime permission).

## Status

Scaffolded 2026-06-29. Elixir API + plugin manifest + native skeletons (Android zig
NIF + Kotlin `AudioPlaybackCapture` bridge + iOS unsupported stub) are in place and
host-green. **Native paths are not yet device-verified** — see `PLAN.md`.
