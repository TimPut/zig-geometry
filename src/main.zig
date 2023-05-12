const print = @import("std").debug.print;
const std = @import("std");
const stl = @import("stl.zig");
const Triangle = @import("stl.zig").Triangle;
const glfw = @import("glfw");
const gl = @import("zgl");
const math = @import("zlm");
const log = std.log.scoped(.Engine);
const log2 = std.log.scoped(std.log.default_log_scope);

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?*const anyopaque {
    _ = p;
    return glfw.getProcAddress(proc);
}

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn setupGlfwContext(allocator: std.mem.Allocator, verts: []f32, colors: []f32, normals: []f32) !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    var fullscreen = false;
    var primaryMonitor = glfw.Monitor.getPrimary();

    var width: u32 = 1920;
    var height: u32 = 1080;
    // Create our window
    const window = glfw.Window.create(width, height, "floatMe", if (fullscreen) primaryMonitor else null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 5,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    // defer window.destroy();
    glfw.makeContextCurrent(window);
    // En/Disable VSYNC
    glfw.swapInterval(1);
    const proc: glfw.GLProc = undefined;
    try gl.loadExtensions(proc, glGetProcAddress);

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
    gl.bufferUninitialized(gl.BufferTarget.array_buffer, f32, (verts.len + colors.len + normals.len) * 3 * @sizeOf(f32), gl.BufferUsage.static_draw);

    gl.bufferSubData(gl.BufferTarget.array_buffer, 0, f32, verts);
    gl.bufferSubData(gl.BufferTarget.array_buffer, verts.len * 3 * @sizeOf(f32), f32, colors);
    gl.bufferSubData(gl.BufferTarget.array_buffer, (verts.len * 3 + colors.len * 3) * @sizeOf(f32), f32, normals);

    print("{d}\n", .{verts.len});
    print("{d}\n", .{colors[2031349]});
    print("{d}\n", .{normals[2031349]});

    // Set up the vertex attributes
    // Positions
    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 3 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);
    // Colors
    gl.vertexAttribPointer(1, 3, gl.Type.float, false, 3 * @sizeOf(f32), verts.len * 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);
    // Normals
    gl.vertexAttribPointer(2, 3, gl.Type.float, false, 3 * @sizeOf(f32), (verts.len * 3 + colors.len * 3) * @sizeOf(f32));
    gl.enableVertexAttribArray(2);

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
    log2.debug("{!s}\n", .{shaderLog});
    var shaderLog2 = gl.getShaderInfoLog(fragmentShader, allocator);
    // var shaderLog2 = gl.getShader(fragmentShader, gl.ShaderParameter.shader_source_length);
    print("{!s}\n", .{shaderLog2});

    var shaderProgram: gl.Program = undefined;
    shaderProgram = gl.createProgram();
    defer gl.deleteProgram(shaderProgram);
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);
    gl.useProgram(shaderProgram);

    var lightPosLoc = gl.getUniformLocation(shaderProgram, "lightPos");
    var lightColorLoc = gl.getUniformLocation(shaderProgram, "lightColor");
    gl.programUniform3f(shaderProgram, lightPosLoc, 10, 10, 10);
    gl.programUniform3f(shaderProgram, lightColorLoc, 1, 1, 2);

    // compiled into the program and no longer needed
    vertexShader.delete();
    fragmentShader.delete();

    gl.cullFace(gl.CullMode.front_and_back);

    var viewLoc = gl.getUniformLocation(shaderProgram, "view");
    const degree: f32 = 0.0174532925199432957692369076848861271344287188854172545609719144; // pi/180
    var projectionLoc = gl.getUniformLocation(shaderProgram, "projection");
    var projection = math.Mat4.createPerspective(90.0 * degree, @intToFloat(f32, width) / @intToFloat(f32, height), 0.001, 10.0);

    // gross casting: https://github.com/ziglang/zig/issues/3156
    const projections: []const [4][4]f32 = @ptrCast([*]const [4][4]f32, &projection.fields)[0..1];

    // Failed attempt at getting resize to work. Passing functions is painful
    // const SizeCallback = struct {
    //     projection: *math.Mat4,
    //     pub fn onResize(w: glfw.Window, width_: i32, height_: i32) void {
    //         _ = w;
    //         gl.viewport(0, 0, width_, height_);
    //     }
    // };

    // const resizeCallback = SizeCallback{ .projection = &projection };
    // window.setSizeCallback(resizeCallback.onResize);
    // // gl.viewport(0, 0, width, height);

    // print("{any}", .{projections});
    // print("{any}", .{projectionLoc});
    gl.programUniformMatrix4(shaderProgram, projectionLoc, false, projections);

    var state: State = .{
        .rotation_a = 0,
        .rotation_b = 0,
        .rotation_ca = 0,
        .rotation_cb = 0,
        .camera_radius = 1,
    };
    var modelLoc = gl.getUniformLocation(shaderProgram, "model");
    var camera_radius: f32 = 1;
    var camera = math.Vec3.new(1, 0, 1);

    gl.enable(gl.Capabilities.depth_test);

    var time: u64 = 0;
    var timer: std.time.Timer = try std.time.Timer.start();
    var frame_sum: u64 = 0;
    var frame_sum_n: u64 = 10;

    var frame_counter: u64 = 0;
    while (!window.shouldClose()) : (frame_counter += 1) {
        processInput(window, &state);

        camera.x = @cos(state.rotation_ca) * @sin(state.rotation_cb) * camera_radius;
        camera.y = @cos(state.rotation_ca) * @cos(state.rotation_cb) * camera_radius;
        camera.z = @sin(state.rotation_ca) * camera_radius;
        camera_radius = state.camera_radius;

        var origin = math.Vec3.zero;
        var up = math.Vec3.unitZ;

        var view = math.Mat4.createLookAt(camera, origin, up);
        const views: []const [4][4]f32 = @ptrCast([*]const [4][4]f32, &view.fields)[0..1];
        gl.programUniformMatrix4(shaderProgram, viewLoc, false, views);

        var model = math.Mat4.createAngleAxis(math.Vec3.unitY, state.rotation_a).mul(math.Mat4.createAngleAxis(math.Vec3.unitX, state.rotation_b));
        const models: []const [4][4]f32 = @ptrCast([*]const [4][4]f32, &model.fields)[0..1];
        gl.programUniformMatrix4(shaderProgram, modelLoc, false, models);

        gl.clearColor(251.0 / 255.0, 250.0 / 255.0, 245.0 / 255.0, 1);
        gl.clear(.{ .color = true, .depth = true, .stencil = false });

        // Bind the VAO
        gl.bindVertexArray(vao);

        // Draw the triangle
        // gl.drawArrays(gl.PrimitiveType.lines, 0, verts.len);
        gl.drawArrays(gl.PrimitiveType.triangles, 0, verts.len);

        glfw.pollEvents();

        time = timer.lap();
        frame_sum *= frame_sum_n - 1;
        frame_sum /= frame_sum_n;
        time /= frame_sum_n;
        frame_sum += time;
        print("\rCPU Frametime: {d:.3}ms", .{@intToFloat(f64, frame_sum) / 1_000_000});

        window.swapBuffers();
        time = timer.lap();
    }
}

