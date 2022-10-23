const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const builtin = std.builtin;
const meta = std.meta;
const math = std.math;
const fmt = std.fmt;

const Type = builtin.Type;
const StructField = Type.StructField;
const Declaration = Type.Declaration;

const pad_str = "__pad";
const max_pad_size = pad_str.len + 3;

pub fn BitFlags(comptime size: type, comptime T: anytype) type {
    const bits = @typeInfo(size).Int.bits;
    var pad_num = 0;
    var num_fields = 0;
    var prev_bit = 0;
    var fields: [bits]StructField = undefined;

    for (@typeInfo(@TypeOf(T)).Struct.fields) |f| {
        const field_type = f.field_type;
        const bit = math.log2(@ptrCast(*align(1) const field_type, f.default_value.?).*) + 1;

        defer {
            num_fields += 1;
            prev_bit = bit;
        }

        const padding = bit - prev_bit - 1;
        if (padding != 0) {
            defer {
                num_fields += 1;
                pad_num += 1;
            }

            const name = fmt.comptimePrint("{s}{}", .{ pad_str, pad_num });

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

    if (prev_bit != bits) {
        defer num_fields += 1;

        const name = fmt.comptimePrint("{s}{}", .{ pad_str, pad_num });

        fields[num_fields] = .{
            .name = name,
            .field_type = meta.Int(.unsigned, bits - prev_bit),
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .Packed,
            .fields = fields[0..num_fields],
            .decls = &[_]Declaration{},
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

    const Flags = BitFlags(u16, .{
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
        while (i < flags.len) : (i += 1) {
            try testing.expect(std.mem.eql(u8, flags[i].name, expected[i].name) and
                flags[i].field_type == expected[i].field_type);
        }
    }
}
