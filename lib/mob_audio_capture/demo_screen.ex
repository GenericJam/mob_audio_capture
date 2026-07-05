defmodule MobAudioCapture.DemoScreen do
  @moduledoc """
  A ready-to-run sample screen exercising `MobAudioCapture`, shipped so a generated
  app can kick the tires the moment the plugin is activated. Declared in the plugin
  manifest's `:screens`. Delete it (and the manifest entry) in a real app.

  Tap **Start** and accept the system capture-consent dialog; the meter then shows
  the device output mix's live level (`rms` / `peak` dBFS) while any app plays audio,
  and `silent` when nothing does. Android only — on iOS every call reports
  `unsupported`.
  """
  use Mob.Screen

  # output_level/0 is a pull, not a push, so poll it on a self-tick while capturing.
  @tick_ms 300

  @impl true
  def mount(_params, _session, socket) do
    {:ok, Mob.Socket.assign(socket, capturing: false, permission: nil, level: nil)}
  end

  @impl true
  def render(assigns) do
    ~MOB"""
    <Column background={:background} padding={:space_lg} fill_width={true} fill_height={true}>
      <Text text="Audio Capture" text_size={:lg} text_color={:on_surface} padding={:space_sm} />
      <Text text={status_text(assigns)} text_size={:sm} text_color={:primary} padding={4} />
      <Spacer size={8} />
      <Text text={level_text(assigns)} text_size={:md} text_color={:on_surface} padding={4} />
      <Spacer size={16} />
      <Button text={if(assigns.capturing, do: "Stop", else: "Start")} background={:primary} text_color={:on_primary} padding={:space_md} fill_width={true} on_tap={{self(), :toggle}} />
    </Column>
    """
  end

  defp status_text(%{capturing: true, permission: :granted}),
    do: "Capturing — play audio anywhere"

  defp status_text(%{capturing: true}), do: "Waiting for capture consent…"
  defp status_text(%{permission: :denied}), do: "Consent denied — tap Start to retry"
  defp status_text(_), do: "Tap Start, then accept the consent dialog"

  defp level_text(%{level: nil}), do: "—"
  defp level_text(%{level: :silent}), do: "silent"
  defp level_text(%{level: {:error, reason}}), do: "error: #{reason}"

  defp level_text(%{level: {rms, peak}}),
    do: "rms #{Float.round(rms, 1)} dBFS   peak #{Float.round(peak, 1)} dBFS"

  @impl true
  def handle_info({:tap, :toggle}, %{assigns: %{capturing: true}} = socket) do
    {:noreply, MobAudioCapture.stop(socket) |> Mob.Socket.assign(capturing: false, level: nil)}
  end

  def handle_info({:tap, :toggle}, socket) do
    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, MobAudioCapture.start(socket) |> Mob.Socket.assign(capturing: true)}
  end

  def handle_info(:tick, %{assigns: %{capturing: true, permission: :granted}} = socket) do
    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, Mob.Socket.assign(socket, :level, MobAudioCapture.output_level())}
  end

  def handle_info(:tick, %{assigns: %{capturing: true}} = socket) do
    # Consent not resolved yet — keep the tick alive but don't read a level.
    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, socket}
  end

  def handle_info(:tick, socket), do: {:noreply, socket}

  def handle_info({:audio_capture, :permission, result}, socket) do
    {:noreply, Mob.Socket.assign(socket, :permission, result)}
  end
end
