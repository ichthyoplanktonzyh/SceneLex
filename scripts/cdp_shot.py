#!/usr/bin/env python3
"""Capture the scenelex Chrome tab via CDP at a fixed device viewport.

Usage: cdp_shot.py <width> <height> <out.png> [port=9222]
"""
import base64
import json
import sys
import time
import urllib.request

import websocket


def find_page(port):
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(
                f'http://127.0.0.1:{port}/json', timeout=3
            ) as resp:
                tabs = json.load(resp)
            for tab in tabs:
                url = tab.get('url', '')
                if tab.get('type') == 'page' and 'localhost' in url:
                    return tab['webSocketDebuggerUrl']
        except Exception:
            pass
        time.sleep(1)
    return None


def shot(ws_url, width, height, out_path):
    ws = websocket.create_connection(ws_url, timeout=20)
    ws.send(
        json.dumps(
            {
                'id': 1,
                'method': 'Emulation.setDeviceMetricsOverride',
                'params': {
                    'width': width,
                    'height': height,
                    'deviceScaleFactor': 1,
                    'mobile': False,
                },
            }
        )
    )
    ws.recv()
    ws.send(
        json.dumps(
            {
                'id': 2,
                'method': 'Page.captureScreenshot',
                'params': {'format': 'png', 'captureBeyondViewport': False},
            }
        )
    )
    while True:
        msg = json.loads(ws.recv())
        if msg.get('id') == 2:
            data = msg.get('result', {}).get('data')
            if not data:
                raise RuntimeError(f'no screenshot data: {msg}')
            with open(out_path, 'wb') as f:
                f.write(base64.b64decode(data))
            break
    ws.close()


if __name__ == '__main__':
    width, height, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    port = int(sys.argv[4]) if len(sys.argv) > 4 else 9222
    ws_url = find_page(port)
    if ws_url is None:
        print('no scenelex tab found', flush=True)
        sys.exit(1)
    shot(ws_url, width, height, out)
    print(f'saved {out}', flush=True)
