const print = @import("std").debug.print;
const std = @import("std");
const stl = @import("stl.zig");
const Triangle = @import("stl.zig").Triangle;
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zlm");
const log = std.log.scoped(.Engine);

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?*const anyopaque {
    _ = p;
    return glfw.getProcAddress(proc);
}

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn setupGlfwContext(allocator: std.mem.Allocator, verts: []f32) !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    var fullscreen = false;
    var primaryMonitor = glfw.Monitor.getPrimary();

    // Create our window
    const window = glfw.Window.create(1920, 1080, "Hello STL!", if (fullscreen) primaryMonitor else null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 5,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    // defer window.destroy();

    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.loadExtensions(proc, glGetProcAddress);
    glfw.makeContextCurrent(window);

    // Use classic OpenGL flavour
    var vao = gl.VertexArray.create();
    defer vao.delete();

    // Use classic OpenGL flavour
    var vbo = gl.Buffer.create();
    defer vbo.delete();

    // Bind the VAO and VBO
    gl.bindVertexArray(vao);
    gl.bindBuffer(vbo, gl.BufferTarget.array_buffer);

    // Upload the vertex data to the VBO
    gl.bufferData(gl.BufferTarget.array_buffer, f32, verts, gl.BufferUsage.static_draw);

    // Set up the vertex attributes
    // Positions
    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 6 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);
    // Colors
    gl.vertexAttribPointer(1, 3, gl.Type.float, false, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    // Unbind the VAO and VBO
    // gl.bindBuffer(null, gl.BufferTarget.array_buffer);
    // gl.bindVertexArray(null);

    // Create the shader program
    const vertexShader = gl.createShader(gl.ShaderType.vertex);
    gl.shaderSource(vertexShader, 1, &vertexShaderSources);
    gl.compileShader(vertexShader);

    const fragmentShader = gl.createShader(gl.ShaderType.fragment);
    gl.shaderSource(fragmentShader, 1, &fragmentShaderSources);
    gl.compileShader(fragmentShader);

    var shaderLog = gl.getShaderInfoLog(vertexShader, allocator);
    var shaderLog2 = gl.getShader(fragmentShader, gl.ShaderParameter.shader_source_length);
    print("{any}", .{shaderLog});
    print("{d}", .{shaderLog2});

    var shaderProgram: gl.Program = undefined;
    shaderProgram = gl.createProgram();
    defer gl.deleteProgram(shaderProgram);
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);
    gl.useProgram(shaderProgram);

    // compiled into the program and no longer needed
    vertexShader.delete();
    fragmentShader.delete();

    gl.cullFace(gl.CullMode.front_and_back);

    var viewLoc = gl.getUniformLocation(shaderProgram, "view");
    var view = math.Mat4.createLookAt(math.Vec3.one.scale(2), math.Vec3.zero, math.Vec3.unitY);

    var projectionLoc = gl.getUniformLocation(shaderProgram, "projection");
    var projection = math.Mat4.createPerspective(30.0 * 3.1416 / 180.0, 1920.0 / 1080.0, 0.1, 100.0);

    // gross casting: https://github.com/ziglang/zig/issues/3156
    const views: []const [4][4]f32 = @ptrCast([*]const [4][4]f32, &view.fields)[0..1];
    const projections: []const [4][4]f32 = @ptrCast([*]const [4][4]f32, &projection.fields)[0..1];

    print("{any}", .{projections});
    print("{any}", .{projectionLoc});
    gl.programUniformMatrix4(shaderProgram, viewLoc, false, views);
    gl.programUniformMatrix4(shaderProgram, projectionLoc, false, projections);

    var state: State = .{
        .rotation_a = 0,
        .rotation_b = 0,
    };
    var modelLoc = gl.getUniformLocation(shaderProgram, "model");

    while (!window.shouldClose()) {
        processInput(window, &state);

        var model = math.Mat4.createAngleAxis(math.Vec3.unitY, state.rotation_a).mul(math.Mat4.createAngleAxis(math.Vec3.unitX, state.rotation_b));
        const models: []const [4][4]f32 = @ptrCast([*]const [4][4]f32, &model.fields)[0..1];
        gl.programUniformMatrix4(shaderProgram, modelLoc, false, models);

        gl.clearColor(251.0 / 255.0, 250.0 / 255.0, 245.0 / 255.0, 1);
        gl.clear(.{ .color = true, .depth = false, .stencil = false });

        // var modelLoc = glGetUniformLocation(ourShader.ID, "model");
        // glUniformMatrix4fv(modelLoc, 1, GL_FALSE, glm::value_ptr(model));

        // Bind the VAO
        gl.bindVertexArray(vao);

        // Draw the triangle
        gl.drawArrays(gl.PrimitiveType.triangles, 0, verts.len);

        glfw.pollEvents();
        window.swapBuffers();
    }
}

