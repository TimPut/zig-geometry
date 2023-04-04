const std = @import("std");
const stl = @import("stl.zig");
const mach = @import("mach");
const zm = @import("zmath");
const glfw = @import("glfw");
const gl = @import("zgl");

const log = std.log.scoped(.Engine);

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?*const anyopaque {
    _ = p;
    return glfw.getProcAddress(proc);
}

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(640, 480, "Hello STL!", null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 0,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.loadExtensions(proc, glGetProcAddress);
    glfw.makeContextCurrent(window);

    while (!window.shouldClose()) {
        glfw.pollEvents();
        gl.clearColor(1, 1, 0, 1);
        gl.clear(.{ .color = true, .depth = true, .stencil = false });

        window.swapBuffers();
    }

    // // Wait for the user to close the window.
    // while (!window.shouldClose()) {
    //     glfw.pollEvents();
    // }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.backing_allocator;

    const stdout_handle = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_handle);
    const stdout = bw.writer();

    var timer: std.time.Timer = try std.time.Timer.start();
    var time: u64 = 0;

    var stl_model = try stl.readStl(std.fs.cwd(), allocator, "3DBenchy.stl");

    time = timer.lap();
    try stdout.print("Read speed: {d:.2}GB/s\n", .{(@intToFloat(f32, stl_model.count * @sizeOf(stl.Triangle)) / (@intToFloat(f32, time) / 1_000_000_000)) / (1000 * 1000 * 1000)});
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
