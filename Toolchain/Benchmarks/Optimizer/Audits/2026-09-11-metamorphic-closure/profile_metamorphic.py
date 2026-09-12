from pathlib import Path
import subprocess
p=Path('MetamorphicProfileProbe.zig');assert not p.exists()
p.write_text('''const std = @import("std");
const Differential = @import("Tools/OptimizerOracle/Differential.zig");
const Metamorphic = @import("Tools/OptimizerOracle/Metamorphic.zig");
const Stats = @import("Tools/OptimizerOracle/IrStats.zig");
test "profile reachable metamorphic pairs" {
 var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
 defer arena.deinit(); const allocator = arena.allocator();
 for (Metamorphic.pairs) |pair| {
  const left = try Differential.verify(allocator, pair.left);
  const right = try Differential.verify(allocator, pair.right);
  const l = try Stats.profileReachable(allocator,left.optimized_ir);
  const r = try Stats.profileReachable(allocator,right.optimized_ir);
  std.debug.print("{s}: instructions {d}/{d}, blocks {d}/{d}, calls {d}/{d}\\n", .{pair.id,l.counts.instructions,r.counts.instructions,l.counts.blocks,r.counts.blocks,l.calls,r.calls});
 }
}
''')
try:
 with open('/private/tmp/silex-part02-evidence/metamorphic-reachable-before.log','w') as log:
  r=subprocess.run(['zig','test','-OReleaseFast','--test-filter','profile reachable metamorphic pairs','--dep','silex_optimizer_api','-Mroot=MetamorphicProfileProbe.zig','--dep','build_options','-Msilex_optimizer_api=Sources/OptimizerOracleApi.zig','-Mbuild_options=.zig-cache/c/c2b944db16cb19947f560e417ce671f1/options.zig'],stdout=log,stderr=subprocess.STDOUT)
finally:p.unlink()
raise SystemExit(r.returncode)
