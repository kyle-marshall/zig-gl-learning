//! Based on https://learnopengl.com/Getting-started/Textures
//! see Tex.zig for the texture loading code.

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const Shader = @import("Shader.zig");
const Tex = @import("Tex.zig");

const log = std.log.scoped(.Engine);

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

/// When the window is resized, update the viewport.
fn framebufferSizeCallback(window: glfw.Window, width: u32, height: u32) void {
    _ = window;
    std.debug.print("framebufferSizeCallback: {d}x{d}\n", .{ width, height });
    gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));
}

pub fn main() !void {
    const SCREEN_WIDTH = 640;
    const SCREEN_HEIGHT = 480;
    const TITLE = "GLOWING RECTANGLE!";

    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        TITLE,
        null,
        null,
        .{},
    ) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    window.setFramebufferSizeCallback(framebufferSizeCallback);

    const proc: glfw.GLProc = undefined;
    try gl.load(proc, glGetProcAddress);

    gl.viewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

    // SHADER SETUP
    // ------------

    var allocator = std.heap.c_allocator;
    var cool_shader = try Shader.load(
        allocator,
        "shaders/cool.vs",
        "shaders/cool.fs",
    );
    defer cool_shader.deinit();

    // VERTEX DATA
    // -----------

    // zig fmt: off
    const vert_stride = 8 * @sizeOf(f32);
    const vertices = [_]f32{
        0.5, 0.5, 0.0, // top right
        1.0, 0.0, 0.0, // red
        1.0, 1.0, // tex

        0.5, -0.5, 0.0, // bottom right
        0.0, 1.0, 0.0, // green
        1.0, 0.0, // tex

        -0.5, -0.5, 0.0, // bottom left
        0.0, 0.0, 1.0, // blue
        0.0, 0.0, // tex

        -0.5, 0.5, 0.0, // top left
        1.0, 1.0, 0.0, // yellow
        0.0, 1.0, // tex
    };
    const indices = [_]u32{
        3, 1, 0, // first triangle
        1, 2, 3, // second triangle
    };
    // zig fmt: on
    var vao: u32 = undefined;
    var vbo: u32 = undefined;
    var ebo: u32 = undefined;
    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    defer gl.deleteBuffers(1, &vbo);
    gl.genBuffers(1, &ebo);
    defer gl.deleteBuffers(1, &ebo);

    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        vertices.len * @sizeOf(f32),
        &vertices,
        gl.STATIC_DRAW,
    );

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        indices.len * @sizeOf(u32),
        &indices,
        gl.STATIC_DRAW,
    );

    // vertex attributes

    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        vert_stride,
        null,
    );
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(
        1,
        3,
        gl.FLOAT,
        gl.FALSE,
        vert_stride,
        @intToPtr(*f32, @sizeOf(f32) * 3),
    );
    gl.enableVertexAttribArray(1);

    gl.vertexAttribPointer(
        2,
        2,
        gl.FLOAT,
        gl.FALSE,
        vert_stride,
        @intToPtr(*f32, @sizeOf(f32) * 6),
    );
    gl.enableVertexAttribArray(2);

    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);

    // TEXTURE SETUP
    // -------------
    const tex0_path = "img/sand-tile-32.png";
    const tex1_path = "img/weird-egg.png";

    var tex0 = try Tex.load(allocator, tex0_path);
    var tex1 = try Tex.load(allocator, tex1_path);

    // the following line can render wireframe polygons.
    // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

    // Wait for the user to close the window.
    var x_offset: f32 = 0.0;
    while (!window.shouldClose()) {
        var elapsed_seconds = glfw.getTime();

        glfw.pollEvents();

        if (window.getKey(.escape) == .press) {
            window.setShouldClose(true);
        }

        // bind textures/VAO

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, tex0.id);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, tex1.id);
        gl.bindVertexArray(vao);

        // update uniforms

        cool_shader.use();

        x_offset = @floatCast(f32, std.math.sin(elapsed_seconds / 2.0)) / 2.0;
        cool_shader.setFloat("xOffset", x_offset);

        cool_shader.setInt("tex0", 0);
        cool_shader.setInt("tex1", 1);

        // draw

        gl.clearColor(0.2, 0.3, 0.3, 1.0);

        gl.clear(gl.COLOR_BUFFER_BIT);

        gl.drawElements(gl.TRIANGLES, indices.len, gl.UNSIGNED_INT, null);

        window.swapBuffers();
    }
}
