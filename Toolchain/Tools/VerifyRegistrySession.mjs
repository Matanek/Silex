// Portable CLI/storage qualification. No PHP, GitHub request or user-home override.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { randomBytes } from 'node:crypto';
import { mkdir, mkdtemp, readFile, writeFile, access, stat, link, unlink } from 'node:fs/promises';
import { resolve, isAbsolute } from 'node:path';

const cli = process.argv[2]; assert(cli && isAbsolute(cli));
await mkdir('TestState/registry-session', { recursive: true });
const root = await mkdtemp(resolve('TestState/registry-session/run-'));
const windows = process.platform === 'win32';
const savedName = windows ? 'registry.dpapi' : 'registry.json';
const children = new Set(), attempts = new Map();
let mode = 'authorized', revoked = false, revokeFailure = false, requests = 0, log = '', checks = 0;
const token = randomBytes(32).toString('hex'), id = randomBytes(16).toString('hex');
const expires_at = Math.floor(Date.now() / 1000) + 86400;
const pass = label => console.log(`ok ${++checks} - ${label}`);
const server = createServer((request, response) => {
  requests++; response.setHeader('Content-Type', 'application/json');
  const authorization = request.headers.authorization ?? '';
  function send(status, body) { response.writeHead(status); response.end(JSON.stringify(body)); }
  if (request.url === '/v2/session') {
    if (authorization !== `Bearer ${token}`) return send(401, {});
    if (request.method === 'DELETE') {
      if (revokeFailure) return send(503, {});
      revoked = true; return send(200, { revoked: true });
    }
    return revoked ? send(401, {}) : send(200, { github_id: '1001', login: 'fixture-user', expires_at });
  }
  if (request.method !== 'POST' || !/^Login [a-f0-9]{64}$/.test(authorization)) return send(401, {});
  if (request.url === '/v2/logins') {
    attempts.set(authorization, id); revoked = false;
    return send(200, { id, state: 'pending', expires_at: Math.floor(Date.now() / 1000) + 900,
      user_code: 'TEST-1234', verification_uri: 'https://github.com/login/device', interval: 1, retry_after: 1 });
  }
  if (request.url !== `/v2/logins/${id}` || attempts.get(authorization) !== id) return send(403, {});
  if (mode === 'pending') return send(200, { id, state: 'pending', expires_at, retry_after: 1 });
  if (mode !== 'authorized') return send(200, { id, state: mode, expires_at });
  send(200, { id, state: 'authorized', token, github_id: '1001', login: 'fixture-user', expires_at });
});
await new Promise(yes => server.listen(0, '127.0.0.1', yes));
const url = `http://127.0.0.1:${server.address().port}`;
async function clientRoot(name) { const path = `${root}/${name}`; await mkdir(path); return path; }
async function missing(path) { await assert.rejects(access(path), { code: 'ENOENT' }); }
function run(path, args, onCode) {
  return new Promise((yes, no) => {
    const child = spawn(cli, args, { env: { ...process.env, SILEX_REGISTRY_TEST_URL: url, SILEX_REGISTRY_TEST_ROOT: path },
      stdio: ['ignore', 'pipe', 'pipe'] });
    children.add(child); let output = '', handled = false;
    const timer = setTimeout(() => { child.kill(); no(new Error('CLI deadline exceeded')); }, 15000);
    const capture = data => {
      output += data; log += data;
      if (!handled && onCode && output.includes('TEST-1234')) {
        handled = true; Promise.resolve(onCode(child)).catch(error => { child.kill(); no(error); });
      }
    };
    child.stdout.on('data', capture); child.stderr.on('data', capture); child.once('error', no);
    child.once('exit', (code, signal) => { clearTimeout(timer); children.delete(child); yes({ code, signal, output }); });
  });
}
try {
  console.log(JSON.stringify({ cli, root, platform: process.platform, architecture: process.arch, provider: 'offline registry response fixture, not OAuth proof' }));
  const first = await clientRoot('first'), file = `${first}/auth/${savedName}`;
  let result = await run(first, ['login', '--no-browser']); assert.equal(result.code, 0, result.output);
  const bytes = await readFile(file);
  if (windows) {
    assert(!bytes.includes(Buffer.from(token))); assert(!bytes.includes(Buffer.from('fixture-user')));
    await missing(`${first}/auth/registry.json`);
  } else {
    assert.equal(JSON.parse(bytes).token, token);
    assert.equal((await stat(file)).mode & 0o777, 0o600);
    assert.equal((await stat(`${first}/auth`)).mode & 0o777, 0o700);
  }
  result = await run(first, ['login', '--no-browser']); assert.equal(result.code, 0, result.output);
  assert.match(result.output, /already connected/);
  pass('credential persisted privately and restored by a second CLI process');

  const originalRequests = requests;
  const tampered = Buffer.from(bytes); tampered[tampered.length - 1] ^= 1; await writeFile(file, tampered);
  result = await run(first, ['login', '--no-browser']); assert.equal(result.code, 1);
  assert.equal(requests, originalRequests); await writeFile(file, bytes);
  if (windows) {
    await writeFile(file, JSON.stringify({ token, github_id: '1001', login: 'fixture-user', expires_at }));
    result = await run(first, ['login', '--no-browser']); assert.equal(result.code, 1);
    assert.equal(requests, originalRequests); await writeFile(file, bytes);
  }
  await link(file, `${first}/duplicate`);
  result = await run(first, ['login', '--no-browser']); assert.equal(result.code, 1);
  assert.equal(requests, originalRequests); await unlink(`${first}/duplicate`);
  pass('corrupt credentials and multiply-linked files fail before making a network request');

  revokeFailure = true; result = await run(first, ['logout']); assert.equal(result.code, 1);
  assert.deepEqual(await readFile(file), bytes);
  revokeFailure = false; result = await run(first, ['logout']); assert.equal(result.code, 0, result.output);
  assert(revoked); await missing(file);
  assert.equal((await run(first, ['logout'])).code, 0);
  pass('logout retains credentials on failure and removes them only after server revocation');

  for (const state of ['denied', 'expired', 'consumed', 'failed']) {
    mode = state; const path = await clientRoot(state); result = await run(path, ['login', '--no-browser']);
    assert.equal(result.code, 1); await missing(`${path}/auth/${savedName}`);
  }
  pass('denied, expired and already consumed attempts do not save credentials');

  mode = 'pending'; const locked = await clientRoot('locked');
  result = await run(locked, ['login', '--no-browser'], async child => {
    const other = await run(locked, ['logout']); assert.equal(other.code, 1);
    assert.match(other.output, /RegistryLoginAlreadyRunning/); child.kill();
  });
  assert(result.code !== 0); await missing(`${locked}/auth/${savedName}`);
  assert.equal((await run(locked, ['logout'])).code, 0);
  pass('competing commands cannot overwrite state and process death releases the lock');

  assert(!log.includes(token));
  for (const authorization of attempts.keys()) assert(!log.includes(authorization.slice(6)));
  pass('neither attempt tickets nor registry bearer appear in CLI output');
  console.log(`PASS ${checks} groups; no OAuth requests and no real user credentials.`);
} finally {
  await Promise.all([...children].map(child => new Promise(yes => {
    if (child.exitCode !== null || child.signalCode !== null) return yes(); child.once('exit', yes); child.kill();
  })));
  server.closeAllConnections(); await new Promise(yes => server.close(yes));
}
