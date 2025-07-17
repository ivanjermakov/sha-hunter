const std = @import("std");
const builtin = @import("builtin");
const nanoid = @import("nanoid.zig");

const hash_size = 32;
const batch_size = 2 << 12;
const rand_size = 5;
const input_size = 14;
const goal_nonce = 2;
const alphabet = nanoid.alphabets.alphanumeric;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 20 }) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;
    _ = allocator;

    var lib = try std.DynLib.open("zig-out/libsha256.so");
    mcmCudaSha256HashBatch = lib.lookup(@TypeOf(mcmCudaSha256HashBatch), "mcm_cuda_sha256_hash_batch") orelse return error.NoSymbol;

    while (true) {
        var res_buf: [input_size * batch_size]u8 = undefined;
        var step_buf: [nanoid.computeRngStepBufferLength(res_buf.len, alphabet.len)]u8 = undefined;
        _ = nanoid.generateEx(std.crypto.random, alphabet, &res_buf, &step_buf);
        for (0..batch_size) |hash_idx| {
            const fixed_text_size = input_size - rand_size;
            const start = hash_idx * input_size;
            @memcpy(res_buf[start .. start + fixed_text_size], "ivnj-org/");
        }

        var hash_buf: [hash_size * batch_size]u8 = undefined;
        hashBatch(batch_size, &res_buf, input_size, hash_buf[0 .. hash_size * batch_size]);

        for (0..batch_size) |hash_idx| {
            const hash_start = hash_idx * hash_size;
            const hash = hash_buf[hash_start .. hash_start + hash_size];
            if (nonce(hash) >= goal_nonce) {
                std.debug.print("{s} ", .{res_buf[hash_idx * input_size .. (hash_idx + 1) * input_size]});
                printHex(hash);
                std.debug.print("\n", .{});
                return;
            }
        }
    }
}

var mcmCudaSha256HashBatch: *const fn (in: [*]c_char, inlen: c_uint, out: [*]c_char, n_batch: c_uint) callconv(.C) void = undefined;

fn hashBatch(comptime batchSize: usize, in: []const u8, stride: usize, out: *[hash_size * batchSize]u8) void {
    mcmCudaSha256HashBatch(@constCast(@ptrCast(in.ptr)), @intCast(stride), @ptrCast(out.ptr), batchSize);
}

fn printHex(bytes: []u8) void {
    for (0..bytes.len) |i|{
        if (i > 0 and i % 4 == 0) std.debug.print(" ", .{});
        std.debug.print("{x:0>2}", .{bytes[i]});
    }
}

/// Returns zero-byte prefix length
pub fn nonce(data: []const u8) usize {
    for (0..data.len) |i| {
        if (data[i] != 0) return i;
    }
    return data.len;
}