const helloTriangle = [_]f32{
    -0.5, -0.5, 0.0, 0.5, 0,   0.0,
    0.5,  -0.5, 0.0, 0.5, 0.5, 0.0,
    0.0,  0.5,  0.0, 0.5, 0,   0.0,
};
const red = stl.V3{
    .x = 0.3,
    .y = 0.3,
    .z = 0.3,
};

// TODO: shrink down this iterated casting grossness into one line
const vertexShaderSources: [1][]u8 = .{vertexShaderSource};
const vertexShaderSource: []u8 = @constCast(vertexShaderSourceRaw);
const vertexShaderSourceRaw: []const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aCol;
    \\layout (location = 2) in vec3 aNormal;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\out vec3 VertColor;
    \\out vec4 FragPos;
    \\out vec3 Normal;
    \\
    \\void main() {
    \\    FragPos = model * vec4(aPos, 1.0);
    \\    Normal = aNormal;
    \\    VertColor = aCol;
    \\    gl_Position = projection * view * FragPos;
    \\}
;

const fragmentShaderSources: [1][]u8 = .{fragmentShaderSource};
const fragmentShaderSource: []u8 = @constCast(fragmentShaderSourceRaw);
const fragmentShaderSourceRaw =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\in vec3 VertColor;
    \\in vec4 FragPos;
    \\in vec3 Normal;
    \\uniform vec3 lightColor;
    \\uniform vec3 lightPos;
    \\void main() {
    \\  float ambientStrength = 0.4;
    \\  vec3 ambient = ambientStrength * lightColor;
    \\
    \\  vec3 norm = normalize(Normal);
    \\  vec3 lightDir = normalize(lightPos - vec3(FragPos));
    \\  float diff = max(dot(norm, lightDir), 0.0);
    \\  vec3 diffuse = diff * lightColor;
    \\
    \\  vec3 result = (ambient + diffuse) * VertColor;
    \\  FragColor = vec4(result, 1.0);
    \\}
;

pub const State = struct {
    rotation_a: f32,
    rotation_b: f32,
    rotation_ca: f32,
    rotation_cb: f32,
    camera_radius: f32,
};

