const std = @import("std");
const Builder = std.build.Builder;
const Target = std.Target;
const fs = std.fs;
const zcc = @import("build/compile_commands.zig");

pub fn build(b: *Builder) void {
    const model = Target.Cpu.Model{ .name = "cortex_m4", .llvm_name = "cortex_m4", .features = Target.Cpu.Feature.Set.empty };
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &model },
        .os_tag = .freestanding,
        .abi = .eabihf,
        .ofmt = .elf,
    } });
    const mode = b.standardOptimizeOption(.{});
    var targets = std.ArrayList(*std.Build.CompileStep).init(b.allocator);

    const exe = b.addExecutable(.{
        .name = "tmp",
        .root_source_file = .{ .path = "src/main.c" },
        .target = target,
        .optimize = mode,
        .link_libc = false,
    });

    exe.addObjectFile(std.build.LazyPath.relative("libs/libc/crt0.o"));
    exe.addObjectFile(std.build.LazyPath.relative("libs/libc/libg_nano.a"));
    exe.addObjectFile(std.build.LazyPath.relative("libs/libc/libnosys.a"));
    exe.addObjectFile(std.build.LazyPath.relative("libs/libc/libm.a"));

    const CFilesList = std.ArrayList([]const u8);

    var src_dir = fs.cwd().openIterableDir("src/", .{}) catch unreachable;
    var c_files: CFilesList = CFilesList.init(b.allocator);
    defer c_files.deinit();

    var iter = src_dir.iterate();
    while (iter.next() catch unreachable) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".c") and !std.mem.startsWith(u8, entry.name, "lab")) {
            const c_file_path = std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name}) catch unreachable;
            c_files.append(c_file_path) catch unreachable;
        }
    }
    src_dir.close();

    // startup
    const CFilesList2 = std.ArrayList([]const u8);
    var src_dir2 = fs.cwd().openIterableDir("startup/src/", .{}) catch unreachable;
    var c_files2: CFilesList = CFilesList2.init(b.allocator);
    defer c_files2.deinit();

    var iter2 = src_dir2.iterate();
    while (iter2.next() catch unreachable) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const c_file_path = std.fmt.allocPrint(b.allocator, "startup/src/{s}", .{entry.name}) catch unreachable;
            c_files2.append(c_file_path) catch unreachable;
        }
    }
    src_dir2.close();

    // freertos source files
    const CFilesList3 = std.ArrayList([]const u8);
    var src_dir3 = fs.cwd().openIterableDir("freertos", .{}) catch unreachable;
    var c_files3: CFilesList = CFilesList3.init(b.allocator);
    defer c_files3.deinit();

    var iter3 = src_dir3.iterate();
    while (iter3.next() catch unreachable) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const c_file_path = std.fmt.allocPrint(b.allocator, "freertos/{s}", .{entry.name}) catch unreachable;
            c_files3.append(c_file_path) catch unreachable;
        }
    }
    src_dir3.close();

    exe.addCSourceFile(.{ .file = std.build.LazyPath.relative("./freertos/portable/MemMang/heap_4.c"), .flags = &[_][]const u8{ "-Wall", "-Wextra" } });
    exe.addCSourceFile(.{ .file = std.build.LazyPath.relative("freertos/portable/GCC/ARM_CM4F/port.c"), .flags = &[_][]const u8{ "-Wall", "-Wextra" } });
    exe.addCSourceFiles(c_files.items, &[_][]const u8{
        "-Wall",
        "-Wextra",
    });
    exe.addCSourceFiles(c_files2.items, &[_][]const u8{
        "-Wall",
        "-Wextra",
    });
    exe.addCSourceFiles(c_files3.items, &[_][]const u8{});

    exe.setLinkerScript(std.build.LazyPath.relative("startup/linkerscript.ld"));
    exe.addAssemblyFile(std.build.LazyPath.relative("startup/src/startup_stm32l476xx.S"));
    exe.addIncludePath(std.build.LazyPath.relative("cmsis/CMSIS/Core/Include"));
    exe.addIncludePath(std.build.LazyPath.relative("freertos/include"));
    exe.addIncludePath(std.build.LazyPath.relative("freertos/portable/GCC/ARM_CM4F"));
    exe.addIncludePath(std.build.LazyPath.relative("libs/libc/include"));
    exe.addIncludePath(std.build.LazyPath.relative("include/"));
    exe.addIncludePath(std.build.LazyPath.relative("startup/include/"));
    targets.append(exe) catch @panic("OOM");

    b.installArtifact(exe);

    const cdb_step = zcc.createStep(b, "cdb", targets.toOwnedSlice() catch unreachable);
    exe.step.dependOn(cdb_step);

    const flash_step = b.addSystemCommand(&[_][]const u8{ "probe-rs", "download", "zig-out/bin/tmp", "--chip", "STM32L476RGTx" });
    flash_step.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Flash and run the app on the board");
    run_step.dependOn(&flash_step.step);
}

pub fn main() void {
    std.build.run(build);
}
