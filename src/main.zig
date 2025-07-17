const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 20 }) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;
    _ = allocator;

    var lib = try std.DynLib.open("zig-out/libsha256.so");
    var hunt: *const fn () callconv(.C) c_int = undefined;
    hunt = lib.lookup(@TypeOf(hunt), "hunt") orelse return error.NoSymbol;
    _ = hunt();
}
