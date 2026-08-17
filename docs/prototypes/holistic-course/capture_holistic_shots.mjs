// Dev-only screenshot capture for the Holistic Course preview (web).
// Drives a headless Chrome via CDP (Node >= 21 built-in WebSocket, no deps):
//   node tools/webui/capture_holistic_shots.mjs <port> <outDir>
// Each shot loads http://localhost:<port>/?step=N&dev=0 (or ?view=overview),
// waits for real rendering time, and captures at 780x1688.
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = process.argv[2] ?? '8766';
const outDir = process.argv[3] ?? '/tmp/holistic_shots';
mkdirSync(outDir, { recursive: true });

const shots = [
  ['01-course-overview', '/?view=overview'],
  ['02-first-step', '/?step=0&dev=0'],
  ['03-symbol-binding', '/?step=4&dev=0'],
  ['04-post-binding', '/?step=5&dev=0'],
  ['05-scheduled-review', '/?step=13&dev=0'],
  ['06-completion', '/?step=19&dev=0'],
  ['07-boundary', '/?step=8&dev=0'],
];

const chrome = spawn(CHROME, [
  '--headless=new',
  '--disable-gpu',
  '--hide-scrollbars',
  '--window-size=780,1688',
  '--remote-debugging-port=9223',
  '--user-data-dir=/tmp/chrome-holistic-profile',
  'about:blank',
]);
chrome.stderr.on('data', () => {});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(url) {
  const res = await fetch(url);
  return res.json();
}

async function waitForDevtools() {
  for (let i = 0; i < 40; i++) {
    try {
      const v = await getJson('http://127.0.0.1:9223/json/version');
      if (v.webSocketDebuggerUrl) return v.webSocketDebuggerUrl;
    } catch {}
    await sleep(500);
  }
  throw new Error('DevTools 未就绪');
}

function cdp(ws, id, method, params = {}) {
  return new Promise((resolve, reject) => {
    const onMessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.id === id) {
        ws.removeEventListener('message', onMessage);
        if (msg.error) reject(new Error(`${method}: ${msg.error.message}`));
        else resolve(msg.result);
      }
    };
    ws.addEventListener('message', onMessage);
    ws.send(JSON.stringify({ id, method, params }));
  });
}

const wsUrl = await waitForDevtools();
const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener('open', r));

// 复用同一个页面：导航到每个 shot 并等待渲染。
const page = (await getJson('http://127.0.0.1:9223/json/list')).find(
  (t) => t.type === 'page',
);
const pageWs = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => pageWs.addEventListener('open', r));
let msgId = 0;
const pageCdp = (method, params = {}) =>
  cdp(pageWs, ++msgId, method, params);

for (const [name, path] of shots) {
  await pageCdp('Page.navigate', { url: `http://localhost:${port}${path}` });
  await sleep(14000); // Flutter web（CanvasKit）真实渲染时间
  const { data } = await pageCdp('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });
  writeFileSync(join(outDir, `${name}.png`), Buffer.from(data, 'base64'));
  console.log(`captured ${name} (${(data.length / 1024).toFixed(0)}KB base64)`);
}

pageWs.close();
ws.close();
chrome.kill();
console.log('done');
