//! mob_audio_capture_nif — Android device-audio-capture plugin NIF (zig).
//!
//! Mirrors the mob_screencast plugin NIF. The Kotlin side is the plugin-owned bridge
//! `io.mob.audiocapture.MobAudioCaptureBridge`: a MediaProjection consent dialog →
//! AudioPlaybackCaptureConfiguration → AudioRecord, with a capture thread computing
//! RMS/peak of the output mix. Three NIFs call static bridge methods:
//!   audio_capture_start(pid, json)  consent + start capture (async; permission outcome
//!                                   comes back via nativeDeliverPermission)
//!   audio_capture_stop()            tear down
//!   audio_capture_level() -> [F     latest {rms_db, peak_db}, or a length-1 error code
//!
//! Build path: compiled via `addZigObject` from `-Dplugin_zig_nifs`, reaching mob-core
//! ERTS / JNI bindings through `@import("erts")` / `@import("jni")`. `get_jenv` + `g_jvm`
//! are mob-core exports linked into the same `.so`.
const std = @import("std");
const erts = @import("erts");
const jni = @import("jni");

// mob-core exports (linked into the same .so). NOT duplicated.
extern fn get_jenv(attached: *c_int) ?*jni.JNIEnv;
extern var g_jvm: ?*jni.JavaVM;

// ── Plugin-owned bridge-class method-id cache ────────────────────────────
const AcMethods = struct {
    start: jni.JMethodID = null,
    stop: jni.JMethodID = null,
    level: jni.JMethodID = null,
};

var g_ac: AcMethods = .{};
var g_ac_cls: jni.JClass = null;

// ── nativeRegister thunk — cache the bridge jclass + method ids ───────────
export fn Java_io_mob_audiocapture_MobAudioCaptureBridge_nativeRegister(jenv: *jni.JNIEnv, cls: jni.JClass) callconv(.c) void {
    g_ac_cls = jni.newGlobalRef(jenv, cls);
    if (g_ac_cls == null) return;
    g_ac.start = jni.getStaticMethodID(jenv, cls, "audio_capture_start", "(JLjava/lang/String;)V");
    g_ac.stop = jni.getStaticMethodID(jenv, cls, "audio_capture_stop", "()V");
    g_ac.level = jni.getStaticMethodID(jenv, cls, "audio_capture_level", "()[F");
}

inline fn detachIfAttached(attached: c_int) void {
    if (attached != 0) {
        if (g_jvm) |jvm| jni.detachCurrentThread(jvm);
    }
}

inline fn pidToJlong(pid: erts.ErlNifPid) jni.JLong {
    if (@sizeOf(erts.ERL_NIF_TERM) == @sizeOf(jni.JLong)) return @bitCast(pid.pid);
    return @intCast(pid.pid);
}

inline fn pidFromLong(jpid: jni.JLong) erts.ErlNifPid {
    if (@sizeOf(erts.ERL_NIF_TERM) == @sizeOf(jni.JLong)) return .{ .pid = @bitCast(jpid) };
    const low: u32 = @truncate(@as(u64, @bitCast(jpid)));
    return .{ .pid = low };
}

// ── nativeDeliverPermission thunk — {:audio_capture, :permission, granted|denied} ──
export fn Java_io_mob_audiocapture_MobAudioCaptureBridge_nativeDeliverPermission(
    jenv: *jni.JNIEnv,
    cls: jni.JClass,
    jpid: jni.JLong,
    granted: jni.JBoolean,
) callconv(.c) void {
    _ = jenv;
    _ = cls;
    var pid = pidFromLong(jpid);
    const env = erts.enif_alloc_env();
    const outcome = if (granted != 0) erts.atom(env, "granted") else erts.atom(env, "denied");
    const msg = erts.makeTuple(env, .{
        erts.atom(env, "audio_capture"),
        erts.atom(env, "permission"),
        outcome,
    });
    _ = erts.enif_send(null, &pid, env, msg);
    erts.enif_free_env(env);
}

// ── NIFs ──────────────────────────────────────────────────────────────────
fn binArgZ(env: ?*erts.ErlNifEnv, term: erts.ERL_NIF_TERM, buf: []u8) bool {
    var bin: erts.ErlNifBinary = undefined;
    if (erts.enif_inspect_binary(env, term, &bin) == 0 and
        erts.enif_inspect_iolist_as_binary(env, term, &bin) == 0) return false;
    const n = @min(bin.size, buf.len - 1);
    @memcpy(buf[0..n], bin.data[0..n]);
    buf[n] = 0;
    return true;
}

