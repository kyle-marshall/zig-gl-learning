//! Based on 1st half of https://learnopengl.com/Getting-started/Shaders

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");

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
        0.5, 0.5, 0.0, // top right
        1.0, 0.0, 0.0, // red

        0.5, -0.5, 0.0, // bottom right
        0.0, 1.0, 0.0, // green

        -0.5, -0.5, 0.0, // bottom left
        0.0, 0.0, 1.0, // blue

        -0.5, 0.5, 0.0, // top left
        1.0, 1.0, 0.0, // yellow
    };
    const indices = [_]u32{
        0, 1, 3, // first triangle
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

    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        6 * @sizeOf(f32),
        null,
    );
    gl.enableVertexAttribArray(0);

    gl.vertexAttribPointer(
        1,
        3,
        gl.FLOAT,
        gl.FALSE,
        6 * @sizeOf(f32),
        @intToPtr(*anyopaque, @sizeOf(f32) * 3),
    );
    gl.enableVertexAttribArray(1);

    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);

    // the following line can render wireframe polygons.
    // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

    // Wait for the user to close the window.
    while (!window.shouldClose()) {
        const elapsed_seconds = glfw.getTime();

        glfw.pollEvents();

        if (window.getKey(.escape) == .press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        const green_value: f32 = (@floatCast(f32, std.math.sin(elapsed_seconds)) / 2.0) + 0.5;
        const vertex_color_location = gl.getUniformLocation(shader_program, "ourColor");

        gl.useProgram(shader_program);
        // shader program must be used before setting uniforms
        gl.uniform4f(vertex_color_location, 0.0, green_value, 0.0, 1.0);
        gl.bindVertexArray(vao);
        gl.drawElements(gl.TRIANGLES, indices.len, gl.UNSIGNED_INT, null);

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
    \\layout (location = 1) in vec3 aColor;
    \\
    \\out vec3 ourColor;
    \\
    \\void main()
    \\{
    \\    gl_Position = vec4(aPos, 1.0);
    \\    ourColor = aColor;
    \\}
;

const FRAGMENT_SHADER_SOURCE: [*c]const u8 =
    \\#version 410 core
    \\out vec4 FragColor;
    \\in vec3 ourColor;
    \\
    \\void main()
    \\{
    \\    FragColor = vec4(ourColor, 1.0);
    \\}
;