const helloTriangle = [_]f32{
    -0.5, -0.5, 0.0, 0.5, 0,   0.0,
    0.5,  -0.5, 0.0, 0.5, 0.5, 0.0,
    0.0,  0.5,  0.0, 0.5, 0,   0.0,
};
const red = stl.V3{
    .x = 0.0,
    .y = 1.0,
    .z = 0.0,
};

// TODO: shrink down this iterated casting grossness into one line
const vertexShaderSources: [1][]u8 = .{vertexShaderSource};
const vertexShaderSource: []u8 = @constCast(vertexShaderSourceRaw);
const vertexShaderSourceRaw: []const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aCol;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\out vec3 VertColor;
    \\void main() {
    \\    gl_Position = projection * view * model * vec4(aPos, 1.0);
    \\    VertColor = aCol;
    \\}
;

// \\    gl_Position = view * vec4(aPos, 1.0);
// \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);

const fragmentShaderSources: [1][]u8 = .{fragmentShaderSource};
const fragmentShaderSource: []u8 = @constCast(fragmentShaderSourceRaw);
const fragmentShaderSourceRaw =
    \\#version 330 core
    \\in vec3 VertColor;
    \\out vec4 FragColor;
    \\void main() {
    \\    FragColor = vec4(VertColor, 1.0);
    \\}
;
// \\    FragColor = vec4(0.0,0.0,0.0, 1.0);

pub const State = struct {
    rotation_a: f32,
    rotation_b: f32,
};

