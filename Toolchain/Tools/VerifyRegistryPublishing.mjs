// Portable client proof against an independent in-memory protocol fixture.
// Not a server-security, OAuth, provider-ABI or deployed-service qualification.
import assert from 'node:assert/strict';
import { execFile, spawn } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { gunzipSync } from 'node:zlib';
import { access, mkdir, mkdtemp, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const group = dirname(repository), cli = process.argv[2];
assert(cli && isAbsolute(cli));
assert.equal(process.cwd(), group, 'Run from the workspace group above Silex, never from a package.');
const platform = { darwin: 'macos', linux: 'linux', win32: 'windows' }[process.platform];
assert(platform && ['arm64', 'x64'].includes(process.arch));
const target = `${platform}-${process.arch}`;
if (process.platform !== 'win32') process.umask(0o077);
await mkdir('TestState/registry-publishing', { recursive: true });
const root = await mkdtemp(resolve('TestState/registry-publishing/run-'));
const children = new Set(), publications = new Map(), objects = new Map(), expectations = new Map();
const token = randomBytes(32).toString('hex'), attempt = randomBytes(16).toString('hex');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
const digest = value => sha(JSON.stringify(canonical(value)));
const missing = path => assert.rejects(access(path), { code: 'ENOENT' });
let loginTicket, revoked = false, disconnect = true, dropped = false, resumed = false;
let corrupt = '', fault, log = '', checks = 0, publicReads = 0, artifactUploads = 0;
const pass = text => console.log(`ok ${++checks} - ${text}`);
const execFileAsync = promisify(execFile);
async function reportNativeProcesses(command) {
  try {
    const { stdout } = await execFileAsync('pwsh', ['-NoProfile', '-NonInteractive', '-Command',
      'Get-Process -Name silex,zig -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,CPU | ConvertTo-Json -Compress'],
      { timeout: 10000 });
    console.log(`probe windows-arm64 ${command} processes: ${stdout.trim() || 'none'}`);
  } catch (error) { console.log(`probe windows-arm64 ${command} process inspection failed: ${error.code || error.message}`); }
}
const artifact = Buffer.alloc(10000, 0x5a), artifactDigest = sha(artifact);
const message = 'portable registry resource';

function verifyArchive(publication) {
  const bytes = gunzipSync(objects.get(publication.descriptor.source.sha256));
  const expected = expectations.get(publication.version), seen = new Set();
  let offset = 0;
  const text = buffer => buffer.toString('utf8').replace(/\0.*$/s, '');
  while (bytes.subarray(offset, offset + 512).some(byte => byte !== 0)) {
    const header = bytes.subarray(offset, offset + 512);
    assert.equal(header.length, 512); assert.equal(text(header.subarray(257, 263)), 'ustar');
    assert([0, 48].includes(header[156]));
    const checksum = [...header].reduce((sum, byte, index) => sum + (index >= 148 && index < 156 ? 32 : byte), 0);
    assert.equal(parseInt(text(header.subarray(148, 156)), 8), checksum);
    const prefix = text(header.subarray(345, 500)), name = text(header.subarray(0, 100));
    const path = prefix ? `${prefix}/${name}` : name;
    assert(expected.has(path) && !seen.has(path), `Unexpected archive member: ${path}`);
    const size = parseInt(text(header.subarray(124, 136)), 8);
    const content = bytes.subarray(offset + 512, offset + 512 + size);
    assert.deepEqual(content, expected.get(path)); seen.add(path);
    offset += 512 + Math.ceil(size / 512) * 512;
  }
  assert.deepEqual([...seen].sort(), [...expected.keys()].sort());
  assert(bytes.length >= offset + 1024 && !bytes.subarray(offset).some(byte => byte !== 0));
}
function status(publication) {
  return { id: publication.id, state: publication.published ? 'published' : 'receiving',
    publication_sha256: publication.digest,
    objects: [publication.descriptor.source, ...publication.descriptor.artifacts].map(blob => {
      const offset = objects.get(blob.sha256)?.length ?? 0;
      if (offset > 0 && offset < blob.size) resumed = true;
      return { sha256: blob.sha256, size: blob.size, offset, available: offset === blob.size };
    }) };
}
const server = createServer((request, response) => {
  void serve(request, response).catch(error => {
    fault = error; if (!response.headersSent) response.writeHead(500); response.end();
  });
});
async function serve(request, response) {
  function send(code, body) { response.writeHead(code, { 'Content-Type': 'application/json' }); response.end(JSON.stringify(body)); }
  const authorization = request.headers.authorization;
  if (request.url === '/v2/session') {
    if (authorization !== `Bearer ${token}` || revoked) return send(401, {});
    if (request.method === 'DELETE') { revoked = true; return send(200, { revoked: true }); }
    return send(200, { github_id: '1001', login: 'fixture-user', expires_at: Math.floor(Date.now() / 1000) + 3600 });
  }
  if (request.url.startsWith('/v2/logins')) {
    assert.equal(request.method, 'POST'); assert.match(authorization, /^Login [a-f0-9]{64}$/);
    if (request.url === '/v2/logins') {
      loginTicket = authorization;
      return send(200, { id: attempt, state: 'pending', user_code: 'TEST-1234',
        verification_uri: 'https://github.com/login/device', expires_at: Math.floor(Date.now() / 1000) + 900, retry_after: 1 });
    }
    assert.equal(request.url, `/v2/logins/${attempt}`); assert.equal(authorization, loginTicket);
    return send(200, { id: attempt, state: 'authorized', token, github_id: '1001', login: 'fixture-user',
      expires_at: Math.floor(Date.now() / 1000) + 3600 });
  }
  if (request.url.startsWith('/v2/publications')) {
    assert.equal(authorization, `Bearer ${token}`); assert(!revoked);
    let payload = Buffer.alloc(0);
    for await (const chunk of request) { payload = Buffer.concat([payload, chunk]); assert(payload.length < 2 ** 20); }
    if (request.url === '/v2/publications') {
      assert.equal(request.method, 'POST');
      const descriptor = JSON.parse(payload), manifest = JSON.parse(descriptor.manifest), version = manifest.version;
      assert.equal(manifest.name, 'RegistryProbe'); assert.equal(descriptor.schema, 1);
      const expected = expectations.get(version); assert(expected);
      assert.equal(descriptor.manifest, expected.get('Package.json').toString());
      assert.deepEqual(descriptor.files.map(file => file.path).sort(), [...expected.keys()].sort());
      for (const file of descriptor.files) {
        assert.equal(file.sha256, sha(expected.get(file.path))); assert.equal(file.size, expected.get(file.path).length);
      }
      assert.deepEqual(descriptor.artifacts, [{ name: 'Fixture', path: `Boundary/${target}/fixture.a`,
        sha256: artifactDigest, size: artifact.length, target }]);
      const hash = digest(descriptor);
      let publication = publications.get(version);
      if (publication) assert.equal(publication.digest, hash);
      else {
        publication = { id: randomBytes(16).toString('hex'), version, digest: hash, descriptor, published: false };
        publications.set(version, publication);
      }
      return send(200, status(publication));
    }
    const match = request.url.match(/^\/v2\/publications\/([a-f0-9]{32})\/(?:objects\/([a-f0-9]{64})|(finalize))$/);
    assert(match);
    const publication = [...publications.values()].find(item => item.id === match[1]); assert(publication);
    if (match[3]) {
      assert.equal(request.method, 'POST');
      for (const blob of [publication.descriptor.source, ...publication.descriptor.artifacts]) {
        assert.equal(objects.get(blob.sha256)?.length, blob.size); assert.equal(sha(objects.get(blob.sha256)), blob.sha256);
      }
      verifyArchive(publication); publication.published = true; return send(200, status(publication));
    }
    assert.equal(request.method, 'PATCH');
    const previous = objects.get(match[2]) ?? Buffer.alloc(0);
    assert.equal(Number(request.headers['upload-offset']), previous.length);
    assert(payload.length > 0 && payload.length <= 4096);
    objects.set(match[2], Buffer.concat([previous, payload]));
    if (match[2] === artifactDigest) {
      artifactUploads++;
      if (disconnect) { disconnect = false; dropped = true; request.socket.destroy(); return; }
    }
    return send(200, { offset: previous.length + payload.length });
  }
  assert.equal(request.method, 'GET'); assert.equal(authorization, undefined, 'Public reads must not carry a credential.');
  publicReads++;
  if (request.url === '/v2/packages/RegistryProbe') return send(200, { name: 'RegistryProbe',
    versions: [...publications.values()].filter(item => item.published).map(item => ({ version: item.version, digest: item.digest })) });
  const match = request.url.match(/^\/v2\/packages\/RegistryProbe\/versions\/(1\.[01]\.0)(\/source|\/artifacts\/[^/]+\/Fixture)?$/);
  assert(match, `Unexpected public path: ${request.url}`);
  const publication = publications.get(match[1]); assert(publication?.published);
  if (!match[2]) return send(200, { descriptor: publication.descriptor, publication_sha256: publication.digest });
  const source = match[2] === '/source';
  if (!source) assert.equal(match[2], `/artifacts/${target}/Fixture`);
  let bytes = objects.get(source ? publication.descriptor.source.sha256 : artifactDigest);
  if (corrupt === (source ? 'source' : 'artifact')) bytes = Buffer.alloc(bytes.length, 0x3f);
  response.writeHead(200, { 'Content-Type': 'application/octet-stream', 'Content-Length': bytes.length }); response.end(bytes);
}
await new Promise((yes, no) => { server.once('error', no); server.listen(0, '127.0.0.1', yes); });
const url = `http://127.0.0.1:${server.address().port}`;
async function localRoot(name) { const path = resolve(root, name); await mkdir(path, { mode: 0o700 }); return path; }
function run(path, args, executable = cli) {
  return new Promise((yes, no) => {
    const child = spawn(executable, args, { cwd: group, env: { ...process.env,
      SILEX_DATA_ROOT: resolve(path, 'data'), SILEX_REGISTRY_TEST_URL: url,
      SILEX_REGISTRY_TEST_ROOT: path, SILEX_REGISTRY_V2: 'test',
      SILEX_REGISTRY: 'https://github.invalid/v1/index.json' }, stdio: ['ignore', 'pipe', 'pipe'] });
    children.add(child); let output = '';
    // A cold native compile on Windows ARM64 invokes the pinned x64 Zig linker
    // under emulation. Keep protocol commands bounded tightly and observe the
    // linker while allowing this one consumer build to finish.
    const command = executable === cli ? args[0] : 'native executable';
    const deadlineMs = target === 'windows-arm64' && command === 'compile' ? 600000 : 60000;
    const diagnosticTimer = target === 'windows-arm64' && command === 'compile'
      ? setInterval(() => { void reportNativeProcesses(command); }, 60000) : null;
    const clearDiagnostics = () => { if (diagnosticTimer) clearInterval(diagnosticTimer); };
    const timer = setTimeout(() => { clearDiagnostics(); child.kill(); no(new Error(`Publishing bank exceeded ${deadlineMs} ms during ${command}`)); }, deadlineMs);
    const capture = bytes => { output += bytes; log += bytes; };
    child.stdout.on('data', capture); child.stderr.on('data', capture);
    child.once('error', error => { clearTimeout(timer); clearDiagnostics(); children.delete(child); no(error); });
    child.once('exit', (code, signal) => { clearTimeout(timer); clearDiagnostics(); children.delete(child);
      if (fault) no(fault); else yes({ code, signal, output }); });
  });
}
async function success(path, args) { const result = await run(path, args); assert.equal(result.code, 0, result.output); return result.output; }
try {
  console.log(JSON.stringify({ cli, root, target, provider: 'offline protocol fixture; no OAuth proof' }));
  const author = await localRoot('author'), reader = await localRoot('anonymous');
  await success(author, ['login', '--no-browser']);
  const packageRoot = resolve(root, 'RegistryProbe');
  await mkdir(`${packageRoot}/Module`, { recursive: true });
  await mkdir(`${packageRoot}/Boundary/${target}`, { recursive: true });
  await mkdir(`${packageRoot}/.silex/cache`, { recursive: true });
  await writeFile(`${packageRoot}/.silex/cache/private`, 'must not be published');
  await writeFile(`${packageRoot}/Boundary/${target}/fixture.a`, artifact);
  await missing(`${packageRoot}/.git`);
  for (const version of ['1.0.0', '1.1.0']) {
    const manifest = JSON.stringify({ name: 'RegistryProbe', version, requires: { silex: '>=0.44.0' },
      artifacts: { [target]: { Fixture: { path: `Boundary/${target}/fixture.a`, sha256: artifactDigest } } } });
    const files = new Map([
      ['Package.json', Buffer.from(manifest)],
      ['Module/Value.sx', Buffer.from('public func answer() int { return 42 }\npublic func message() str { return embed_text("Message é.txt") }\n')],
      ['Module/Message é.txt', Buffer.from(message)],
    ]);
    expectations.set(version, files);
    for (const [path, bytes] of files) await writeFile(`${packageRoot}/${path}`, bytes);
    if (version === '1.0.0') {
      await success(author, ['publish', packageRoot, '--dry-run']);
      const failed = await run(author, ['publish', packageRoot]); assert.equal(failed.code, 1, failed.output);
      assert(dropped, failed.output); assert.match(failed.output, /cannot contact the package registry/);
      assert(!publications.get(version).published);
    }
    const uploads = artifactUploads;
    await success(author, ['publish', packageRoot]);
    if (version === '1.1.0') assert.equal(artifactUploads, uploads, 'Shared artifact must not be sent again.');
    assert.match(await success(author, ['publish', packageRoot]), /already published/);
  }
  assert(resumed); assert.equal(artifactUploads, 3);
  pass('publication resumes after a lost acknowledgement; two immutable versions share one artifact');
  pass('independent archive reader verifies exact manifest, NFC resource and exclusion of cache/private data');
  await success(author, ['logout']); assert(revoked);
  await rename(packageRoot, resolve(root, 'retained-origin'));
  await missing(resolve(reader, 'data')); await missing(resolve(reader, 'auth'));
  await success(reader, ['install', 'RegistryProbe@1.0.0', '--target', target]);
  const installed = resolve(reader, 'data/packages/RegistryProbe@1.0.0');
  for (const [path, bytes] of expectations.get('1.0.0')) assert.deepEqual(await readFile(`${installed}/${path}`), bytes);
  assert.deepEqual(await readFile(`${installed}/Boundary/${target}/fixture.a`), artifact);
  const receipt = JSON.parse(await readFile(`${installed}/.silex/source.json`, 'utf8'));
  assert.equal(receipt.schema, 4); assert.equal(receipt.publication_sha256, publications.get('1.0.0').digest);
  assert.deepEqual(receipt.dependencies, []); assert.equal(receipt.artifacts[0].sha256, artifactDigest);
  await success(reader, ['install', 'RegistryProbe@1.0.0', '--target', target]);
  pass('anonymous empty-store installation preserves exact sources, target artifact and publication receipt');
  const app = await localRoot('App');
  await writeFile(`${app}/Package.json`, JSON.stringify({ sources: '.', dependencies: { RegistryProbe: '=1.0.0' } }));
  await writeFile(`${app}/Main.sx`, 'use RegistryProbe.Value\nfunc main() { print(Value.answer(), ":", Value.message()) }\n');
  let execution;
  if (target === 'windows-arm64') {
    const binary = resolve(app, 'RegistryConsumer.exe');
    console.log('windows-arm64: compile installed consumer with the emulated x64 linker');
    await success(reader, ['compile', `${app}/Main.sx`, '--backend', 'native', '--nocache', '-o', binary]);
    console.log('windows-arm64: execute compiled consumer');
    const standalone = await run(reader, [], binary);
    assert.equal(standalone.code, 0, standalone.output);
    execution = standalone.output;
  } else {
    execution = await success(reader, ['run', `${app}/Main.sx`, '--backend', 'native', '--nocache']);
  }
  assert.match(execution, /(?:^|\n)42:portable registry resource\r?\n/);
  pass('host-native consumer executes installed code and embedded resource after origin is unavailable');
  for (const kind of ['source', 'artifact']) {
    corrupt = kind; const victim = await localRoot(`corrupt-${kind}`);
    const result = await run(victim, ['install', 'RegistryProbe@1.1.0', '--target', target]);
    assert.equal(result.code, 1, result.output);
    assert.match(result.output, kind === 'source' ? /source does not match its descriptor/ : /cannot download or verify registry artifact/);
    await missing(resolve(victim, 'data/packages/RegistryProbe@1.1.0'));
  }
  corrupt = '';
  pass('corrupt source and artifact bytes are refused without exposing an installed package');
  await missing(resolve(reader, 'auth')); assert(publicReads > 0);
  assert(!log.includes(token) && !log.includes(loginTicket.slice(6))); assert(!fault);
  pass('public requests are credential-free and output contains neither bearer nor attempt ticket');
  await writeFile(resolve(root, 'result.json'), JSON.stringify({ target, checks, publicReads, artifactUploads,
    publication_sha256: publications.get('1.0.0').digest, native_output: '42:portable registry resource' }, null, 2));
  console.log(`PASS ${checks} groups on ${target}; retained state: ${root}`);
} finally {
  await Promise.all([...children].map(child => new Promise(yes => {
    if (child.exitCode !== null || child.signalCode !== null) return yes(); child.once('exit', yes); child.kill();
  })));
  server.closeAllConnections(); await new Promise(yes => server.close(yes));
}
