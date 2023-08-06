const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libz_dep = b.dependency("libz", .{
        .target = target,
        .optimize = optimize,
    });

    const usockets_dep = b.dependency("usockets", .{
        .target = target,
        .optimize = optimize,
        .ssl = true,
        .uv = true,
    });

    const lib = b.addStaticLibrary(.{
        .name = "uwebsockets",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkLibCpp();
    lib.linkLibrary(libz_dep.artifact("z"));
    lib.linkLibrary(usockets_dep.artifact("usockets"));
    lib.addIncludePath(.{ .path = "vendor/src" });
    lib.addIncludePath(.{ .path = "vendor/capi" });
    lib.defineCMacroRaw("UWS_WITH_PROXY");
    lib.addCSourceFile(.{
        .file = .{ .path = "vendor/capi/libuwebsockets.cpp" },
        .flags = &.{"-DUWS_WITH_PROXY"},
    });
    lib.installHeader("vendor/capi/libuwebsockets.h", "libuwebsockets.h");
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
    tests.linkLibrary(lib);
    tests.linkLibrary(usockets_dep.artifact("usockets"));

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    b.installArtifact(tests);
}
