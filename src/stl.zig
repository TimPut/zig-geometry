const std = @import("std");

pub const V3 = packed struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Triangle = packed struct {
    n: V3,
    a: V3,
    b: V3,
    c: V3,
    attrib: u16,
};

pub const TriangleList = std.MultiArrayList(Triangle);

pub const Stl = struct {
    header: [80]u8,
    count: u32,
    tris: TriangleList,
};

pub fn readStl(dir: std.fs.Dir, allocator: std.mem.Allocator, sub_path: []const u8) !Stl {
    var file = try dir.openFile(sub_path, .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var stream = buffered.reader();

    var header: [80]u8 = undefined;
    header = try stream.readBytesNoEof(80);
    var count: u32 = undefined;
    count = try stream.readIntLittle(u32);

    var tris = TriangleList{};
    defer tris.deinit(allocator);
    try tris.ensureTotalCapacity(allocator, count);

    var i: u32 = 0;
    var tri: Triangle = undefined;

    i = 0;
    while (i < count) {
        const bytes = try stream.readBytesNoEof(@divExact(@bitSizeOf(Triangle), 8));
        @memcpy(std.mem.asBytes(&tri), &bytes, @divExact(@bitSizeOf(Triangle), 8));
        tris.appendAssumeCapacity(tri);
        i += 1;
    }

    var stl = Stl{
        .header = header,
        .count = count,
        .tris = tris,
    };

    return stl;
}
