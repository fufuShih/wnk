const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    const exe = b.addExecutable(.{
        .name = "wnk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add the state module
    const state_module = b.createModule(.{
        .root_source_file = b.path("src/state/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tray_module = b.createModule(.{
        .root_source_file = b.path("src/tray/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // tray module depends on SDL backend types
    tray_module.addImport("sdl-backend", dvui_dep.module("sdl3"));

    // Add imports to the executable's root module
    exe.root_module.addImport("state", state_module);
    exe.root_module.addImport("tray", tray_module);

    // Third party dependencies
    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    exe.root_module.addImport("sdl-backend", dvui_dep.module("sdl3"));
    // For windows
    exe.linkLibC();

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the executable's
    // root module.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