fn nif_audio_capture_start(env: ?*erts.ErlNifEnv, argc: c_int, argv: [*]const erts.ERL_NIF_TERM) callconv(.c) erts.ERL_NIF_TERM {
    _ = argc;
    if (g_ac.start == null) return erts.atom(env, "unsupported_on_platform");
    var jbuf: [1024]u8 = undefined;
    if (!binArgZ(env, argv[0], &jbuf)) return erts.badarg(env);
    var pid: erts.ErlNifPid = undefined;
    _ = erts.enif_self(env, &pid);
    var attached: c_int = 0;
    const jenv = get_jenv(&attached) orelse return erts.atom(env, "error");
    const jstr = jni.newStringUTF(jenv, @ptrCast(&jbuf));
    jenv.*.CallStaticVoidMethod.?(jenv, g_ac_cls, g_ac.start, pidToJlong(pid), jstr);
    jni.deleteLocalRef(jenv, jstr);
    detachIfAttached(attached);
    return erts.atom(env, "ok");
}

fn nif_audio_capture_stop(env: ?*erts.ErlNifEnv, argc: c_int, argv: [*]const erts.ERL_NIF_TERM) callconv(.c) erts.ERL_NIF_TERM {
    _ = argc;
    _ = argv;
    if (g_ac.stop == null) return erts.atom(env, "unsupported_on_platform");
    var attached: c_int = 0;
    const jenv = get_jenv(&attached) orelse return erts.atom(env, "error");
    jenv.*.CallStaticVoidMethod.?(jenv, g_ac_cls, g_ac.stop);
    detachIfAttached(attached);
    return erts.atom(env, "ok");
}

// audio_capture_level() -> {RmsDb, PeakDb} | error atom. Bridge returns float[2] =
// [rms_db, peak_db] on success, or float[1] = [code] (2 needs_record_audio,
// 4 not_capturing) which we map to an atom Mob.AudioCapture.decode_level/1 turns into
// {:error, _}.
fn nif_audio_capture_level(env: ?*erts.ErlNifEnv, argc: c_int, argv: [*]const erts.ERL_NIF_TERM) callconv(.c) erts.ERL_NIF_TERM {
    _ = argc;
    _ = argv;
    if (g_ac.level == null) return erts.atom(env, "unsupported_on_platform");
    var attached: c_int = 0;
    const jenv = get_jenv(&attached) orelse return erts.atom(env, "error");
    const arr = jenv.*.CallStaticObjectMethod.?(jenv, g_ac_cls, g_ac.level);
    if (arr == null) {
        detachIfAttached(attached);
        return erts.atom(env, "error");
    }
    const len = jni.getArrayLength(jenv, arr);
    if (len >= 2) {
        var vals: [2]f32 = @splat(0);
        jni.getFloatArrayRegion(jenv, arr, 0, 2, &vals);
        jni.deleteLocalRef(jenv, arr);
        detachIfAttached(attached);
        return erts.makeTuple(env, .{
            erts.enif_make_double(env, @floatCast(vals[0])),
            erts.enif_make_double(env, @floatCast(vals[1])),
        });
    }
    var code: [1]f32 = @splat(0);
    if (len == 1) jni.getFloatArrayRegion(jenv, arr, 0, 1, &code);
    jni.deleteLocalRef(jenv, arr);
    detachIfAttached(attached);
    return switch (@as(i32, @intFromFloat(code[0]))) {
        2 => erts.atom(env, "needs_record_audio"),
        4 => erts.atom(env, "not_capturing"),
        else => erts.atom(env, "error"),
    };
}

// ── NIF table + init entry point ─────────────────────────────────────────
fn nifLoad(env: ?*erts.ErlNifEnv, priv: *?*anyopaque, info: erts.ERL_NIF_TERM) callconv(.c) c_int {
    _ = env;
    _ = priv;
    _ = info;
    return 0;
}

const nif_funcs = [_]erts.ErlNifFunc{
    .{ .name = "audio_capture_start", .arity = 1, .fptr = nif_audio_capture_start, .flags = 0 },
    .{ .name = "audio_capture_stop", .arity = 0, .fptr = nif_audio_capture_stop, .flags = 0 },
    .{ .name = "audio_capture_level", .arity = 0, .fptr = nif_audio_capture_level, .flags = 0 },
};

var nif_entry: erts.ErlNifEntry = .{
    .major = erts.ERL_NIF_MAJOR_VERSION,
    .minor = erts.ERL_NIF_MINOR_VERSION,
    .name = "mob_audio_capture_nif",
    .num_of_funcs = nif_funcs.len,
    .funcs = &nif_funcs,
    .load = nifLoad,
    .reload = null,
    .upgrade = null,
    .unload = null,
    .vm_variant = erts.ERL_NIF_VM_VARIANT,
    .options = 1,
    .sizeof_ErlNifResourceTypeInit = erts.SIZEOF_ErlNifResourceTypeInit,
    .min_erts = erts.ERL_NIF_MIN_ERTS_VERSION,
};

pub export fn mob_audio_capture_nif_nif_init() callconv(.c) *erts.ErlNifEntry {
    return &nif_entry;
}
