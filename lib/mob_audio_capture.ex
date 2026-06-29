defmodule MobAudioCapture do
  @moduledoc """
  Capture the **device's whole output mix** from inside a Mob app — including audio
  produced by *other* apps and by native players (a game's own `AudioTrack`) that
  bypass `Mob.Audio`.

  This is the capability `Mob.Audio.output_level(source: :mix)` deliberately does
  *not* provide. A normal app cannot tap the global output mix with a session-0
  `Visualizer` (privileged: `ERROR_NO_INIT`), so this plugin uses the
  consent-gated `MediaProjection` + `AudioPlaybackCapture` path (Android API 29+)
  instead. Because capture requires a per-session system consent dialog and a typed
  foreground service, it is intended as a **test-environment dependency** for
  agent-driven verification, not a capability you ship in a production app.

  ## Platform support

    * **Android 10+ (API 29):** full capture of the output mix, subject to each
      source app's `allowAudioPlaybackCapture` (default-on for non-privileged apps
      targeting API 29+; `VOICE_COMMUNICATION` usage and DRM output are never
      captured by design).
    * **iOS:** unsupported — there is no public inter-app/system output capture API.
      Every call returns `{:error, :unsupported_on_platform}`.

  ## Usage

      MobAudioCapture.start(socket)
      # → handle_info({:audio_capture, :permission, :granted | :denied}, socket)

      # once granted, while audio is playing anywhere on the device:
      MobAudioCapture.output_level()
      # => {-12.0, -3.4}   # {rms_db, peak_db}, or :silent

      MobAudioCapture.stop(socket)

  Capture must be active for `output_level/0` to read; otherwise it returns
  `{:error, :not_capturing}`.
  """
  @nif :mob_audio_capture_nif

  @type level_error :: :unsupported_on_platform | :needs_record_audio | :not_capturing | :unknown

  @default_usages [:media, :game, :unknown]

  @doc """
  Begin capturing the device output mix. Triggers the `MediaProjection` consent
  dialog; the outcome arrives as `{:audio_capture, :permission, :granted | :denied}`
  to the calling process. Once granted, capture runs in a foreground service until
  `stop/1`.

  Options:
    * `:usages` — which audio usages to capture, any of `:media`, `:game`,
      `:unknown` (default `#{inspect(@default_usages)}`). These are the only usages
      `AudioPlaybackCapture` is permitted to record.
  """
  @spec start(Mob.Socket.t(), keyword()) :: Mob.Socket.t()
  def start(socket, opts \\ []) do
    @nif.audio_capture_start(:json.encode(capture_opts(opts)))
    socket
  end

  @doc """
  Build the config map passed to `audio_capture_start/1`. Pure function exposed so
  tests can pin defaults + serialisation without the NIF.
  """
  @spec capture_opts(keyword()) :: map()
  def capture_opts(opts) do
    usages =
      opts
      |> Keyword.get(:usages, @default_usages)
      |> Enum.map(&to_string/1)

    %{"usages" => usages}
  end

  @doc """
  Read the current captured-mix level as `{rms_db, peak_db}` (dBFS), `:silent` when
  there is no measurable signal, or `{:error, reason}`.

  `reason` is `:not_capturing` (no active session — call `start/1` first),
  `:needs_record_audio` (Android permission not granted at runtime), or
  `:unsupported_on_platform` (iOS).
  """
  @spec output_level() :: {float(), float()} | :silent | {:error, level_error()}
  def output_level do
    decode_level(@nif.audio_capture_level())
  end

  @doc "Stop the active capture session and tear down the foreground service."
  @spec stop(Mob.Socket.t()) :: Mob.Socket.t()
  def stop(socket) do
    @nif.audio_capture_stop()
    socket
  end

  @doc false
  @spec decode_level(term()) :: {float(), float()} | :silent | {:error, level_error()}
  def decode_level({_rms, peak}) when peak <= -120.0, do: :silent
  def decode_level({rms, peak}), do: {rms, peak}
  def decode_level(reason) when is_atom(reason), do: {:error, reason}
  def decode_level(_), do: {:error, :unknown}
end
