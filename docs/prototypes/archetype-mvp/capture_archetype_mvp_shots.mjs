#!/usr/bin/env node
// Capture Teaching Archetype MVP screenshots via headless Chrome CDP.
// Requires: Flutter web server on :8766 (SCENELEX_ARCHETYPE_MVP=true),
// Node >= 21 (built-in WebSocket), headless Chrome.
//
// Usage:
//   node capture_archetype_mvp_shots.mjs [--port 8766] [--out docs/prototypes/archetype-mvp]
//
// The preview app accepts dev URL params (?day / ?seed / ?session / ?step /
// ?view) documented in docs/prototypes/archetype-mvp/README.md §9. All shots
// below are driven through those params plus real UI clicks where needed.

import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const args = process.argv.slice(2);
const portArg = args.indexOf('--port');
const port = portArg >= 0 ? Number(args[portArg + 1]) : 8766;
const outArg = args.indexOf('--out');
const outDir = outArg >= 0 ? args[outArg + 1] : 'docs/prototypes/archetype-mvp';
const chrome = process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

mkdirSync(outDir, { recursive: true });

const debugPort = 9224;
const chromeProc = spawn(chrome, [
  '--headless=new',
  `--remote-debugging-port=${debugPort}`,
  '--no-first-run',
  '--no-default-browser-check',
  `--user-data-dir=/tmp/archetype-mvp-chrome-profile-${Date.now()}`,
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForJson(url, tries = 40) {
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch (_) { /* not up yet */ }
    await sleep(1000);
  }
  throw new Error(`timeout waiting for ${url}`);
}

async function connect() {
  const version = await waitForJson(`http://127.0.0.1:${debugPort}/json/version`);
  const ws = new WebSocket(version.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });
  let nextId = 1;
  const pending = new Map();
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  };
  const send = (method, params = {}) =>
    new Promise((resolve) => {
      const id = nextId++;
      pending.set(id, resolve);
      ws.send(JSON.stringify({ id, method, params }));
    });
  return { ws, send };
}

const { ws, send } = await connect();
const { result: target } = await send('Target.createTarget', { url: 'about:blank' });
const { result: attachResult } = await send('Target.attachToTarget', {
  targetId: target.targetId,
  flatten: true,
});
const sessionId = attachResult.sessionId;

const sendTo = (method, params = {}) =>
  new Promise((resolve) => {
    const id = Math.floor(Math.random() * 1e9);
    const onMsg = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.id === id && msg.sessionId === sessionId) {
        ws.removeEventListener('message', onMsg);
        resolve(msg);
      }
    };
    ws.addEventListener('message', onMsg);
    ws.send(JSON.stringify({ id, sessionId, method, params }));
  });

async function shot(name, url, { wait = 6500, width = 390, height = 844, dpr = 3 } = {}) {
  await sendTo('Emulation.setDeviceMetricsOverride', {
    width, height, deviceScaleFactor: dpr, mobile: width < 600,
  });
  await sendTo('Page.navigate', { url });
  await sleep(wait);
  const { result } = await sendTo('Page.captureScreenshot', { format: 'png' });
  const file = join(outDir, name);
  writeFileSync(file, Buffer.from(result.data, 'base64'));
  console.log(`✓ ${file}`);
  return file;
}

const base = `http://localhost:${port}`;

try {
  // 1. Day 1 home（唯一主入口）
  await shot('mvp-01-home-day1.png', `${base}/?day=1`);
  // 2. Mixed Today Session 首页（第 3 天：messy/dirty 已绑定 → 回想 + 新义项课）
  await shot('mvp-02-home-mixed-day3.png', `${base}/?day=3&seed=demo`);
  // 3. 中途退出后的继续状态（第 2 天：day-1 课程未到断点 → 必须继续）
  await shot('mvp-03-home-resume.png', `${base}/?day=2&seed=partial`);
  // 4. 桌面/平板首页
  await shot('mvp-04-home-desktop.png', `${base}/?day=1`, { width: 1280, height: 800, dpr: 2 });
  // 5. 跨天 scheduled review（第 2 天 session：r1 回想进入计划）
  await shot('mvp-05-session-review.png', `${base}/?day=2&seed=demo&session=1&step=0`);
  // 6. 完成页（step 超出计划 → 完成视图）
  await shot('mvp-06-completion.png', `${base}/?day=1&session=1&step=99`);
  // 7. 开发者总览（课程/类别覆盖）
  await shot('mvp-07-dev-overview.png', `${base}/?day=3&seed=demo&view=overview`);
  // Phase 2: one real course step per archetype (MVP session chrome)
  const labShots = [
    ['mvp-08-entity-category-object-inspection.png', 'cup-01', 2],
    ['mvp-09-visible-attribute-boundary.png', 'dirty-01', 9],
    ['mvp-10-spatial-path-stage.png', 'across-01', 1],
    ['mvp-11-role-perspective-map.png', 'borrow-01', 1],
    ['mvp-12-threshold-scale.png', 'almost-01', 2],
    ['mvp-13-intention-cues.png', 'reluctant-01', 1],
    ['mvp-14-cognitive-update.png', 'realize-01', 1],
    ['mvp-15-multi-label-choice.png', 'cup-01', 13],
  ];
  for (const [name, sense, step] of labShots) {
    await shot(name, `${base}/?lab=${sense}&step=${step}`);
  }
} finally {
  ws.close();
  chromeProc.kill('SIGTERM');
}
console.log('done');

// ---------------------------------------------------------------------------
// Phase 2: renderer-level shots via the dev-only ?lab=<sense>&step=<idx>
// endpoint (real course steps, MVP session chrome).
// ---------------------------------------------------------------------------
