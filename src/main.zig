const std = @import("std");
const builtin = @import("builtin");

const hash_size = 32;

var mcmCudaSha256HashBatch: *const fn (in: [*]c_char, inlen: c_uint, out: [*]c_char, n_batch: c_uint) callconv(.C) void = undefined;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 20 }) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

    var lib = try std.DynLib.open("./libsha256.so");
    mcmCudaSha256HashBatch = lib.lookup(@TypeOf(mcmCudaSha256HashBatch), "mcm_cuda_sha256_hash_batch") orelse return error.NoSymbol;

    const str: []const u8 = try allocator.dupe(u8, "HelloWorld");
    defer allocator.free(str);
    const hash = try allocator.alloc(u8, hash_size * 2);
    defer allocator.free(hash);
    const batch_size = 2;
    const stride = str.len / batch_size;
    hashBatch(batch_size, str, stride, hash[0 .. hash_size * batch_size]);

    for (0..batch_size) |hash_idx| {
        std.debug.print("{s} ", .{str[hash_idx * stride .. (hash_idx + 1) * stride]});
        printHex(hash[hash_idx * hash_size .. (hash_idx + 1) * hash_size]);
        std.debug.print("\n", .{});
    }
}

fn hashBatch(comptime batchSize: usize, in: []const u8, stride: usize, out: *[hash_size * batchSize]u8) void {
    mcmCudaSha256HashBatch(@constCast(@ptrCast(in.ptr)), @intCast(stride), @ptrCast(out.ptr), batchSize);
}

fn printHex(bytes: []u8) void {
    for (bytes) |byte| std.debug.print("{x}", .{byte});
}
