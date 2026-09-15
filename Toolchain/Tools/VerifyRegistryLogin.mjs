// Run from the Spec Worktree group with explicit candidate CLI and PHP paths.
// The sibling registry supplies an offline GitHub fixture, never a real consent.
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, writeFile, stat, chmod, symlink, access } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createServer as createSocket } from 'node:net';
import { resolve } from 'node:path';

const group = process.cwd(), [cli, php] = process.argv.slice(2);
assert(cli?.startsWith('/') && php?.startsWith('/'));
const registry = resolve(group, 'Silex-Registry');
await access(`${registry}/server/tests/login-router.php`);
await mkdir('TestState/cli-login', { recursive: true });
const root = await mkdtemp(resolve('TestState/cli-login/run-'));
const serverRoot = `${root}/server`;
await mkdir(serverRoot, { mode: 0o700 });
let checks = 0, output = '', serverErrors = '';
const children = new Set(), servers = new Set();
const pass = label => console.log(`ok ${++checks} - ${label}`);
function fixture(action, values = {}) {
  return JSON.parse(execFileSync(php, [`${registry}/server/tests/login-fixture.php`], {
    input: JSON.stringify({ root: serverRoot, action, ...values }), encoding: 'utf8', timeout: 10000,
  }));
}
async function localRoot(name) { const path = `${root}/${name}`; await mkdir(path); return path; }
async function missing(path) { await assert.rejects(access(path), { code: 'ENOENT' }); }
function command(path, args, { url = base, env = {}, onCode } = {}) {
  return new Promise((yes, no) => {
    const child = spawn(cli, args, { cwd: group, env: { ...process.env,
      SILEX_REGISTRY_TEST_URL: url, SILEX_REGISTRY_TEST_ROOT: path, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
    children.add(child); let text = '', handled = false;
    const timer = setTimeout(() => { child.kill('SIGKILL'); no(new Error('CLI test exceeded 40 seconds')); }, 40000);
    function data(bytes) {
      text += bytes; output += bytes;
      const code = text.match(/enter (TEST-\d{4})/);
      if (code && !handled && onCode) {
        handled = true;
        Promise.resolve().then(() => onCode(code[1], child)).catch(error => { child.kill(); no(error); });
      }
    }
    child.stdout.on('data', data); child.stderr.on('data', data);
    child.on('error', no);
    child.on('exit', (code, signal) => { clearTimeout(timer); children.delete(child); yes({ code, signal, text }); });
  });
}
async function login(path, state = 'authorized', values = {}) {
  // Keep the mock clock near wall time so the CLI can verify the access lifetime.
  await writeFile(`${serverRoot}/clock`, String(Math.floor(Date.now() / 1000)));
  return command(path, ['login', '--no-browser'], { onCode(code) {
    fixture('configure', { user_code: code, state, ...values }); fixture('tick', { seconds: 5 });
  } });
}
async function fake(handler) {
  const server = createServer(handler); servers.add(server);
  await new Promise(yes => server.listen(0, '127.0.0.1', yes));
  return `http://127.0.0.1:${server.address().port}`;
}
let base;
try {
  console.log(JSON.stringify({ root, cli, php, registryHead: execFileSync('git', ['-C', registry, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(), provider: 'offline only' }));
  fixture('init');
  const socket = createSocket(); await new Promise(yes => socket.listen(0, '127.0.0.1', yes));
  const port = socket.address().port; await new Promise(yes => socket.close(yes));
  const server = spawn(php, ['-S', `127.0.0.1:${port}`, '-t', `${registry}/server/public`, `${registry}/server/tests/login-router.php`],
    { env: { ...process.env, SILEX_REGISTRY_DATA: serverRoot }, stdio: ['ignore', 'ignore', 'pipe'] });
  children.add(server); server.stderr.on('data', bytes => { serverErrors += bytes; });
  base = `http://127.0.0.1:${port}`;
  let ready = false;
  for (let retry = 0; retry < 100; retry++) {
    try { await fetch(base); ready = true; break; } catch { await new Promise(yes => setTimeout(yes, 20)); }
  }
  assert(ready, serverErrors);
  const first = await localRoot('success');
  let result = await login(first); assert.equal(result.code, 0, result.text);
  const credentialPath = `${first}/auth/registry.json`;
  const credential = JSON.parse(await readFile(credentialPath));
  assert.deepEqual(Object.keys(credential).sort(), ['expires_at', 'github_id', 'login', 'token']);
  assert.equal(credential.github_id, '1001'); assert.match(credential.token, /^[a-f0-9]{64}$/);
  assert.equal((await stat(credentialPath)).mode & 0o777, 0o600);
  assert.equal((await stat(`${first}/auth`)).mode & 0o777, 0o700);
  result = await command(first, ['login', '--no-browser']); assert.equal(result.code, 0, result.text);
  assert.match(result.text, /already connected/);
  const inspected = await fetch(`${base}/v2/session`, { headers: { Authorization: `Bearer ${credential.token}` } });
  assert.equal(inspected.status, 200);
  pass('actual CLI obtains a registry-only credential in private storage and reuses a live session');

  const switched = await fake((request, response) => response.end(JSON.stringify({ github_id: '1002', login: 'other', expires_at: credential.expires_at })));
  result = await command(first, ['login', '--no-browser'], { url: switched });
  assert.equal(result.code, 1); assert.match(result.text, /InvalidRegistryResponse/);
  assert.equal(JSON.parse(await readFile(credentialPath)).token, credential.token);
  pass('session inspection cannot silently replace the stable account identity');

  const unavailable = await fake((request, response) => { response.writeHead(503); response.end('{"error":"unavailable"}'); });
  result = await command(first, ['logout'], { url: unavailable }); assert.equal(result.code, 1);
  assert.equal(JSON.parse(await readFile(credentialPath)).token, credential.token);
  result = await command(first, ['logout']); assert.equal(result.code, 0, result.text);
  await missing(credentialPath);
  assert.equal((await fetch(`${base}/v2/session`, { headers: { Authorization: `Bearer ${credential.token}` } })).status, 401);
  assert.equal((await command(first, ['logout'])).code, 0);
  pass('logout preserves access on server failure, then revokes before removal and is idempotent');

  for (const state of ['denied', 'expired', 'network']) {
    const path = await localRoot(state); result = await login(path, state);
    assert.equal(result.code, 1, result.text); await missing(`${path}/auth/registry.json`);
    assert.match(result.text, state === 'denied' ? /RegistryLoginDenied/ : state === 'expired' ? /RegistryLoginExpired/ : /RegistryLoginUnavailable/);
  }
  pass('denial, expiry and provider failure leave no local access');

  const locked = await localRoot('locked');
  result = await command(locked, ['login', '--no-browser'], { async onCode(code, child) {
    const concurrent = await command(locked, ['logout']); assert.equal(concurrent.code, 1);
    assert.match(concurrent.text, /RegistryLoginAlreadyRunning/); child.kill('SIGTERM');
  } });
  assert.equal(result.signal, 'SIGTERM'); await missing(`${locked}/auth/registry.json`);
  assert.equal((await command(locked, ['logout'])).code, 0);
  pass('concurrent mutation is refused; process interruption releases the lock without saving a ticket');

  const unsafe = await localRoot('unsafe'); await mkdir(`${unsafe}/auth`, { mode: 0o755 });
  result = await command(unsafe, ['logout']); assert.equal(result.code, 1); assert.match(result.text, /StorageNotPrivate/);
  const linked = await localRoot('symlink'); await symlink(`${first}/auth`, `${linked}/auth`);
  assert.equal((await command(linked, ['logout'])).code, 1);
  await chmod(`${unsafe}/auth`, 0o700); await symlink(credentialPath, `${unsafe}/auth/registry.lock`);
  assert.equal((await command(unsafe, ['logout'])).code, 1); await missing(credentialPath);
  pass('public credential directories and symbolic links are refused without touching their targets');

  const isolated = await localRoot('isolation');
  assert.equal((await command(isolated, ['login', '--no-browser'], { env: { SILEX_REGISTRY_TEST_ROOT: '' } })).code, 1);
  assert.equal((await command(isolated, ['login', '--no-browser'], { url: 'http://127.0.0.1:80@evil.invalid' })).code, 1);
  assert.equal((await command(group, ['logout'])).code, 1);
  assert.equal((await command(isolated, ['login', '--token', 'not-supported'])).code, 1);
  pass('test endpoint/root are paired, loopback-only and confined to TestState; no credential argument');

  let redirected = false;
  const destination = await fake((request, response) => { redirected = true; response.end('{}'); });
  const redirect = await fake((request, response) => { response.writeHead(302, { Location: destination }); response.end(); });
  assert.equal((await command(await localRoot('redirect'), ['login', '--no-browser'], { url: redirect })).code, 1);
  assert(!redirected);
  const oversized = await fake((request, response) => response.end('x'.repeat(40000)));
  assert.equal((await command(await localRoot('oversized'), ['login', '--no-browser'], { url: oversized })).code, 1);
  const poisoned = await fake((request, response) => response.end(JSON.stringify({ id: 'a'.repeat(32), state: 'pending', expires_at: 9999999999,
    user_code: 'TEST-0001', verification_uri: 'https://evil.invalid', retry_after: 1 })));
  result = await command(await localRoot('poisoned'), ['login', '--no-browser'], { url: poisoned });
  assert.equal(result.code, 1); assert(!result.text.includes('evil.invalid'));
  pass('redirects, oversized payloads and arbitrary browser URLs cannot propagate credentials or untrusted text');

  for (const mode of ['consumed', 'crossed', 'invalid-expiry']) {
    const path = await localRoot(mode), id = 'a'.repeat(32);
    const endpoint = await fake((request, response) => {
      response.setHeader('Content-Type', 'application/json');
      if (request.url === '/v2/logins') return response.end(JSON.stringify({ id, state: 'pending', expires_at: Math.floor(Date.now() / 1000) + 900,
        user_code: 'TEST-0001', verification_uri: 'https://github.com/login/device', retry_after: 1 }));
      response.end(JSON.stringify({ id: mode === 'crossed' ? 'b'.repeat(32) : id, state: mode === 'consumed' ? 'consumed' : 'authorized',
        expires_at: 9999999999, github_id: '1001', login: 'author', token: 'c'.repeat(64) }));
    });
    result = await command(path, ['login', '--no-browser'], { url: endpoint }); assert.equal(result.code, 1);
    await missing(`${path}/auth/registry.json`); assert(!result.text.includes('c'.repeat(64)));
    assert.match(result.text, mode === 'consumed' ? /StartAgain/ : /InvalidRegistryResponse/);
  }
  pass('consumed attempts, crossed responses and unbounded access lifetimes never create a local credential');

  const stalled = await fake(() => {}); const started = Date.now();
  result = await command(await localRoot('timeout'), ['login', '--no-browser'], { url: stalled });
  assert.equal(result.code, 1); assert.match(result.text, /RegistryRequestTimedOut/);
  assert(Date.now() - started < 32000);
  pass('a stalled HTTP peer is canceled within the request deadline');

  for (const code of Object.keys(JSON.parse(await readFile(`${serverRoot}/mock.json`)).devices)) {
    assert(!output.includes(code)); assert(!serverErrors.includes(code));
  }
  assert(!output.includes(credential.token) && !serverErrors.includes(credential.token));
  assert(!output.includes('Authorization:') && !output.includes('refresh_token'));
  pass('CLI and HTTP traces contain neither provider device/token secrets nor issued registry bearer');
  console.log(`PASS ${checks} groups; retained isolated state: ${root}`);
} finally {
  for (const server of servers) { server.closeAllConnections(); await new Promise(yes => server.close(yes)); }
  await Promise.all([...children].map(child => new Promise(yes => {
    if (child.exitCode !== null || child.signalCode !== null) return yes(); child.once('exit', yes); child.kill('SIGTERM');
  })));
}