pub fn processInput(window: glfw.Window, state: *State) void {
    if (window.getKey(.escape) == glfw.Action.press) {
        window.setShouldClose(true);
    }
    if (window.getKey(.left) == glfw.Action.press) {
        state.rotation_a += 0.01;
    }
    if (window.getKey(.right) == glfw.Action.press) {
        state.rotation_a -= 0.01;
    }
    if (window.getKey(.up) == glfw.Action.press) {
        state.rotation_b += 0.01;
    }
    if (window.getKey(.down) == glfw.Action.press) {
        state.rotation_b -= 0.01;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.backing_allocator;

    const stdout_handle = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_handle);
    const stdout = bw.writer();
    try stdout.print("Uses STDOUT\n", .{});

    var time: u64 = 0;
    var timer: std.time.Timer = try std.time.Timer.start();
    time = timer.lap();

    var stl_model = try stl.readStl(std.fs.cwd(), allocator, "3DBenchy.stl");

    try bw.flush();

    var stl_model_2 = stl_model;
    // ^ Copies the struct including its fields, but one field is a
    // point, so we need to deep copy that target of that pointer
    stl_model_2.tris = try stl_model_2.tris.clone(allocator);

    time = timer.lap();

    var xlower: f32 = 0;
    var xupper: f32 = 0;
    var ylower: f32 = 0;
    var yupper: f32 = 0;
    var zlower: f32 = 0;
    var zupper: f32 = 0;

    for (
        stl_model_2.tris.items(.a),
        stl_model_2.tris.items(.b),
        stl_model_2.tris.items(.c),
    ) |a, b, c| {
        xupper = @max(xupper, a.x);
        xupper = @max(xupper, b.x);
        xupper = @max(xupper, c.x);
        xlower = @min(xlower, a.x);
        xlower = @min(xlower, b.x);
        xlower = @min(xlower, c.x);
        yupper = @max(yupper, a.y);
        yupper = @max(yupper, b.y);
        yupper = @max(yupper, c.y);
        ylower = @min(ylower, a.y);
        ylower = @min(ylower, b.y);
        ylower = @min(ylower, c.y);
        zupper = @max(zupper, a.z);
        zupper = @max(zupper, b.z);
        zupper = @max(zupper, c.z);
        zlower = @min(zlower, a.z);
        zlower = @min(zlower, b.z);
        zlower = @min(zlower, c.z);
    }

    print("maxs: {d},{d},{d}", .{ xupper, yupper, zupper });
    print("mins: {d},{d},{d}", .{ xlower, ylower, zlower });

    for (
        stl_model_2.tris.items(.a),
        stl_model_2.tris.items(.b),
        stl_model_2.tris.items(.c),
    ) |*as, *bs, *cs| {
        as.x += xlower;
        bs.x += xlower;
        cs.x += xlower;
        as.y += ylower;
        bs.y += ylower;
        cs.y += ylower;
        as.z += zlower;
        bs.z += zlower;
        cs.z += zlower;

        as.x /= (xupper - xlower) * 2;
        bs.x /= (xupper - xlower) * 2;
        cs.x /= (xupper - xlower) * 2;
        as.y /= (yupper - ylower) * 2;
        bs.y /= (yupper - ylower) * 2;
        cs.y /= (yupper - ylower) * 2;
        as.z /= (zupper - zlower) * 2;
        bs.z /= (zupper - zlower) * 2;
        cs.z /= (zupper - zlower) * 2;
    }

    var stl_model_3: stl.Stl = try stl.concat(allocator, stl_model, stl_model_2);

    try writeStl(std.fs.cwd(), allocator, "output.stl", stl_model_3);

    // time = timer.lap();
    // try stdout.print("Write speed: {d:.2}GB/s\n", .{(@intToFloat(f32, stl_model_3.count * @sizeOf(stl.Triangle)) / (@intToFloat(f32, time) / 1_000_000_000)) / (1000 * 1000 * 1000)});
    // try bw.flush();
    try bw.flush();

    const vertSlice: []f32 = try allocator.alloc(f32, stl_model.count * 3 * 3 * 2);
    // 3 verts per triangle, 3 coords per vert
    var i: u32 = 0;
    for (
        stl_model_2.tris.items(.a),
        stl_model_2.tris.items(.b),
        stl_model_2.tris.items(.c),
    ) |a, b, c| {
        vertSlice[i + 0] = a.x;
        vertSlice[i + 1] = a.y;
        vertSlice[i + 2] = a.z;
        vertSlice[i + 3] = red.x;
        vertSlice[i + 4] = red.y;
        vertSlice[i + 5] = red.z;
        vertSlice[i + 6] = b.x;
        vertSlice[i + 7] = b.y;
        vertSlice[i + 8] = b.z;
        vertSlice[i + 9] = red.x;
        vertSlice[i + 10] = red.y;
        vertSlice[i + 11] = red.z;
        vertSlice[i + 12] = c.x;
        vertSlice[i + 13] = c.y;
        vertSlice[i + 14] = c.z;
        vertSlice[i + 15] = red.x;
        vertSlice[i + 16] = red.y;
        vertSlice[i + 17] = red.z;
        i += 18;
    }

    // var vertSlice: []f32 = @constCast(&helloTriangle);
    // var vertSlice: []f32 = std.mem.bytesAsSlice(f32, std.mem.sliceAsBytes(buf));
    var offset: u64 = 500;
    print("{d};{d};{d}\n", .{ vertSlice[6 * offset + 0], vertSlice[6 * offset + 1], vertSlice[6 * offset + 2] });
    print("{d};{d};{d}\n", .{ vertSlice[6], vertSlice[7], vertSlice[8] });
    print("{d};{d};{d}\n", .{ vertSlice[12], vertSlice[13], vertSlice[14] });
    try setupGlfwContext(allocator, vertSlice);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

pub fn writeStl(dir: std.fs.Dir, allocator: std.mem.Allocator, sub_path: []const u8, stl_model: stl.Stl) !void {
    var file = try dir.createFile(sub_path, .{ .read = false });
    defer file.close();
    // _ = try my_file.write(stl_model.header[0..]);

    const default_header = [_]u8{0} ** 80;
    _ = try file.write(&default_header);
    _ = try file.write(std.mem.asBytes(&stl_model.count));

    const buf: []u8 = try allocator.alloc(u8, stl_model.count * 50);
    defer allocator.free(buf);

    var i: u32 = 0;
    while (i < stl_model.count) {
        std.mem.copy(u8, buf[50 * i ..], std.mem.asBytes(&stl_model.tris.get(i))[0..50]);
        i += 1;
    }
    _ = try file.write(buf);
}
