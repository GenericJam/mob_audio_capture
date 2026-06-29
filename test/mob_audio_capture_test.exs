defmodule MobAudioCaptureTest do
  use ExUnit.Case, async: true

  alias MobAudioCapture

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
