defmodule MobAudioCaptureTest do
  use ExUnit.Case, async: true

  alias MobAudioCapture

  describe "start_message/1 (what start/2 sends the caller at once)" do
    test "consent pending: nothing now, the outcome arrives from native later" do
      assert MobAudioCapture.start_message(:ok) == nil
    end

    test "another request's consent is pending: :busy, not a permission outcome" do
      assert MobAudioCapture.start_message(:busy) == {:audio_capture, :start_error, :busy}
    end

    test "refused before any dialog: :denied" do
      assert MobAudioCapture.start_message(:denied) == {:audio_capture, :permission, :denied}
    end

    test "iOS stub or a JNI failure: nothing" do
      assert MobAudioCapture.start_message(:unsupported_on_platform) == nil
      assert MobAudioCapture.start_message(:error) == nil
    end
  end

  describe "capture_opts/1" do
    test "defaults to media + game + unknown usages, as strings" do
      assert MobAudioCapture.capture_opts([]) ==
               %{"usages" => ["media", "game", "unknown"]}
    end

    test "honors an explicit usage list" do
      assert MobAudioCapture.capture_opts(usages: [:media]) == %{"usages" => ["media"]}
    end

    test "usages serialize to strings (JSON-safe)" do
      %{"usages" => usages} = MobAudioCapture.capture_opts(usages: [:game, :unknown])
      assert Enum.all?(usages, &is_binary/1)
      assert usages == ["game", "unknown"]
    end
  end

  describe "decode_level/1" do
    test "passes through {rms, peak} when there is signal" do
      assert MobAudioCapture.decode_level({-12.0, -3.4}) == {-12.0, -3.4}
    end

    test "a peak at or below -120 dB reads as :silent" do
      assert MobAudioCapture.decode_level({-160.0, -160.0}) == :silent
      assert MobAudioCapture.decode_level({-130.0, -120.0}) == :silent
    end

    test "an atom result becomes {:error, atom}" do
      assert MobAudioCapture.decode_level(:not_capturing) == {:error, :not_capturing}
      assert MobAudioCapture.decode_level(:needs_record_audio) == {:error, :needs_record_audio}

      assert MobAudioCapture.decode_level(:unsupported_on_platform) ==
               {:error, :unsupported_on_platform}
    end

    test "an unexpected shape becomes {:error, :unknown}" do
      assert MobAudioCapture.decode_level(42) == {:error, :unknown}
    end
  end
end
