const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_cimgui = b.dependency("cimgui", .{});
    const dep_imgui = b.dependency("imgui", .{});

    const dep_cimguizmo = b.dependency("cimguizmo", .{});
    const dep_imguizmo = b.dependency("imguizmo", .{});
    const writeFile = b.addNamedWriteFiles("cimguizmo");
    _ = writeFile.addCopyDirectory(dep_cimguizmo.path(""), "", .{});
    _ = writeFile.addCopyDirectory(dep_imguizmo.path(""), "ImGuizmo", .{});
    const root = writeFile.getDirectory();
    // build cimguizmo as C/C++ library
    const lib = b.addStaticLibrary(.{
        .name = "cimguizmo_clib",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.linkLibCpp();
    lib.addCSourceFiles(.{
        .root = root,
        .files = &.{
            b.pathJoin(&.{"cimguizmo.cpp"}),
            b.pathJoin(&.{ "ImGuizmo", "ImGuizmo.cpp" }),
        },
    });
    lib.addIncludePath(dep_cimgui.path(""));
    lib.addIncludePath(dep_imgui.path(""));
    lib.addIncludePath(root);
    b.installArtifact(lib);
    lib.step.dependOn(&writeFile.step);
    const headerFile = dep_cimguizmo.path("cimguizmo.h");
    const translateC = b.addTranslateC(.{
        .root_source_file = headerFile,
        .target = b.host,
        .optimize = optimize,
    });
    translateC.addIncludeDir(dep_cimgui.path("").getPath(b));
    translateC.defineCMacroRaw("CIMGUI_DEFINE_ENUMS_AND_STRUCTS=\"\"");
    // build cimguizmo as a module with the header file as the entrypoint
    const mod = b.addModule("cimguizmo", .{
        .root_source_file = translateC.getOutput(),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    mod.linkLibrary(lib);
}
