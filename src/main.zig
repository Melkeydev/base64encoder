const std = @import("std");
const stdout = std.io.getStdOut().writer();

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers_sym = "0123456789+/";
        return Base64{
            ._table = upper ++ lower ++ numbers_sym,
        };
    }

    pub fn _char_at(self: Base64, index: usize) u8 {
        return self._table[index];
    }

    pub fn char_index(self: Base64, char: u8) u8 {
        if (char == '=') {
            return 64;
        }

        var index: u8 = 0;
        for (0..63) |i| {
            if (self._char_at(i) == char) {
                break;
            }
            index += 1;
        }
        return index;
    }

    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const n_out = try _calc_encode_length(input);
        var out = try allocator.alloc(u8, n_out);
        var buf = [3]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (input, 0..) |_, i| {
            buf[count] = input[i];
            count += 1;
            if (count == 3) {
                out[iout] = self._char_at(buf[0] >> 2);
                out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                out[iout + 2] = self._char_at(((buf[1] & 0x0f) << 2) + (buf[2] >> 6));
                out[iout + 3] = self._char_at(buf[2] & 0x3f);
                iout += 4;
                count = 0;
            }
        }

        if (count == 1) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at((buf[0] & 0x03) << 4);
            out[iout + 2] = '=';
            out[iout + 3] = '=';
        }

        if (count == 2) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            out[iout + 2] = self._char_at((buf[1] & 0x0f) << 2);
            out[iout + 3] = '=';
            iout += 4;
        }

        return out;
    }

    fn decode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const n_ouput = try _calc_decode_length(input);
        var output = try allocator.alloc(u8, n_ouput);
        var count: u8 = 0;
        var iout: u64 = 0;
        var buf = [4]u8{ 0, 0, 0, 0 };

        for (0..input.len) |i| {
            buf[count] = self.char_index(input[i]);
            count += 1;

            if (count == 4) {
                output[iout] = (buf[0] << 2) + (buf[1] >> 4);
                if (buf[2] != 64) {
                    output[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
                }
                if (buf[3] != 64) {
                    output[iout + 2] = (buf[2] << 6) + buf[3];
                }
                iout += 3;
                count = 0;
            }
        }
        return output;
    }
};

fn _calc_encode_length(input: []const u8) !usize {
    if (input.len < 3) { // text like "hi"
        const n_output: usize = 4;
        return n_output;
    }
    const n_output: usize = try std.math.divCeil(usize, input.len, 3);
    return n_output * 4;
}

fn _calc_decode_length_broken(input: []const u8) !usize {
    if (input.len < 4) {
        const n_output: usize = 3;
        return n_output;
    }
    const n_output: usize = try std.math.divFloor(usize, input.len, 4);
    return n_output * 3;
}

fn _calc_decode_length(input: []const u8) !usize {
    var length = input.len;
    if (length == 0) return 0;

    // Ignore padding characters '='
    if (input[length - 1] == '=') length -= 1;
    if (length > 1 and input[length - 1] == '=') length -= 1;

    return (length * 3) / 4; // Standard base64 formula
}

pub fn main() !void {}

test "testing encoder" {
    const ta = std.testing.allocator;

    const text = "Testing some more shit\n";

    const base64 = Base64.init();
    const encoded_text = try base64.encode(ta, text);
    defer ta.free(encoded_text);

    const decoded_text = try base64.decode(ta, encoded_text);
    defer ta.free(decoded_text);

    try std.testing.expectEqual(text.len, decoded_text.len);
    // try std.testing.expectEqualStrings(text, decoded_text);
}
