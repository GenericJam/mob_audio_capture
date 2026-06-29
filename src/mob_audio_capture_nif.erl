%% mob_audio_capture_nif — Erlang NIF module for the device-audio-capture plugin.
%%
%% Android: priv/native/jni/mob_audio_capture_nif.zig bridges to the Kotlin
%% io.mob.audiocapture.MobAudioCaptureBridge (MediaProjection consent →
%% AudioPlaybackCaptureConfiguration → AudioRecord; the capture thread computes RMS/peak
%% and start/stop lifecycle + permission outcome are delivered back to the BEAM).
%% iOS: priv/native/ios/mob_audio_capture_nif.m — there is no public inter-app/system
%% output capture API, so every NIF returns :unsupported_on_platform.
%%
%% Both register this module via the plugin nif_init entry point and are statically
%% linked into the host binary on device. On a host dev build neither is linked, so
%% on_load tolerates the failure and the NIFs fall back to nif_error until the native
%% merge links one.
-module(mob_audio_capture_nif).
-export([
    audio_capture_start/1,
    audio_capture_stop/0,
    audio_capture_level/0
]).
-on_load(init/0).

init() ->
    case erlang:load_nif("mob_audio_capture_nif", 0) of
        ok -> ok;
        {error, _} -> ok
    end.

audio_capture_start(_ConfigJson) ->
    erlang:nif_error(nif_not_loaded).

audio_capture_stop() ->
    erlang:nif_error(nif_not_loaded).

audio_capture_level() ->
    erlang:nif_error(nif_not_loaded).
