const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const ResolvedTarget = std.Build.ResolvedTarget;
const fs = std.fs;
const zcc = @import("build/compile_commands.zig");

pub fn main() void {
    std.build.run(build);
}

pub fn build(b: *Build) void {
    const model = Target.Cpu.Model{ .name = "cortex_m4", .llvm_name = "cortex_m4", .features = Target.Cpu.Feature.Set.empty };
    const target_arch = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &model },
        .os_tag = .freestanding,
        .abi = .eabihf,
        .ofmt = .elf,
    } });

    const CFilesList = std.ArrayList([]const u8);

    var src_dir = fs.cwd().openDir("src/", .{ .iterate = true }) catch unreachable;
    var c_files: CFilesList = CFilesList.init(b.allocator);
    defer c_files.deinit();

    var iter = src_dir.iterate();
    while (iter.next() catch unreachable) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".c") and !std.mem.startsWith(u8, entry.name, "main")) {
            const c_file_path = std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name}) catch unreachable;
            c_files.append(c_file_path) catch unreachable;
        }
    }
    src_dir.close();

    // startup
    var src_dir2 = fs.cwd().openDir("startup/src/", .{ .iterate = true }) catch unreachable;

    var iter2 = src_dir2.iterate();
    while (iter2.next() catch unreachable) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const c_file_path = std.fmt.allocPrint(b.allocator, "startup/src/{s}", .{entry.name}) catch unreachable;
            c_files.append(c_file_path) catch unreachable;
        }
    }
    src_dir2.close();

    // freertos source files
    var src_dir3 = fs.cwd().openDir("freertos", .{ .iterate = true }) catch unreachable;

    var iter3 = src_dir3.iterate();
    while (iter3.next() catch unreachable) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const c_file_path = std.fmt.allocPrint(b.allocator, "freertos/{s}", .{entry.name}) catch unreachable;
            c_files.append(c_file_path) catch unreachable;
        }
    }
    src_dir3.close();

    var targets = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);

    const install_all = b.step("all", "Build and install all targets");

    const mode = b.standardOptimizeOption(.{});

    addExecutable(b, target_arch, &targets, mode, install_all, "stack", "src/main.c", c_files.items);

    const targets_clone = targets.clone() catch unreachable;

    const cdb_step = zcc.createStep(b, "cdb", targets.toOwnedSlice() catch unreachable);
    for (targets_clone.items) |target| {
        target.step.dependOn(cdb_step);
    }
    b.default_step.dependOn(cdb_step);
}

fn addExecutable(
    b: *Build,
    target: ResolvedTarget,
    targets: *std.ArrayList(*std.Build.Step.Compile),
    mode: std.builtin.OptimizeMode,
    install_all: *Build.Step,
    name: []const u8,
    src_path: []const u8,
    c_files: []const []const u8,
) void {
    const exe = b.addExecutable(.{
        .name = name,
        .optimize = mode,
        .target = target,
    });
    // exe.linkLibCpp();
    exe.linkLibC();

    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/crt0.o" } });
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/libg_nano.a" } });
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/libnosys.a" } });
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/libm.a" } });

    exe.setLinkerScript(.{ .src_path = .{ .owner = b, .sub_path = "startup/linkerscript.ld" } });
    exe.addAssemblyFile(.{ .src_path = .{ .owner = b, .sub_path = "startup/src/startup_stm32l476xx.S" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "cmsis/CMSIS/Core/Include" } });

    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "freertos/include" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "freertos/portable/GCC/ARM_CM4F" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "include/" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "startup/include/" } });

    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "./freertos/portable/MemMang/heap_4.c" } }, .flags = &[_][]const u8{ "-Wall", "-Wextra" } });
    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "freertos/portable/GCC/ARM_CM4F/port.c" } }, .flags = &[_][]const u8{ "-Wall", "-Wextra" } });

    exe.addCSourceFile(.{
        .file = .{ .src_path = .{ .owner = b, .sub_path = src_path } },
        .flags = &.{
            "-Wall",
            "-Wextra",
            // "-std=c++23",
        },
    });

    exe.addCSourceFiles(.{
        .files = c_files,
        .flags = &.{
            "-Wall",
            "-Wextra",
            // "-std=c++23",
        },
    });

    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "include/" } });

    targets.append(exe) catch @panic("OOM");
    const run_artifact = b.addRunArtifact(exe);
    const install_artifact = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .{ .custom = "../target" } } });
    install_all.dependOn(&install_artifact.step);

    var run_step_name_buffer: [64]u8 = undefined;
    const run_step_name = std.fmt.bufPrint(&run_step_name_buffer, "run-{s}", .{name}) catch @panic("OOM");
    var run_step_description_buffer: [64]u8 = undefined;
    const run_description = std.fmt.bufPrint(&run_step_description_buffer, "Build and run the {s} program", .{run_step_name}) catch @panic("OOM");
    const run_step = b.step(run_step_name, run_description);

    var build_step_name_buffer: [64]u8 = undefined;
    const build_step_name = std.fmt.bufPrint(&build_step_name_buffer, "{s}", .{name}) catch @panic("OOM");
    var build_step_description_buffer: [64]u8 = undefined;
    const build_description = std.fmt.bufPrint(&build_step_description_buffer, "Build the {s} program", .{build_step_name}) catch @panic("OOM");
    const build_step = b.step(build_step_name, build_description);

    build_step.dependOn(&install_artifact.step);
    run_step.dependOn(&install_artifact.step);
    run_step.dependOn(&run_artifact.step);
}
