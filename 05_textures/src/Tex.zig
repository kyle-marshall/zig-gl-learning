const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const zigimg = @import("zigimg");
const Image = zigimg.Image;

id: u32,

/// Flip the image vertically in-place.
/// Useful because OpenGL uses lower-left corner as origin for textures.
fn flipImageVertically(allocator: Allocator, image: *Image) !void {
    const sourceBytes = image.rawBytes();
    const bytesPerRow = image.rowByteSize();
    const buffer = try allocator.alloc(u8, sourceBytes.len);
    defer allocator.free(buffer);
    for (0..image.height) |source_y| {
        const dest_y = image.height - source_y - 1;
        const source_offset = bytesPerRow * source_y;
        const dest_offset = bytesPerRow * dest_y;
        const sourceRow = sourceBytes[source_offset .. source_offset + bytesPerRow];
        var destRow = buffer[dest_offset .. dest_offset + bytesPerRow];
        @memcpy(destRow, sourceRow);
    }
    @memcpy(@constCast(sourceBytes), buffer);
}

pub fn load(allocator: Allocator, image_path: []const u8) !Self {
    var img = try Image.fromFilePath(allocator, image_path);
    try flipImageVertically(allocator, &img);
    defer img.deinit();

    const width = @intCast(c_int, img.width);
    const height = @intCast(c_int, img.height);
    std.debug.print("creating texture from image: {s} ({d}x{d})\n", .{ image_path, width, height });

    var tex_id: u32 = undefined;
    gl.genTextures(1, &tex_id);
    gl.bindTexture(gl.TEXTURE_2D, tex_id);
    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        width,
        height,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        @alignCast(@sizeOf(u8) * 4, &img.pixels.rgba32[0]),
    );
    gl.generateMipmap(gl.TEXTURE_2D);
    std.debug.print("created texture {d}\n", .{tex_id});
    return Self{ .id = tex_id };
}
