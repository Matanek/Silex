// Run from the common workspace root, never from a package or the compiler checkout.
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { cpus, platform, release } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { performance } from "node:perf_hooks";

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const source = join(repository, "Tests/Native/HeapAllocation.sx");
const expected = "256000\n";

export function checked(result, command) {
    if (result.error || result.signal || result.status !== 0) {
        throw new Error(`${command} failed (${result.signal ?? result.status}): ${result.error ?? result.stderr}\n${result.stdout ?? ""}`);
    }
    return result.stdout.replaceAll("\r\n", "\n");
}

function run(binary, args = [], timeout = 30_000) {
    return checked(spawnSync(binary, args, { encoding: "utf8", timeout }), [binary, ...args].join(" "));
}

export function median(values) {
    const sorted = [...values].sort((a, b) => a - b);
    if (!sorted.length) throw new Error("Empty timing series");
    const middle = Math.floor(sorted.length / 2);
    return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function hash(path) {
    return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function sample(binary) {
    const start = performance.now();
    const output = run(binary);
    const elapsed = performance.now() - start;
    if (output !== expected) throw new Error(`Unexpected allocation checksum: ${JSON.stringify(output)}`);
    return elapsed;
}

export function qualify(candidate, outputDirectory, target, baseline) {
    if (realpathSync(process.cwd()) !== realpathSync(dirname(repository))) {
        throw new Error("Invoke this qualification from the common workspace root above Silex");
    }
    if (!/^(macos|linux|windows)-(arm64|x64)$/.test(target)) throw new Error("Unknown target");
    const output = resolve(outputDirectory);
    mkdirSync(output, { recursive: true });
    const configurations = {};
    for (const [name, path] of Object.entries({ candidate, ...(baseline ? { baseline } : {}) })) {
        const compiler = realpathSync(path);
        const targets = run(compiler, ["targets"]).split("\n");
        if (!targets.includes(`${target} (host)`)) throw new Error(`Compiler is not native to ${target}`);
        const information = { compiler, sha256: hash(compiler), version: run(compiler, ["--version"]).trim(), binaries: {}, correctness: {} };
        console.log(`${name}: heap regression tests (${target})`);
        information.correctness.heap_tests = run(compiler, ["test", source, "--backend", "native", "--nocache"], 600_000);
        console.log(`${name}: ownership and portability tests (${target})`);
        information.correctness.portability_tests = run(compiler, ["test", join(repository, "Tests/Native/NativePortability.sx"), "--backend", "native", "--nocache"], 600_000);
        for (const mode of ["debug", "release"]) {
            // Correctness and execution mode are independent from timing.
            console.log(`${name}: compile and verify ${mode} (${target})`);
            const binary = join(output, `${name}-${mode}${platform() === "win32" ? ".exe" : ""}`);
            run(compiler, ["compile", source, "--backend", "native", `--${mode}`, "--nocache", "-o", binary], 600_000);
            sample(binary);
            information.binaries[mode] = { path: binary, sha256: hash(binary) };
        }
        configurations[name] = information;
    }
    // Warm each executable, then balance order without building during measurements.
    for (const config of Object.values(configurations)) sample(config.binaries.release.path);
    const samples = [];
    for (let round = 0; round < 12; round++) {
        const order = Object.keys(configurations);
        if (round % 2) order.reverse();
        for (const name of order) {
            samples.push({ round, configuration: name, elapsed_ms: sample(configurations[name].binaries.release.path) });
        }
    }
    const summary = {};
    for (const name of Object.keys(configurations)) {
        const times = samples.filter(sample => sample.configuration === name).map(sample => sample.elapsed_ms);
        summary[name] = { median_ms: median(times), min_ms: Math.min(...times), max_ms: Math.max(...times) };
    }
    const report = {
        schema: 1, target, timestamp: new Date().toISOString(),
        environment: { os: platform(), release: release(), cpu: cpus()[0]?.model },
        source: { path: source, sha256: hash(source), expected_stdout: expected },
        configurations, samples, summary,
        qualification_commit: process.env.GITHUB_SHA ?? null,
        published_compiler_version: process.env.RELEASE_VERSION ?? null,
        limitations: "Fixed-work allocation diagnostic, including process startup. No cross-host comparison, parity claim or automatic speedup verdict. Baseline and candidate must differ only in the intended compiler change.",
    };
    writeFileSync(join(output, "heap-qualification.json"), JSON.stringify(report, null, 2) + "\n");
    console.log(JSON.stringify({ target, summary, report: join(output, "heap-qualification.json") }, null, 2));
    return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    try {
        if (process.argv.length < 5 || process.argv.length > 6) {
            throw new Error("Usage: node QualifyHeap.mjs CANDIDATE OUTPUT_DIRECTORY TARGET [BASELINE]");
        }
        qualify(...process.argv.slice(2));
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
