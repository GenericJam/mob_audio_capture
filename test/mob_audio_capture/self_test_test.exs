defmodule MobAudioCapture.SelfTestTest do
  use ExUnit.Case, async: true

  alias MobAudioCapture.SelfTest
  alias MobDev.Plugin.{Manifest, Validator}

  @plugin_dir Path.expand("../..", __DIR__)
  @android %{platform: :android, device: :emulator}
  @ios %{platform: :ios, device: :simulator}

  # One stub NIF per native answer; the self-test only calls audio_capture_level/0.
  for {name, answer} <- [
        NotCapturing: :not_capturing,
        NeedsRecordAudio: :needs_record_audio,
        Unsupported: :unsupported_on_platform,
        BridgeNotRegistered: :bridge_not_registered,
        NoActivity: :no_activity,
        JniError: :error,
        Ok: :ok
      ] do
    defmodule Module.concat(__MODULE__, name) do
      @moduledoc false
      def audio_capture_level, do: unquote(answer)
    end
  end

  defmodule Capturing do
    @moduledoc false
    def audio_capture_level, do: {-14.2, -3.1}
  end

  defmodule NotLoaded do
    @moduledoc false
    def audio_capture_level, do: :erlang.nif_error(:nif_not_loaded)
  end

  alias __MODULE__.{
    BridgeNotRegistered,
    JniError,
    NeedsRecordAudio,
    NoActivity,
    NotCapturing,
    Ok,
    Unsupported
  }

  defp run(ctx, stub), do: SelfTest.run(ctx, stub)

  defp assert_contract(result) do
    assert Mob.Plugin.SelfTest.result?(result)
    result
  end

  describe "Android (zig NIF → Kotlin bridge)" do
    test "a registered bridge with an Activity passes, idle or capturing, granted or not" do
      assert assert_contract(run(@android, NotCapturing)) == :pass
      assert assert_contract(run(@android, NeedsRecordAudio)) == :pass
      assert assert_contract(run(%{@android | device: :physical}, Capturing)) == :pass
    end

    test "an unregistered bridge or a missing Activity fails, naming the cause" do
      assert {:fail, reason} = assert_contract(run(@android, BridgeNotRegistered))
      assert reason =~ "audio_capture_level/0 returned :bridge_not_registered"
      assert reason =~ "register()"

      assert {:fail, reason} = assert_contract(run(@android, NoActivity))
      assert reason =~ "audio_capture_level/0 returned :no_activity"
      assert reason =~ "setActivity"
    end

    test "the iOS stub's answer is a failure on Android" do
      assert {:fail, reason} = assert_contract(run(@android, Unsupported))
      assert reason =~ ":unsupported_on_platform on Android"
    end

    test "any other answer fails with what came back and what was expected" do
      assert {:fail, reason} = assert_contract(run(@android, JniError))
      assert reason =~ "audio_capture_level/0 returned :error, expected :not_capturing"

      assert {:fail, _} = assert_contract(run(@android, Ok))
    end
  end

  describe "iOS (Objective-C stub)" do
    test ":unsupported_on_platform proves the stub is linked and passes" do
      assert assert_contract(run(@ios, Unsupported)) == :pass
      assert assert_contract(run(%{@ios | device: :physical}, Unsupported)) == :pass
    end

    test "Android answers are failures on iOS" do
      for stub <- [NotCapturing, NeedsRecordAudio, Capturing, BridgeNotRegistered] do
        assert {:fail, reason} = assert_contract(run(@ios, stub))
        assert reason =~ "expected :unsupported_on_platform"
      end
    end
  end

  test "a NIF that is not linked fails, naming the NIF, instead of raising" do
    for ctx <- [@android, @ios] do
      assert {:fail, reason} = assert_contract(run(ctx, NotLoaded))
      assert reason =~ "mob_audio_capture_nif is not linked"
      assert reason =~ "nif_not_loaded"
    end
  end

  test "run/1 on the host (stub .erl, no native library) is a failure, not a raise" do
    for ctx <- [@android, @ios] do
      assert {:fail, reason} = assert_contract(SelfTest.run(ctx))
      assert reason =~ "mob_audio_capture_nif is not linked"
    end
  end

  test "the manifest declares it and the validator raises no selftest warning" do
    {:ok, m} = Manifest.load(@plugin_dir)
    assert m.selftest == SelfTest
    assert %{errors: [], warnings: warnings} = Validator.validate_plugin(m, @plugin_dir)
    refute Enum.any?(warnings, &(&1 =~ "selftest"))
  end
end
