const Self = @This();
const std = @import("std");
const gl = @import("gl");

id: u32,

pub fn load(
    allocator: std.mem.Allocator,
    vertex_shader_path: []const u8,
    fragment_shader_path: []const u8,
) !Self {
    var vertex_shader: u32 = try loadShader(allocator, vertex_shader_path, gl.VERTEX_SHADER);
    var fragment_shader: u32 = try loadShader(allocator, fragment_shader_path, gl.FRAGMENT_SHADER);

    var shader_program: u32 = undefined;
    shader_program = gl.createProgram();
    gl.attachShader(shader_program, vertex_shader);
    gl.attachShader(shader_program, fragment_shader);
    gl.linkProgram(shader_program);
    check_program_linking(shader_program);

    return Self{
        .id = shader_program,
    };
}

pub fn deinit(self: *Self) void {
    gl.deleteProgram(self.id);
}

fn loadShader(allocator: std.mem.Allocator, path: []const u8, shader_type: u32) !u32 {
    var cwd = std.fs.cwd();
    var shader_file = try cwd.openFile(path, .{ .mode = .read_only });
    var shader_file_size = (try shader_file.stat()).size;
    var shader_src_buff = try allocator.alloc(u8, shader_file_size);
    defer allocator.free(shader_src_buff);
    try shader_file.reader().readNoEof(shader_src_buff);
    var shader: u32 = gl.createShader(shader_type);
    var _string = @ptrCast([*c]const [*c]const u8, &shader_src_buff);
    gl.shaderSource(shader, 1, _string, null);
    gl.compileShader(shader);
    check_shader_compilation(shader);
    return shader;
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
    std.debug.print("shader compiled successfully\n", .{});
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

pub fn use(self: *Self) void {
    gl.useProgram(self.id);
}

pub fn setBool(self: *Self, name: [*c]const u8, value: bool) void {
    gl.uniform1i(
        gl.getUniformLocation(self.id, name),
        @boolToInt(value),
    );
}

pub fn setInt(self: *Self, name: [*c]const u8, value: i32) void {
    gl.uniform1i(
        gl.getUniformLocation(self.id, name),
        value,
    );
}

pub fn setFloat(self: *Self, name: [*c]const u8, value: f32) void {
    gl.uniform1f(
        gl.getUniformLocation(self.id, name),
        value,
    );
}
