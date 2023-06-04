//! Extends https://github.com/hexops/mach-glfw-opengl-example in order to draw a triangle
//! Based on https://learnopengl.com/Getting-started/Hello-Triangle

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");

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

    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello, mach-glfw!", null, null, .{}) orelse {
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

    var vertex_shader: u32 = undefined;
    vertex_shader = gl.createShader(gl.VERTEX_SHADER);
    {
        var shader_source = @alignCast(@sizeOf([*c]const [*c]const u8), &VERTEX_SHADER_SOURCE);
        gl.shaderSource(vertex_shader, 1, shader_source, null);
        gl.compileShader(vertex_shader);
        check_shader_compilation(vertex_shader);
    }

    var fragment_shader: u32 = undefined;
    fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
    {
        var shader_source = @alignCast(@sizeOf([*c]const [*c]const u8), &FRAGMENT_SHADER_SOURCE);
        gl.shaderSource(fragment_shader, 1, shader_source, null);
        gl.compileShader(fragment_shader);
        check_shader_compilation(fragment_shader);
    }

    var shader_program: u32 = undefined;
    shader_program = gl.createProgram();
    gl.attachShader(shader_program, vertex_shader);
    gl.attachShader(shader_program, fragment_shader);
    gl.linkProgram(shader_program);
    check_program_linking(shader_program);

    gl.deleteShader(vertex_shader);
    gl.deleteShader(fragment_shader);

    // VERTEX DATA
    // -----------

    // zig fmt: off
    const vertices = [_]f32{
        -0.5, -0.5, 0.0,
        0.5, -0.5,  0.0,
        0.0, 0.5, 0.0,
    };
    // zig fmt: on

    var vao: u32 = undefined;
    var vbo: u32 = undefined;
    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    defer gl.deleteBuffers(1, &vbo);
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        vertices.len * @sizeOf(f32),
        &vertices,
        gl.STATIC_DRAW,
    );
    // usage can be gl.STATIC_DRAW, gl.DYNAMIC_DRAW, or gl.STREAM_DRAW
    // STREAM_DRAW: the data is set only once and used by the GPU at most a few times.
    // STATIC_DRAW: the data is set only once and used many times.
    // DYNAMIC_DRAW: the data is changed a lot and used many times.

    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        3 * @sizeOf(f32),
        null,
    );
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);

    // the following line can render wireframe polygons.
    // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

    // Wait for the user to close the window.
    while (!window.shouldClose()) {
        glfw.pollEvents();

        if (window.getKey(.escape) == .press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        gl.useProgram(shader_program);
        gl.bindVertexArray(vao);
        gl.drawArrays(gl.TRIANGLES, 0, 3);

        window.swapBuffers();
    }
}

fn check_shader_compilation(shader: u32) void {
    var success: i32 = undefined;
    gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        var info_log: [512]u8 = undefined;
        @memset(&info_log, 0);
        gl.getShaderInfoLog(shader, 512, null, &info_log);
        std.log.err("shader compilation failed:\n{s}\n", .{info_log});
        unreachable;
    }
    std.debug.print("vertex shader compiled successfully\n", .{});
}

fn check_program_linking(program: u32) void {
    var success: i32 = undefined;
    gl.getProgramiv(program, gl.LINK_STATUS, &success);
    if (success == 0) {
        var info_log: [512]u8 = undefined;
        @memset(&info_log, 0);
        gl.getProgramInfoLog(program, 512, null, &info_log);
        std.log.err("shader program linking failed:\n{s}\n", .{info_log});
        unreachable;
    }
    std.debug.print("shader program linked successfully\n", .{});
}

const VERTEX_SHADER_SOURCE: [*c]const u8 =
    \\#version 410 core
    \\layout (location = 0) in vec3 aPos;
    \\void main()
    \\{
    \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\}
;

const FRAGMENT_SHADER_SOURCE: [*c]const u8 =
    \\#version 410 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\}
;
