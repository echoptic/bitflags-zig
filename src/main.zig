const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const builtin = std.builtin;
const meta = std.meta;

const TypeInfo = builtin.TypeInfo;
const StructField = TypeInfo.StructField;

const pad_str = "__pad";
const max_pad_size = pad_str.len + 3;

pub fn BitFlags(comptime num_bits: usize, comptime T: anytype) type {
    var pad_num = 0;
    var num_fields = 0;
    var prev_bit = 0;
    var fields: [num_bits]StructField = undefined;

    for (@typeInfo(@TypeOf(T)).Struct.fields) |f| {
        const bit_pos = blk: {
            var buf: [num_bits]u8 = undefined;
            break :blk (try std.fmt.bufPrint(&buf, "{b}", .{f.default_value})).len;
        };

        defer {
            num_fields += 1;
            prev_bit = bit_pos;
        }

        const padding = bit_pos - prev_bit - 1;
        if (padding != 0) {
            defer {
                num_fields += 1;
                pad_num += 1;
            }

            const name = blk: {
                var buf: [max_pad_size]u8 = undefined;
                break :blk try std.fmt.bufPrint(&buf, "{s}{}", .{ pad_str, pad_num });
            };

            fields[num_fields] = .{
                .name = name,
                .field_type = meta.Int(.unsigned, padding),
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }

        fields[num_fields] = .{
            .name = f.name,
            .field_type = u1,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    if (prev_bit != num_bits) {
        defer num_fields += 1;

        const name = blk: {
            var buf: [max_pad_size]u8 = undefined;
            break :blk try std.fmt.bufPrint(&buf, "{s}{}", .{ pad_str, pad_num });
        };

        fields[num_fields] = .{
            .name = name,
            .field_type = meta.Int(.unsigned, num_bits - prev_bit),
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .Packed,
            .fields = fields[0..num_fields],
            .decls = &[_]TypeInfo.Declaration{},
            .is_tuple = false,
        },
    });
}

test "fields test" {
    const Expected = packed struct {
        public: u1,
        __pad0: u3,
        final: u1,
        super: u1,
        __pad1: u3,
        interface: u1,
        abstract: u1,
        __pad2: u1,
        synthetic: u1,
        annotation: u1,
        enum_: u1,
        __pad3: u1,
    };

    const Flags = BitFlags(16, .{
        .public = 0x1,
        .final = 0x10,
        .super = 0x20,
        .interface = 0x200,
        .abstract = 0x400,
        .synthetic = 0x1000,
        .annotation = 0x2000,
        .enum_ = 0x4000,
    });

    comptime {
        const flags = @typeInfo(Flags).Struct.fields;
        const expected = @typeInfo(Expected).Struct.fields;
        try testing.expect(flags.len == expected.len);

        var i: usize = 0;
        inline while (i < flags.len) : (i += 1) {
            try testing.expect(std.mem.eql(u8, flags[i].name, expected[i].name) and
                flags[i].field_type == expected[i].field_type);
        }
    }
}

test "size test" {
    {
        const size = 8;
        const Flags = BitFlags(size, .{
            .f1 = 0x1,
            .f2 = 0x20,
        });

        try testing.expect(@bitSizeOf(Flags) == size);
    }

    {
        const size = 16;
        const Flags = BitFlags(size, .{
            .f1 = 0x1,
            .f2 = 0x20,
        });

        try testing.expect(@bitSizeOf(Flags) == size);
    }
}
