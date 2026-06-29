%{
  name: :mob_audio_capture,
  mob_version: "~> 0.7",
  plugin_spec_version: 1,
  description:
    "Global device-audio capture via Android MediaProjection + AudioPlaybackCapture " <>
      "(API 29+). Meters / streams the output mix — audio from OTHER apps and native " <>
      "players (a game's own AudioTrack) that the in-app Mob.Audio.output_level probe " <>
      "cannot reach. A normal app may not tap the global mix with a session-0 Visualizer, " <>
      "so this uses the privileged-by-consent MediaProjection path instead. Intended as " <>
      "a TEST-ENVIRONMENT dependency, not a shipped capability.",
  nifs: [
    # Android: zig NIF bridging to the Kotlin io.mob.audiocapture.MobAudioCaptureBridge
    # (MediaProjection consent → AudioPlaybackCaptureConfiguration → AudioRecord →
    # RMS/peak metering). This is the real capability.
    %{
      module: :mob_audio_capture_nif,
      native_dir: "priv/native/jni",
      lang: :zig,
      platform: :android
    },
    # iOS: there is NO public inter-app / system audio output capture API (sandbox).
    # The Objective-C NIF registers the same functions and returns
    # :unsupported_on_platform so the Elixir API degrades cleanly instead of raising.
    %{
      module: :mob_audio_capture_nif,
      native_dir: "priv/native/ios",
      lang: :objc,
      platform: :ios
    }
  ],
  android: %{
    bridge_kt: "priv/native/android/MobAudioCaptureBridge.kt",
    bridge_class: "io.mob.audiocapture.MobAudioCaptureBridge",
    # MediaProjection is granted per-session via the system consent dialog (driven by
    # the bridge), NOT a manifest permission. The manifest needs RECORD_AUDIO (AudioRecord
    # under a playback-capture config still requires it) and the foreground-service perms
    # a MediaProjection capture must run under (API 34+ split out the typed one).
    permissions: [
      "android.permission.RECORD_AUDIO",
      "android.permission.FOREGROUND_SERVICE",
      "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"
    ]
  },
  ios: %{
    # No frameworks — iOS cannot capture other apps' / system output; the NIF is a
    # documented :unsupported_on_platform stub.
    frameworks: []
  },
  # Manual host-app steps the build can't automate; printed as a warning on every
  # `mix mob.deploy --native` of the host. Same class of gap as mob_screencast.
  host_requirements: [
    "AndroidManifest.xml must declare the capture service inside <application>: " <>
      ~s(<service android:name="io.mob.audiocapture.AudioCaptureService" ) <>
      ~s(android:exported="false" android:foregroundServiceType="mediaProjection" />) <>
      " — AudioPlaybackCapture via MediaProjection must run in a typed foreground service; " <>
      "without it the app builds + boots fine and throws a SecurityException at first capture.",
    "AudioPlaybackCapture only records apps whose playback allows capture " <>
      "(android:allowAudioPlaybackCapture, default true for apps targeting API 29+ that " <>
      "are not privileged). Audio with usage VOICE_COMMUNICATION and DRM-protected output " <>
      "is never captured by design."
  ]
}
