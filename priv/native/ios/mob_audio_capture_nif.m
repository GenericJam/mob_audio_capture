// mob_audio_capture_nif (iOS) — unsupported stub.
//
// iOS has no public API to capture another app's or the system's audio output (the
// sandbox forbids it; ReplayKit captures the screen + the app's OWN audio only). So
// device-output capture is Android-only. These NIFs register the same names as the
// Android (zig) build and return :unsupported_on_platform so MobAudioCapture degrades
// cleanly (output_level/0 → {:error, :unsupported_on_platform}) instead of raising
// nif_not_loaded.
#include <erl_nif.h>

static ERL_NIF_TERM nif_audio_capture_start(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    return enif_make_atom(env, "unsupported_on_platform");
}

static ERL_NIF_TERM nif_audio_capture_stop(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    return enif_make_atom(env, "unsupported_on_platform");
}

static ERL_NIF_TERM nif_audio_capture_level(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    return enif_make_atom(env, "unsupported_on_platform");
}

static ErlNifFunc nif_funcs[] = {
    {"audio_capture_start", 1, nif_audio_capture_start, 0},
    {"audio_capture_stop", 0, nif_audio_capture_stop, 0},
    {"audio_capture_level", 0, nif_audio_capture_level, 0},
};

ERL_NIF_INIT(mob_audio_capture_nif, nif_funcs, NULL, NULL, NULL, NULL)
