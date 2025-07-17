const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 20 }) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

    std.debug.print("Hello\n", .{});
    var lib = try std.DynLib.open("./libsha256.so");
    var hash_fn: *const fn (in: [*]c_char, inlen: c_uint, out: [*]c_char, n_batch: c_uint) callconv(.C) void = undefined;
    hash_fn = lib.lookup(@TypeOf(hash_fn), "mcm_cuda_sha256_hash_batch") orelse return error.NoSymbol;
    const str: []const u8 = try allocator.dupe(u8, "HelloWorld");
    defer allocator.free(str);
    const hash = try allocator.alloc(u8, 64);
    defer allocator.free(hash);
    hash_fn(@constCast(@ptrCast(str.ptr)), @intCast(str.len/2), @ptrCast(hash.ptr), 2);
    std.debug.print("hash: ", .{});
    printHex(hash[0..32]);
    std.debug.print("\n", .{});
    std.debug.print("hash: ", .{});
    printHex(hash[32..64]);
    std.debug.print("\n", .{});
}

fn printHex(bytes: []u8) void {
    for (bytes) |byte| std.debug.print("{x}", .{byte});
}
