const print = @import("std").debug.print;
const std = @import("std");

pub const V3 = packed struct {
    x: f32,
    y: f32,
    z: f32,
};

// pub const V3 = @Vector(3, f32);

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

pub fn concat(allocator: std.mem.Allocator, a: Stl, b: Stl) !Stl {
    var tris = TriangleList{};
    try tris.ensureTotalCapacity(allocator, a.count + b.count);
    for (0..a.count) |idx| {
        tris.appendAssumeCapacity(a.tris.get(idx));
    }
    for (0..b.count) |idx| {
        tris.appendAssumeCapacity(b.tris.get(idx));
    }

    var joined_stl = Stl{
        .header = a.header,
        .count = a.count + b.count,
        .tris = tris,
    };
    return joined_stl;
}

pub const IndexArray = struct {
    idxs: []u32,
    verts: []V3,
};

//  pub fn indexArrayfromTriangles(allocator: std.mem.Allocator, tris: TriangleList) !IndexArray {
//     var seen = std.AutoHashMap.init(allocator);
//     var idxs = allocator.alloc(u32, tris.len * 3);
//     var verts = allocator.alloc(V3, tris.len * 3);

//     // const insert = struct {
//     //     pub fn vertex(vs: *[]V3, v: V3) void {
//     //         vs[0] = v;
//     //     }
//     //     pub fn triangle(vs: *[]V3, is: *[]u32, t: Triangle) void {
//     //         vertex(vs, is, t.a);
//     //         vertex(vs, is, t.b);
//     //         vertex(vs, is, t.c);
//     //     }
//     // };

//     var i: u32 = 0;
//     for (tris.items(.a), tris.items(.b), tris.items(.c)) |a, b, c| {
//         var result = try seen.getOrPut(a.x);
//         if (result.found_existing) {
//             idxs[i] = result.value_ptr.*;
//         }
//     }
// }

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
    try tris.ensureTotalCapacity(allocator, count);

    var tri: Triangle = undefined;

    for (0..count) |_| {
        const bytes = try stream.readBytesNoEof(@divExact(@bitSizeOf(Triangle), 8));
        @memcpy(std.mem.asBytes(&tri), &bytes, @divExact(@bitSizeOf(Triangle), 8));
        tris.appendAssumeCapacity(tri);
    }

    var stl = Stl{
        .header = header,
        .count = count,
        .tris = tris,
    };

    return stl;
}
