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
    const executables = [_][]const u8{"lab1"};

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
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const should_include = !isExecutableSource(entry.name, &executables);
            if (should_include) {
                const c_file_path = std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name}) catch unreachable;
                c_files.append(c_file_path) catch unreachable;
            }
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
    // var src_dir3 = fs.cwd().openDir("freertos", .{ .iterate = true }) catch unreachable;

    // var iter3 = src_dir3.iterate();
    // while (iter3.next() catch unreachable) |entry| {
    //     if (std.mem.endsWith(u8, entry.name, ".c")) {
    //         const c_file_path = std.fmt.allocPrint(b.allocator, "freertos/{s}", .{entry.name}) catch unreachable;
    //         c_files.append(c_file_path) catch unreachable;
    //     }
    // }
    // src_dir3.close();

    var targets = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);

    const install_all = b.step("all", "Build and install all targets");

    const mode = b.standardOptimizeOption(.{});

    for (executables) |exe| {
        const src_path = std.fmt.allocPrint(b.allocator, "src/{s}.c", .{exe}) catch unreachable;
        addExecutable(b, target_arch, &targets, mode, install_all, exe, src_path, c_files.items);
    }

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
    // exe.linkLibC();

    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/crt0.o" } });
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/libg_nano.a" } });
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/libnosys.a" } });
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/libm.a" } });

    exe.setLinkerScript(.{ .src_path = .{ .owner = b, .sub_path = "startup/linkerscript.ld" } });
    exe.addAssemblyFile(.{ .src_path = .{ .owner = b, .sub_path = "startup/src/startup_stm32l476xx.S" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "cmsis/CMSIS/Core/Include" } });

    // exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "freertos/include" } });
    // exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "freertos/portable/GCC/ARM_CM4F" } });
    // exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "./freertos/portable/MemMang/heap_4.c" } }, .flags = &[_][]const u8{ "-Wall", "-Wextra" } });
    // exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "freertos/portable/GCC/ARM_CM4F/port.c" } }, .flags = &[_][]const u8{ "-Wall", "-Wextra" } });

    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "libs/libc/include" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "include/" } });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "startup/include/" } });

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
    var flash_art_name_buffer: [64]u8 = undefined;
    const flash_art_name = std.fmt.bufPrint(&flash_art_name_buffer, "target/{s}", .{name}) catch @panic("OOM");
    const flash_artifact = b.addSystemCommand(&[_][]const u8{ "probe-rs", "download", flash_art_name, "--chip", "STM32L476RGTx" });

    const install_artifact = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .{ .custom = "../target" } } });
    install_all.dependOn(&install_artifact.step);

    var flash_step_name_buffer: [64]u8 = undefined;
    const flash_step_name = std.fmt.bufPrint(&flash_step_name_buffer, "flash-{s}", .{name}) catch @panic("OOM");
    var flash_step_description_buffer: [64]u8 = undefined;
    const flash_description = std.fmt.bufPrint(&flash_step_description_buffer, "Build and flash the {s} program", .{flash_step_name}) catch @panic("OOM");
    const flash_step = b.step(flash_step_name, flash_description);

    var build_step_name_buffer: [64]u8 = undefined;
    const build_step_name = std.fmt.bufPrint(&build_step_name_buffer, "{s}", .{name}) catch @panic("OOM");
    var build_step_description_buffer: [64]u8 = undefined;
    const build_description = std.fmt.bufPrint(&build_step_description_buffer, "Build the {s} program", .{build_step_name}) catch @panic("OOM");
    const build_step = b.step(build_step_name, build_description);

    build_step.dependOn(&install_artifact.step);
    flash_step.dependOn(&install_artifact.step);
    flash_step.dependOn(&flash_artifact.step);
}

fn isExecutableSource(filename: []const u8, executables: []const []const u8) bool {
    for (executables) |exe| {
        const exe_filename = std.fmt.allocPrint(std.heap.page_allocator, "{s}.c", .{exe}) catch unreachable;
        defer std.heap.page_allocator.free(exe_filename);
        if (std.mem.eql(u8, filename, exe_filename)) {
            return true;
        }
    }
    return false;
}
