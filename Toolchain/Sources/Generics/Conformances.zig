const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

pub fn conforms(self: anytype, type_value: Ast.Type, protocol: Ast.Type, position: Source.Position, depth: usize) bool {
    if (depth > self.structures.items.len + 1) return false;
    const structure = self.structureForType(type_value) orelse self.sourceStructureForType(type_value) orelse return false;
    if (structure.base) |base| {
        if (base == protocol) return true;
        if (conforms(self, base, protocol, position, depth + 1)) return true;
    }
    for (structure.conformances) |relation| if (relation == protocol) return true;
    if (depth == 0) for (structure.extension_conformances) |relation| {
        if (relation.protocol != protocol) continue;
        for (relation.visible_files) |file| if (file == position.file) return true;
    };
    return false;
}