pub fn processInput(window: glfw.Window, state: *State) void {
    if (window.getKey(.escape) == glfw.Action.press) {
        window.setShouldClose(true);
    }
    if (window.getKey(.left) == glfw.Action.press) {
        state.rotation_a += 0.1;
    }
    if (window.getKey(.right) == glfw.Action.press) {
        state.rotation_a -= 0.1;
    }
    if (window.getKey(.up) == glfw.Action.press) {
        state.rotation_b += 0.1;
    }
    if (window.getKey(.down) == glfw.Action.press) {
        state.rotation_b -= 0.1;
    }
    if (window.getKey(.w) == glfw.Action.press) {
        state.rotation_ca += 0.1;
        state.rotation_ca = @min(state.rotation_ca, 3.14159 / 2.0);
    }
    if (window.getKey(.s) == glfw.Action.press) {
        state.rotation_ca -= 0.1;
        state.rotation_ca = @max(state.rotation_ca, -3.14159 / 2.0);
    }
    if (window.getKey(.a) == glfw.Action.press) {
        state.rotation_cb += 0.1;
    }
    if (window.getKey(.d) == glfw.Action.press) {
        state.rotation_cb -= 0.1;
    }
    if (window.getKey(.kp_add) == glfw.Action.press) {
        state.camera_radius *= 0.99;
    }
    if (window.getKey(.kp_subtract) == glfw.Action.press) {
        state.camera_radius *= 1.01;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    // const stdout_handle = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_handle);
    // const stdout = bw.writer();
    // try stdout.print("Uses STDOUT\n", .{});
    // try bw.flush();

    var stl_model = try stl.readStl(std.fs.cwd(), allocator, "3DBenchy.stl");

    // var stl_model_2 = stl_model;
    // ^ Copies the struct including its fields, but one field is a
    // pointer, so we need to deep copy that target of that pointer
    // stl_model_2.tris = try stl_model_2.tris.clone(allocator);

    var xlower: f32 = 0;
    var xupper: f32 = 0;
    var ylower: f32 = 0;
    var yupper: f32 = 0;
    var zlower: f32 = 0;
    var zupper: f32 = 0;

    for (
        stl_model.tris.items(.a),
        stl_model.tris.items(.b),
        stl_model.tris.items(.c),
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

    // print("maxs: {d},{d},{d}", .{ xupper, yupper, zupper });
    // print("mins: {d},{d},{d}", .{ xlower, ylower, zlower });
    var scale: f32 = @max(zupper - zlower, @max(yupper - ylower, xupper - xlower));
    var xcenter: f32 = (xupper + xlower) / 2;
    var ycenter: f32 = (yupper + ylower) / 2;
    var zcenter: f32 = (zupper + zlower) / 2;
    for (
        stl_model.tris.items(.a),
        stl_model.tris.items(.b),
        stl_model.tris.items(.c),
    ) |*as, *bs, *cs| {
        as.x -= xcenter;
        bs.x -= xcenter;
        cs.x -= xcenter;
        as.y -= ycenter;
        bs.y -= ycenter;
        cs.y -= ycenter;
        as.z -= zcenter;
        bs.z -= zcenter;
        cs.z -= zcenter;

        as.x /= scale;
        bs.x /= scale;
        cs.x /= scale;
        as.y /= scale;
        bs.y /= scale;
        cs.y /= scale;
        as.z /= scale;
        bs.z /= scale;
        cs.z /= scale;
    }

    const vertSlice: []f32 = try allocator.alloc(f32, stl_model.count * 3 * 3);
    const colorSlice: []f32 = try allocator.alloc(f32, stl_model.count * 3 * 3);
    const normalSlice: []f32 = try allocator.alloc(f32, stl_model.count * 3 * 3);

    for (
        0..,
        stl_model.tris.items(.a),
        stl_model.tris.items(.b),
        stl_model.tris.items(.c),
    ) |i, a, b, c| {
        vertSlice[9 * i + 0] = a.x;
        vertSlice[9 * i + 1] = a.y;
        vertSlice[9 * i + 2] = a.z;
        vertSlice[9 * i + 3] = b.x;
        vertSlice[9 * i + 4] = b.y;
        vertSlice[9 * i + 5] = b.z;
        vertSlice[9 * i + 6] = c.x;
        vertSlice[9 * i + 7] = c.y;
        vertSlice[9 * i + 8] = c.z;
    }
    for (
        0..stl_model.count * 3,
    ) |i| {
        colorSlice[3 * i + 0] = red.x;
        colorSlice[3 * i + 1] = red.y;
        colorSlice[3 * i + 2] = red.z;
    }
    for (
        0..,
        stl_model.tris.items(.n),
    ) |i, n| {
        normalSlice[9 * i + 0] = n.x;
        normalSlice[9 * i + 1] = n.y;
        normalSlice[9 * i + 2] = n.z;
        normalSlice[9 * i + 3] = n.x;
        normalSlice[9 * i + 4] = n.y;
        normalSlice[9 * i + 5] = n.z;
        normalSlice[9 * i + 6] = n.x;
        normalSlice[9 * i + 7] = n.y;
        normalSlice[9 * i + 8] = n.z;
    }

    try setupGlfwContext(allocator, vertSlice, colorSlice, normalSlice);
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
