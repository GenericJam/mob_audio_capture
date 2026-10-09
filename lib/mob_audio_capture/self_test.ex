defmodule MobAudioCapture.SelfTest do
  @moduledoc """
  The plugin's on-device proof (`Mob.Plugin.SelfTest`), run by
  `mix mob.selftest` and mob_ci for every activated plugin.

  One native call, no UI, nothing started: `audio_capture_level/0`. It only
  reads the bridge's state, so unlike `audio_capture_stop/0` it cannot cancel
  a capture or a pending consent request the host app owns, and the device is
  left as found.

  ## Android (zig NIF → Kotlin `MobAudioCaptureBridge`)

    * `:not_capturing` passes: the NIF is linked, `nativeRegister` cached the
      bridge class and method IDs, the Kotlin bridge has an Activity, and
      `RECORD_AUDIO` is granted. This is the expected answer on an emulator
      (the runner pre-grants `RECORD_AUDIO` from the manifest) and on an idle
      phone.
    * `:needs_record_audio` passes: the same round trip, on a device where
      `RECORD_AUDIO` is not granted. The permission gates capture, which is a
      feature (and needs the MediaProjection consent dialog anyway), not the
      proof that the plugin initialised.
    * `{rms_db, peak_db}` passes: the host app is capturing right now.
    * `:bridge_not_registered` (the bootstrap never called
      `MobAudioCaptureBridge.register()`, or the method-ID lookup failed) and
      `:no_activity` (the bridge holds no live Activity: the bootstrap never
      called `MobActivityAware.setActivity`, or the Activity was destroyed) fail:
      capture cannot start in that state, and the self-test runs with the app in
      the foreground, so a live Activity is expected.
    * `:unsupported_on_platform` fails on Android: that is the iOS stub's
      answer (and what the Android NIF of 0.1.2 and earlier gave for an
      unregistered bridge).

  The `AudioCaptureService` the host must declare in its `AndroidManifest.xml`
  (a host requirement, warned about at build time) is only started once
  consent is granted; `audio_capture_level/0` never touches it, so a missing
  declaration does not change this result. Proving it is there needs the
  consent dialog, i.e. a person.

  ## iOS (Objective-C stub)

  iOS has no public API to capture other apps' or the system's audio output,
  so the plugin ships an Objective-C NIF whose every function answers
  `:unsupported_on_platform`. That answer passes: it proves the stub is
  linked and registered, so `MobAudioCapture` degrades to
  `{:error, :unsupported_on_platform}` instead of raising. Same on a
  simulator and a phone.

  ## Both

  The host stub's `nif_not_loaded` (no native library linked) is a failure,
  as is any other answer.
  """
  @behaviour Mob.Plugin.SelfTest

  @impl true
  def run(ctx), do: run(ctx, :mob_audio_capture_nif)

  @doc false
  # `nif` is the NIF module; tests pass a stub.
  @spec run(Mob.Plugin.SelfTest.ctx(), module()) :: Mob.Plugin.SelfTest.result()
  def run(%{platform: platform}, nif) do
    classify(platform, nif.audio_capture_level())
  rescue
    e in ErlangError ->
      {:fail,
       "mob_audio_capture_nif is not linked into this build: " <>
         "audio_capture_level/0 raised #{Exception.message(e)}"}
  end

  defp classify(:ios, :unsupported_on_platform), do: :pass

  defp classify(:android, answer) when answer in [:not_capturing, :needs_record_audio],
    do: :pass

  defp classify(:android, {rms, peak}) when is_float(rms) and is_float(peak), do: :pass

  defp classify(:android, :bridge_not_registered) do
    {:fail,
     "audio_capture_level/0 returned :bridge_not_registered: the Kotlin " <>
       "MobAudioCaptureBridge never registered (register() was not called or a " <>
       "method-ID lookup failed), expected :not_capturing"}
  end

  defp classify(:android, :no_activity) do
    {:fail,
     "audio_capture_level/0 returned :no_activity: MobAudioCaptureBridge holds no live " <>
       "Activity (MobActivityAware.setActivity never ran, or the Activity was destroyed) " <>
       "with the app in the foreground, expected :not_capturing"}
  end

  defp classify(:android, :unsupported_on_platform) do
    {:fail,
     "audio_capture_level/0 returned :unsupported_on_platform on Android: the iOS " <>
       "stub's answer, or a 0.1.2-or-earlier Android NIF with no registered bridge; " <>
       "expected :not_capturing"}
  end

  defp classify(:android, other) do
    {:fail,
     "audio_capture_level/0 returned #{inspect(other)}, expected :not_capturing, " <>
       ":needs_record_audio or {rms_db, peak_db}"}
  end

  defp classify(:ios, other) do
    {:fail,
     "audio_capture_level/0 returned #{inspect(other)}, expected :unsupported_on_platform " <>
       "from the iOS stub"}
  end
end
