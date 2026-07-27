const Source = @import("../Source.zig");
const Inheritance = @import("Inheritance.zig");

pub fn memberVisible(self: anytype, structure_index: usize, member: anytype, position: Source.Position) bool {
    if (member.is_public) return true;
    if (member.is_internal) return position.file == member.position.file;
    const context = self.member_context orelse return false;
    if (context == structure_index) return true;
    return member.is_protected and Inheritance.isDescendant(self, context, structure_index);
}

pub fn name(member: anytype) []const u8 {
    if (member.is_public) return "public";
    if (member.is_internal) return "internal";
    if (member.is_protected) return "protected";
    return "private";
}
