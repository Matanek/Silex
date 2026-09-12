from pathlib import Path
import subprocess
root=Path('/private/tmp/silex-part02-evidence')
probe=Path('LongOracleProbe.zig'); a=Path('LongOracleRepeated.txt'); b=Path('LongOracleShared.txt')
assert not any(p.exists() for p in (probe,a,b))
a.write_bytes((root/'IntegrationRepeatedLong.sx').read_bytes()); b.write_bytes((root/'IntegrationSharedLong.sx').read_bytes())
probe.write_text('''const std = @import("std");
const Silex = @import("silex_optimizer_api");
const Llvm = @import("Tools/OptimizerOracle/Llvm.zig");
test "emit long integration oracle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const inputs = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "repeated", .source = @embedFile("LongOracleRepeated.txt") },
        .{ .name = "shared", .source = @embedFile("LongOracleShared.txt") },
    };
    for (inputs) |input| {
        var frontend = Silex.Frontend.init(allocator);
        const compilation = try frontend.compile(input.source);
        const optimized = try Silex.ReleaseOptimizer.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
        for ([_][]const u8{ "raw", "silex" }, [_]Silex.Ir.Program{ compilation.ir, optimized }) |mode, program| {
            const path = try std.fmt.allocPrint(allocator, "/private/tmp/silex-part02-evidence/integration-long-{s}-{s}.ll", .{ input.name, mode });
            try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = path, .data = try Llvm.emit(allocator, program) });
        }
    }
}
''')
try:
 with open(root/'integration-long-llvm-emission.log','w') as log:
  result=subprocess.run(['zig','test','-OReleaseFast','--test-filter','emit long integration oracle','--dep','silex_optimizer_api','-Mroot=LongOracleProbe.zig','--dep','build_options','-Msilex_optimizer_api=Sources/OptimizerOracleApi.zig','-Mbuild_options=.zig-cache/c/c2b944db16cb19947f560e417ce671f1/options.zig'],stdout=log,stderr=subprocess.STDOUT)
finally:
 for p in (probe,a,b): p.unlink()
raise SystemExit(result.returncode)
