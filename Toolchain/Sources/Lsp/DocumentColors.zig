const std = @import("std");
const LexerModule = @import("../Lexer.zig");
const Protocol = @import("Protocol.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Token = LexerModule.Token;

const NamedColor = struct {
    name: []const u8,
    bytes: [4]u8,
};

const named_colors = [_]NamedColor{
    .{ .name = "white", .bytes = .{ 255, 255, 255, 255 } },
    .{ .name = "black", .bytes = .{ 0, 0, 0, 255 } },
    .{ .name = "gray", .bytes = .{ 127, 127, 127, 255 } },
    .{ .name = "transparent", .bytes = .{ 0, 0, 0, 0 } },
    .{ .name = "gizmos", .bytes = .{ 255, 214, 64, 255 } },
    .{ .name = "red_50", .bytes = .{ 254, 242, 242, 255 } },
    .{ .name = "red_100", .bytes = .{ 255, 226, 226, 255 } },
    .{ .name = "red_200", .bytes = .{ 255, 201, 201, 255 } },
    .{ .name = "red_300", .bytes = .{ 255, 162, 162, 255 } },
    .{ .name = "red_400", .bytes = .{ 255, 100, 103, 255 } },
    .{ .name = "red_500", .bytes = .{ 251, 44, 54, 255 } },
    .{ .name = "red_600", .bytes = .{ 231, 0, 11, 255 } },
    .{ .name = "red_700", .bytes = .{ 193, 0, 7, 255 } },
    .{ .name = "red_800", .bytes = .{ 159, 7, 18, 255 } },
    .{ .name = "red_900", .bytes = .{ 130, 24, 26, 255 } },
    .{ .name = "red_950", .bytes = .{ 70, 8, 9, 255 } },
    .{ .name = "orange_50", .bytes = .{ 255, 247, 237, 255 } },
    .{ .name = "orange_100", .bytes = .{ 255, 237, 212, 255 } },
    .{ .name = "orange_200", .bytes = .{ 255, 214, 167, 255 } },
    .{ .name = "orange_300", .bytes = .{ 255, 184, 106, 255 } },
    .{ .name = "orange_400", .bytes = .{ 255, 137, 4, 255 } },
    .{ .name = "orange_500", .bytes = .{ 255, 105, 0, 255 } },
    .{ .name = "orange_600", .bytes = .{ 245, 73, 0, 255 } },
    .{ .name = "orange_700", .bytes = .{ 202, 53, 0, 255 } },
    .{ .name = "orange_800", .bytes = .{ 159, 45, 0, 255 } },
    .{ .name = "orange_900", .bytes = .{ 126, 42, 12, 255 } },
    .{ .name = "orange_950", .bytes = .{ 68, 19, 6, 255 } },
    .{ .name = "amber_50", .bytes = .{ 255, 251, 235, 255 } },
    .{ .name = "amber_100", .bytes = .{ 254, 243, 198, 255 } },
    .{ .name = "amber_200", .bytes = .{ 254, 230, 133, 255 } },
    .{ .name = "amber_300", .bytes = .{ 255, 210, 48, 255 } },
    .{ .name = "amber_400", .bytes = .{ 255, 185, 0, 255 } },
    .{ .name = "amber_500", .bytes = .{ 254, 154, 0, 255 } },
    .{ .name = "amber_600", .bytes = .{ 225, 113, 0, 255 } },
    .{ .name = "amber_700", .bytes = .{ 187, 77, 0, 255 } },
    .{ .name = "amber_800", .bytes = .{ 151, 60, 0, 255 } },
    .{ .name = "amber_900", .bytes = .{ 123, 51, 6, 255 } },
    .{ .name = "amber_950", .bytes = .{ 70, 25, 1, 255 } },
    .{ .name = "yellow_50", .bytes = .{ 254, 252, 232, 255 } },
    .{ .name = "yellow_100", .bytes = .{ 254, 249, 194, 255 } },
    .{ .name = "yellow_200", .bytes = .{ 255, 240, 133, 255 } },
    .{ .name = "yellow_300", .bytes = .{ 255, 223, 32, 255 } },
    .{ .name = "yellow_400", .bytes = .{ 253, 199, 0, 255 } },
    .{ .name = "yellow_500", .bytes = .{ 240, 177, 0, 255 } },
    .{ .name = "yellow_600", .bytes = .{ 208, 135, 0, 255 } },
    .{ .name = "yellow_700", .bytes = .{ 166, 95, 0, 255 } },
    .{ .name = "yellow_800", .bytes = .{ 137, 75, 0, 255 } },
    .{ .name = "yellow_900", .bytes = .{ 115, 62, 10, 255 } },
    .{ .name = "yellow_950", .bytes = .{ 67, 32, 4, 255 } },
    .{ .name = "lime_50", .bytes = .{ 247, 254, 231, 255 } },
    .{ .name = "lime_100", .bytes = .{ 236, 252, 202, 255 } },
    .{ .name = "lime_200", .bytes = .{ 216, 249, 153, 255 } },
    .{ .name = "lime_300", .bytes = .{ 187, 244, 81, 255 } },
    .{ .name = "lime_400", .bytes = .{ 154, 230, 0, 255 } },
    .{ .name = "lime_500", .bytes = .{ 124, 207, 0, 255 } },
    .{ .name = "lime_600", .bytes = .{ 94, 165, 0, 255 } },
    .{ .name = "lime_700", .bytes = .{ 73, 125, 0, 255 } },
    .{ .name = "lime_800", .bytes = .{ 60, 99, 0, 255 } },
    .{ .name = "lime_900", .bytes = .{ 53, 83, 14, 255 } },
    .{ .name = "lime_950", .bytes = .{ 25, 46, 3, 255 } },
    .{ .name = "green_50", .bytes = .{ 240, 253, 244, 255 } },
    .{ .name = "green_100", .bytes = .{ 220, 252, 231, 255 } },
    .{ .name = "green_200", .bytes = .{ 185, 248, 207, 255 } },
    .{ .name = "green_300", .bytes = .{ 123, 241, 168, 255 } },
    .{ .name = "green_400", .bytes = .{ 5, 223, 114, 255 } },
    .{ .name = "green_500", .bytes = .{ 0, 201, 80, 255 } },
    .{ .name = "green_600", .bytes = .{ 0, 166, 62, 255 } },
    .{ .name = "green_700", .bytes = .{ 0, 130, 54, 255 } },
    .{ .name = "green_800", .bytes = .{ 1, 102, 48, 255 } },
    .{ .name = "green_900", .bytes = .{ 13, 84, 43, 255 } },
    .{ .name = "green_950", .bytes = .{ 3, 46, 21, 255 } },
    .{ .name = "emerald_50", .bytes = .{ 236, 253, 245, 255 } },
    .{ .name = "emerald_100", .bytes = .{ 208, 250, 229, 255 } },
    .{ .name = "emerald_200", .bytes = .{ 164, 244, 207, 255 } },
    .{ .name = "emerald_300", .bytes = .{ 94, 233, 181, 255 } },
    .{ .name = "emerald_400", .bytes = .{ 0, 212, 146, 255 } },
    .{ .name = "emerald_500", .bytes = .{ 0, 188, 125, 255 } },
    .{ .name = "emerald_600", .bytes = .{ 0, 153, 102, 255 } },
    .{ .name = "emerald_700", .bytes = .{ 0, 122, 85, 255 } },
    .{ .name = "emerald_800", .bytes = .{ 0, 96, 69, 255 } },
    .{ .name = "emerald_900", .bytes = .{ 0, 79, 59, 255 } },
    .{ .name = "emerald_950", .bytes = .{ 0, 44, 34, 255 } },
    .{ .name = "teal_50", .bytes = .{ 240, 253, 250, 255 } },
    .{ .name = "teal_100", .bytes = .{ 203, 251, 241, 255 } },
    .{ .name = "teal_200", .bytes = .{ 150, 247, 228, 255 } },
    .{ .name = "teal_300", .bytes = .{ 70, 236, 213, 255 } },
    .{ .name = "teal_400", .bytes = .{ 0, 213, 190, 255 } },
    .{ .name = "teal_500", .bytes = .{ 0, 187, 167, 255 } },
    .{ .name = "teal_600", .bytes = .{ 0, 150, 137, 255 } },
    .{ .name = "teal_700", .bytes = .{ 0, 120, 111, 255 } },
    .{ .name = "teal_800", .bytes = .{ 0, 95, 90, 255 } },
    .{ .name = "teal_900", .bytes = .{ 11, 79, 74, 255 } },
    .{ .name = "teal_950", .bytes = .{ 2, 47, 46, 255 } },
    .{ .name = "cyan_50", .bytes = .{ 236, 254, 255, 255 } },
    .{ .name = "cyan_100", .bytes = .{ 206, 250, 254, 255 } },
    .{ .name = "cyan_200", .bytes = .{ 162, 244, 253, 255 } },
    .{ .name = "cyan_300", .bytes = .{ 83, 234, 253, 255 } },
    .{ .name = "cyan_400", .bytes = .{ 0, 211, 242, 255 } },
    .{ .name = "cyan_500", .bytes = .{ 0, 184, 219, 255 } },
    .{ .name = "cyan_600", .bytes = .{ 0, 146, 184, 255 } },
    .{ .name = "cyan_700", .bytes = .{ 0, 117, 149, 255 } },
    .{ .name = "cyan_800", .bytes = .{ 0, 95, 120, 255 } },
    .{ .name = "cyan_900", .bytes = .{ 16, 78, 100, 255 } },
    .{ .name = "cyan_950", .bytes = .{ 5, 51, 69, 255 } },
    .{ .name = "sky_50", .bytes = .{ 240, 249, 255, 255 } },
    .{ .name = "sky_100", .bytes = .{ 223, 242, 254, 255 } },
    .{ .name = "sky_200", .bytes = .{ 184, 230, 254, 255 } },
    .{ .name = "sky_300", .bytes = .{ 116, 212, 255, 255 } },
    .{ .name = "sky_400", .bytes = .{ 0, 188, 255, 255 } },
    .{ .name = "sky_500", .bytes = .{ 0, 166, 244, 255 } },
    .{ .name = "sky_600", .bytes = .{ 0, 132, 209, 255 } },
    .{ .name = "sky_700", .bytes = .{ 0, 105, 168, 255 } },
    .{ .name = "sky_800", .bytes = .{ 0, 89, 138, 255 } },
    .{ .name = "sky_900", .bytes = .{ 2, 74, 112, 255 } },
    .{ .name = "sky_950", .bytes = .{ 5, 47, 74, 255 } },
    .{ .name = "blue_50", .bytes = .{ 239, 246, 255, 255 } },
    .{ .name = "blue_100", .bytes = .{ 219, 234, 254, 255 } },
    .{ .name = "blue_200", .bytes = .{ 190, 219, 255, 255 } },
    .{ .name = "blue_300", .bytes = .{ 142, 197, 255, 255 } },
    .{ .name = "blue_400", .bytes = .{ 81, 162, 255, 255 } },
    .{ .name = "blue_500", .bytes = .{ 43, 127, 255, 255 } },
    .{ .name = "blue_600", .bytes = .{ 21, 93, 252, 255 } },
    .{ .name = "blue_700", .bytes = .{ 20, 71, 230, 255 } },
    .{ .name = "blue_800", .bytes = .{ 25, 60, 184, 255 } },
    .{ .name = "blue_900", .bytes = .{ 28, 57, 142, 255 } },
    .{ .name = "blue_950", .bytes = .{ 22, 36, 86, 255 } },
    .{ .name = "indigo_50", .bytes = .{ 238, 242, 255, 255 } },
    .{ .name = "indigo_100", .bytes = .{ 224, 231, 255, 255 } },
    .{ .name = "indigo_200", .bytes = .{ 198, 210, 255, 255 } },
    .{ .name = "indigo_300", .bytes = .{ 163, 179, 255, 255 } },
    .{ .name = "indigo_400", .bytes = .{ 124, 134, 255, 255 } },
    .{ .name = "indigo_500", .bytes = .{ 97, 95, 255, 255 } },
    .{ .name = "indigo_600", .bytes = .{ 79, 57, 246, 255 } },
    .{ .name = "indigo_700", .bytes = .{ 67, 45, 215, 255 } },
    .{ .name = "indigo_800", .bytes = .{ 55, 42, 172, 255 } },
    .{ .name = "indigo_900", .bytes = .{ 49, 44, 133, 255 } },
    .{ .name = "indigo_950", .bytes = .{ 30, 26, 77, 255 } },
    .{ .name = "violet_50", .bytes = .{ 245, 243, 255, 255 } },
    .{ .name = "violet_100", .bytes = .{ 237, 233, 254, 255 } },
    .{ .name = "violet_200", .bytes = .{ 221, 214, 255, 255 } },
    .{ .name = "violet_300", .bytes = .{ 196, 180, 255, 255 } },
    .{ .name = "violet_400", .bytes = .{ 166, 132, 255, 255 } },
    .{ .name = "violet_500", .bytes = .{ 142, 81, 255, 255 } },
    .{ .name = "violet_600", .bytes = .{ 127, 34, 254, 255 } },
    .{ .name = "violet_700", .bytes = .{ 112, 8, 231, 255 } },
    .{ .name = "violet_800", .bytes = .{ 93, 14, 192, 255 } },
    .{ .name = "violet_900", .bytes = .{ 77, 23, 154, 255 } },
    .{ .name = "violet_950", .bytes = .{ 47, 13, 104, 255 } },
    .{ .name = "purple_50", .bytes = .{ 250, 245, 255, 255 } },
    .{ .name = "purple_100", .bytes = .{ 243, 232, 255, 255 } },
    .{ .name = "purple_200", .bytes = .{ 233, 212, 255, 255 } },
    .{ .name = "purple_300", .bytes = .{ 218, 178, 255, 255 } },
    .{ .name = "purple_400", .bytes = .{ 194, 122, 255, 255 } },
    .{ .name = "purple_500", .bytes = .{ 173, 70, 255, 255 } },
    .{ .name = "purple_600", .bytes = .{ 152, 16, 250, 255 } },
    .{ .name = "purple_700", .bytes = .{ 130, 0, 219, 255 } },
    .{ .name = "purple_800", .bytes = .{ 110, 17, 176, 255 } },
    .{ .name = "purple_900", .bytes = .{ 89, 22, 139, 255 } },
    .{ .name = "purple_950", .bytes = .{ 60, 3, 102, 255 } },
    .{ .name = "fuchsia_50", .bytes = .{ 253, 244, 255, 255 } },
    .{ .name = "fuchsia_100", .bytes = .{ 250, 232, 255, 255 } },
    .{ .name = "fuchsia_200", .bytes = .{ 246, 207, 255, 255 } },
    .{ .name = "fuchsia_300", .bytes = .{ 244, 168, 255, 255 } },
    .{ .name = "fuchsia_400", .bytes = .{ 237, 106, 255, 255 } },
    .{ .name = "fuchsia_500", .bytes = .{ 225, 42, 251, 255 } },
    .{ .name = "fuchsia_600", .bytes = .{ 200, 0, 222, 255 } },
    .{ .name = "fuchsia_700", .bytes = .{ 168, 0, 183, 255 } },
    .{ .name = "fuchsia_800", .bytes = .{ 138, 1, 148, 255 } },
    .{ .name = "fuchsia_900", .bytes = .{ 114, 19, 120, 255 } },
    .{ .name = "fuchsia_950", .bytes = .{ 75, 0, 79, 255 } },
    .{ .name = "pink_50", .bytes = .{ 253, 242, 248, 255 } },
    .{ .name = "pink_100", .bytes = .{ 252, 231, 243, 255 } },
    .{ .name = "pink_200", .bytes = .{ 252, 206, 232, 255 } },
    .{ .name = "pink_300", .bytes = .{ 253, 165, 213, 255 } },
    .{ .name = "pink_400", .bytes = .{ 251, 100, 182, 255 } },
    .{ .name = "pink_500", .bytes = .{ 246, 51, 154, 255 } },
    .{ .name = "pink_600", .bytes = .{ 230, 0, 118, 255 } },
    .{ .name = "pink_700", .bytes = .{ 198, 0, 92, 255 } },
    .{ .name = "pink_800", .bytes = .{ 163, 0, 76, 255 } },
    .{ .name = "pink_900", .bytes = .{ 134, 16, 67, 255 } },
    .{ .name = "pink_950", .bytes = .{ 81, 4, 36, 255 } },
    .{ .name = "rose_50", .bytes = .{ 255, 241, 242, 255 } },
    .{ .name = "rose_100", .bytes = .{ 255, 228, 230, 255 } },
    .{ .name = "rose_200", .bytes = .{ 255, 204, 211, 255 } },
    .{ .name = "rose_300", .bytes = .{ 255, 161, 173, 255 } },
    .{ .name = "rose_400", .bytes = .{ 255, 99, 126, 255 } },
    .{ .name = "rose_500", .bytes = .{ 255, 32, 86, 255 } },
    .{ .name = "rose_600", .bytes = .{ 236, 0, 63, 255 } },
    .{ .name = "rose_700", .bytes = .{ 199, 0, 54, 255 } },
    .{ .name = "rose_800", .bytes = .{ 165, 0, 54, 255 } },
    .{ .name = "rose_900", .bytes = .{ 139, 8, 54, 255 } },
    .{ .name = "rose_950", .bytes = .{ 77, 2, 24, 255 } },
    .{ .name = "slate_50", .bytes = .{ 248, 250, 252, 255 } },
    .{ .name = "slate_100", .bytes = .{ 241, 245, 249, 255 } },
    .{ .name = "slate_200", .bytes = .{ 226, 232, 240, 255 } },
    .{ .name = "slate_300", .bytes = .{ 202, 213, 226, 255 } },
    .{ .name = "slate_400", .bytes = .{ 144, 161, 185, 255 } },
    .{ .name = "slate_500", .bytes = .{ 98, 116, 142, 255 } },
    .{ .name = "slate_600", .bytes = .{ 69, 85, 108, 255 } },
    .{ .name = "slate_700", .bytes = .{ 49, 65, 88, 255 } },
    .{ .name = "slate_800", .bytes = .{ 29, 41, 61, 255 } },
    .{ .name = "slate_900", .bytes = .{ 15, 23, 43, 255 } },
    .{ .name = "slate_950", .bytes = .{ 2, 6, 24, 255 } },
    .{ .name = "gray_50", .bytes = .{ 249, 250, 251, 255 } },
    .{ .name = "gray_100", .bytes = .{ 243, 244, 246, 255 } },
    .{ .name = "gray_200", .bytes = .{ 229, 231, 235, 255 } },
    .{ .name = "gray_300", .bytes = .{ 209, 213, 220, 255 } },
    .{ .name = "gray_400", .bytes = .{ 153, 161, 175, 255 } },
    .{ .name = "gray_500", .bytes = .{ 106, 114, 130, 255 } },
    .{ .name = "gray_600", .bytes = .{ 74, 85, 101, 255 } },
    .{ .name = "gray_700", .bytes = .{ 54, 65, 83, 255 } },
    .{ .name = "gray_800", .bytes = .{ 30, 41, 57, 255 } },
    .{ .name = "gray_900", .bytes = .{ 16, 24, 40, 255 } },
    .{ .name = "gray_950", .bytes = .{ 3, 7, 18, 255 } },
    .{ .name = "zinc_50", .bytes = .{ 250, 250, 250, 255 } },
    .{ .name = "zinc_100", .bytes = .{ 244, 244, 245, 255 } },
    .{ .name = "zinc_200", .bytes = .{ 228, 228, 231, 255 } },
    .{ .name = "zinc_300", .bytes = .{ 212, 212, 216, 255 } },
    .{ .name = "zinc_400", .bytes = .{ 159, 159, 169, 255 } },
    .{ .name = "zinc_500", .bytes = .{ 113, 113, 123, 255 } },
    .{ .name = "zinc_600", .bytes = .{ 82, 82, 92, 255 } },
    .{ .name = "zinc_700", .bytes = .{ 63, 63, 70, 255 } },
    .{ .name = "zinc_800", .bytes = .{ 39, 39, 42, 255 } },
    .{ .name = "zinc_900", .bytes = .{ 24, 24, 27, 255 } },
    .{ .name = "zinc_950", .bytes = .{ 9, 9, 11, 255 } },
    .{ .name = "neutral_50", .bytes = .{ 250, 250, 250, 255 } },
    .{ .name = "neutral_100", .bytes = .{ 245, 245, 245, 255 } },
    .{ .name = "neutral_200", .bytes = .{ 229, 229, 229, 255 } },
    .{ .name = "neutral_300", .bytes = .{ 212, 212, 212, 255 } },
    .{ .name = "neutral_400", .bytes = .{ 161, 161, 161, 255 } },
    .{ .name = "neutral_500", .bytes = .{ 115, 115, 115, 255 } },
    .{ .name = "neutral_600", .bytes = .{ 82, 82, 82, 255 } },
    .{ .name = "neutral_700", .bytes = .{ 64, 64, 64, 255 } },
    .{ .name = "neutral_800", .bytes = .{ 38, 38, 38, 255 } },
    .{ .name = "neutral_900", .bytes = .{ 23, 23, 23, 255 } },
    .{ .name = "neutral_950", .bytes = .{ 10, 10, 10, 255 } },
    .{ .name = "stone_50", .bytes = .{ 250, 250, 249, 255 } },
    .{ .name = "stone_100", .bytes = .{ 245, 245, 244, 255 } },
    .{ .name = "stone_200", .bytes = .{ 231, 229, 228, 255 } },
    .{ .name = "stone_300", .bytes = .{ 214, 211, 209, 255 } },
    .{ .name = "stone_400", .bytes = .{ 166, 160, 155, 255 } },
    .{ .name = "stone_500", .bytes = .{ 121, 113, 107, 255 } },
    .{ .name = "stone_600", .bytes = .{ 87, 83, 77, 255 } },
    .{ .name = "stone_700", .bytes = .{ 68, 64, 59, 255 } },
    .{ .name = "stone_800", .bytes = .{ 41, 37, 36, 255 } },
    .{ .name = "stone_900", .bytes = .{ 28, 25, 23, 255 } },
    .{ .name = "stone_950", .bytes = .{ 12, 10, 9, 255 } },
    .{ .name = "taupe_50", .bytes = .{ 251, 250, 249, 255 } },
    .{ .name = "taupe_100", .bytes = .{ 243, 241, 241, 255 } },
    .{ .name = "taupe_200", .bytes = .{ 232, 228, 227, 255 } },
    .{ .name = "taupe_300", .bytes = .{ 216, 210, 208, 255 } },
    .{ .name = "taupe_400", .bytes = .{ 171, 160, 156, 255 } },
    .{ .name = "taupe_500", .bytes = .{ 124, 109, 103, 255 } },
    .{ .name = "taupe_600", .bytes = .{ 91, 79, 75, 255 } },
    .{ .name = "taupe_700", .bytes = .{ 71, 60, 57, 255 } },
    .{ .name = "taupe_800", .bytes = .{ 43, 36, 34, 255 } },
    .{ .name = "taupe_900", .bytes = .{ 29, 24, 22, 255 } },
    .{ .name = "taupe_950", .bytes = .{ 12, 10, 9, 255 } },
    .{ .name = "mauve_50", .bytes = .{ 250, 250, 250, 255 } },
    .{ .name = "mauve_100", .bytes = .{ 243, 241, 243, 255 } },
    .{ .name = "mauve_200", .bytes = .{ 231, 228, 231, 255 } },
    .{ .name = "mauve_300", .bytes = .{ 215, 208, 215, 255 } },
    .{ .name = "mauve_400", .bytes = .{ 168, 158, 169, 255 } },
    .{ .name = "mauve_500", .bytes = .{ 121, 105, 123, 255 } },
    .{ .name = "mauve_600", .bytes = .{ 89, 76, 91, 255 } },
    .{ .name = "mauve_700", .bytes = .{ 70, 57, 71, 255 } },
    .{ .name = "mauve_800", .bytes = .{ 42, 33, 44, 255 } },
    .{ .name = "mauve_900", .bytes = .{ 29, 22, 30, 255 } },
    .{ .name = "mauve_950", .bytes = .{ 12, 9, 12, 255 } },
    .{ .name = "mist_50", .bytes = .{ 249, 251, 251, 255 } },
    .{ .name = "mist_100", .bytes = .{ 241, 243, 243, 255 } },
    .{ .name = "mist_200", .bytes = .{ 227, 231, 232, 255 } },
    .{ .name = "mist_300", .bytes = .{ 208, 214, 216, 255 } },
    .{ .name = "mist_400", .bytes = .{ 156, 168, 171, 255 } },
    .{ .name = "mist_500", .bytes = .{ 103, 120, 124, 255 } },
    .{ .name = "mist_600", .bytes = .{ 75, 88, 91, 255 } },
    .{ .name = "mist_700", .bytes = .{ 57, 68, 71, 255 } },
    .{ .name = "mist_800", .bytes = .{ 34, 41, 43, 255 } },
    .{ .name = "mist_900", .bytes = .{ 22, 27, 29, 255 } },
    .{ .name = "mist_950", .bytes = .{ 9, 11, 12, 255 } },
    .{ .name = "olive_50", .bytes = .{ 251, 251, 249, 255 } },
    .{ .name = "olive_100", .bytes = .{ 244, 244, 240, 255 } },
    .{ .name = "olive_200", .bytes = .{ 232, 232, 227, 255 } },
    .{ .name = "olive_300", .bytes = .{ 216, 216, 208, 255 } },
    .{ .name = "olive_400", .bytes = .{ 171, 171, 156, 255 } },
    .{ .name = "olive_500", .bytes = .{ 124, 124, 103, 255 } },
    .{ .name = "olive_600", .bytes = .{ 91, 91, 75, 255 } },
    .{ .name = "olive_700", .bytes = .{ 71, 71, 57, 255 } },
    .{ .name = "olive_800", .bytes = .{ 43, 43, 34, 255 } },
    .{ .name = "olive_900", .bytes = .{ 29, 29, 22, 255 } },
    .{ .name = "olive_950", .bytes = .{ 12, 12, 9, 255 } },
};

pub fn inSource(
    allocator: Allocator,
    source: []const u8,
    encoding: Types.PositionEncoding,
) ![]Types.ColorInformation {
    const tokens = try tokenize(allocator, source);
    defer allocator.free(tokens);

    var colors: std.ArrayList(Types.ColorInformation) = .empty;
    defer colors.deinit(allocator);

    var index: usize = 0;
    while (index < tokens.len) : (index += 1) {
        const parsed = try colorAt(allocator, tokens, index) orelse continue;
        const start = Protocol.positionAtByteOffset(source, tokens[index].start, encoding) orelse continue;
        const end = Protocol.positionAtByteOffset(source, parsed.end, encoding) orelse continue;
        try colors.append(allocator, .{
            .range = .{ .start = start, .end = end },
            .color = parsed.color,
        });
        index = parsed.last_token;
    }
    return colors.toOwnedSlice(allocator);
}

const ParsedColor = struct {
    color: Types.Color,
    end: usize,
    last_token: usize,
};

fn colorAt(allocator: Allocator, tokens: []const Token, start: usize) !?ParsedColor {
    if (!isToken(tokens, start, .identifier, "Color") or
        !isToken(tokens, start + 1, .dot, ".") or
        start + 3 >= tokens.len or tokens[start + 2].tag != .identifier or
        tokens[start + 3].tag != .left_parenthesis)
    {
        return null;
    }

    const name = tokens[start + 2].lexeme;
    if (namedColor(name)) |named| {
        if (start + 4 >= tokens.len or tokens[start + 4].tag != .right_parenthesis) return null;
        return .{
            .color = named,
            .end = tokens[start + 4].end,
            .last_token = start + 4,
        };
    }

    const expected: usize = if (std.mem.eql(u8, name, "rgb"))
        3
    else if (std.mem.eql(u8, name, "rgba"))
        4
    else if (std.mem.eql(u8, name, "bytes"))
        0
    else
        return null;

    var values: [4]f64 = .{ 0.0, 0.0, 0.0, 1.0 };
    var cursor = start + 4;
    var count: usize = 0;
    while (cursor < tokens.len and tokens[cursor].tag != .right_parenthesis) {
        if (count == values.len) return null;
        const value = try numericValue(allocator, tokens[cursor]) orelse return null;
        values[count] = value;
        count += 1;
        cursor += 1;
        if (cursor >= tokens.len or tokens[cursor].tag == .right_parenthesis) break;
        if (tokens[cursor].tag != .comma) return null;
        cursor += 1;
    }
    if (cursor >= tokens.len or tokens[cursor].tag != .right_parenthesis) return null;

    if (std.mem.eql(u8, name, "bytes")) {
        if (count != 3 and count != 4) return null;
        if (count == 3) values[3] = 255.0;
        for (values[0..count]) |value| {
            if (value < 0.0 or value > 255.0 or @floor(value) != value) return null;
        }
        for (&values) |*value| value.* /= 255.0;
    } else if (count != expected) {
        return null;
    }

    for (values) |value| {
        if (!std.math.isFinite(value) or value < 0.0 or value > 1.0) return null;
    }
    return .{
        .color = color(values),
        .end = tokens[cursor].end,
        .last_token = cursor,
    };
}

fn tokenize(allocator: Allocator, source: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    var lexer = LexerModule.Lexer.init(source);
    var attempts: usize = 0;
    while (attempts <= source.len * 2 + 1) : (attempts += 1) {
        const token = lexer.next() catch continue;
        try tokens.append(allocator, token);
        if (token.tag == .end) break;
    }
    return tokens.toOwnedSlice(allocator);
}

fn numericValue(allocator: Allocator, token: Token) !?f64 {
    if (token.tag != .integer and token.tag != .floating) return null;
    const normalized = try removeSeparators(allocator, token.lexeme);
    defer allocator.free(normalized);
    if (token.tag == .floating) return std.fmt.parseFloat(f64, normalized) catch null;

    const base: u8 = if (normalized.len > 2 and normalized[0] == '0') switch (normalized[1]) {
        'b', 'B' => 2,
        'o', 'O' => 8,
        'x', 'X' => 16,
        else => 10,
    } else 10;
    const digits = if (base == 10) normalized else normalized[2..];
    const magnitude = std.fmt.parseInt(u64, digits, base) catch return null;
    return @floatFromInt(magnitude);
}

fn removeSeparators(allocator: Allocator, text: []const u8) ![]u8 {
    const normalized = try allocator.alloc(u8, text.len);
    var length: usize = 0;
    for (text) |character| {
        if (character == '_') continue;
        normalized[length] = character;
        length += 1;
    }
    return allocator.realloc(normalized, length);
}

fn namedColor(name: []const u8) ?Types.Color {
    for (named_colors) |entry| {
        if (!std.mem.eql(u8, entry.name, name)) continue;
        return .{
            .red = @as(f64, @floatFromInt(entry.bytes[0])) / 255.0,
            .green = @as(f64, @floatFromInt(entry.bytes[1])) / 255.0,
            .blue = @as(f64, @floatFromInt(entry.bytes[2])) / 255.0,
            .alpha = @as(f64, @floatFromInt(entry.bytes[3])) / 255.0,
        };
    }
    return null;
}

fn color(values: [4]f64) Types.Color {
    return .{
        .red = values[0],
        .green = values[1],
        .blue = values[2],
        .alpha = values[3],
    };
}

fn isToken(
    tokens: []const Token,
    index: usize,
    tag: LexerModule.TokenTag,
    lexeme: []const u8,
) bool {
    return index < tokens.len and tokens[index].tag == tag and
        std.mem.eql(u8, tokens[index].lexeme, lexeme);
}

test "find literal and named GFX colors without reading comments or strings" {
    const source =
        \\let byte_color = Color.bytes(255, 32, 86)
        \\let rgb_color = Color.rgb(0.2, 0.4, 0.8)
        \\let rgba_color = Color.rgba(0.2, 0.4, 0.8, 0.5)
        \\let named_color = Color.blue_500()
        \\let gizmos_color = Color.gizmos()
        \\// Color.red_500()
        \\let text = "Color.green_500()"
    ;
    const colors = try inSource(std.testing.allocator, source, .utf16);
    defer std.testing.allocator.free(colors);
    try std.testing.expectEqual(@as(usize, 5), colors.len);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), colors[0].color.red, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 32.0 / 255.0), colors[0].color.green, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), colors[0].color.alpha, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), colors[1].color.blue, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), colors[2].color.alpha, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 43.0 / 255.0), colors[3].color.red, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 214.0 / 255.0), colors[4].color.green, 0.000001);
    try std.testing.expectEqual(@as(usize, 0), colors[0].range.start.line);
    try std.testing.expectEqual(@as(usize, 17), colors[0].range.start.character);
}

test "use the negotiated position encoding and reject nonliteral or invalid colors" {
    const source =
        \\let prefix = "😀"; Color.red_500()
        \\let dynamic = Color.rgb(red, 0.0, 0.0)
        \\let outside = Color.rgba(2.0, 0.0, 0.0, 1.0)
        \\let invalid_byte = Color.bytes(256, 0, 0)
    ;
    const utf16 = try inSource(std.testing.allocator, source, .utf16);
    defer std.testing.allocator.free(utf16);
    const utf8 = try inSource(std.testing.allocator, source, .utf8);
    defer std.testing.allocator.free(utf8);
    try std.testing.expectEqual(@as(usize, 1), utf16.len);
    try std.testing.expectEqual(@as(usize, 1), utf8.len);
    try std.testing.expectEqual(@as(usize, 19), utf16[0].range.start.character);
    try std.testing.expectEqual(@as(usize, 21), utf8[0].range.start.character);
}
