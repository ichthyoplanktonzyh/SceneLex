#!/usr/bin/env python3
"""Code relay for the checkpoint harness.

The runner clicks "Send code" in the real UI, which creates a fresh OTP
challenge on the server. The bash-pregenerated code would be invalidated by
that click, so instead this tiny HTTP server (started by run-checkpoints.sh)
performs the send-code call AFTER the click and reads the fresh code from the
server log, returning it to the test:

    GET /request-code?email=xxx   ->  {"code": "12345678"}
    GET /health                   ->  {"ok": true}

Listens on 127.0.0.1:9001 with permissive CORS for the test page origin.
"""

import datetime
import http.server
import json
import re
import subprocess
import time
import urllib.parse

SERVER_LOG = "/tmp/scenelex-server.log"
BASE = "http://127.0.0.1:8081/v1"


def _ts() -> str:
    return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]


class Handler(http.server.BaseHTTPRequestHandler):
    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/health":
            self._send(200, {"ok": True})
            return
        if parsed.path == "/request-code":
            email = urllib.parse.parse_qs(parsed.query).get("email", [""])[0]
            if not email:
                self._send(400, {"error": "email required"})
                return
            code = self._request_code(email)
            print(f"[{_ts()}] request-code email={email} -> {code}", flush=True)
            if code is None:
                self._send(500, {"error": "no code in server log"})
                return
            self._send(200, {"code": code})
            return
        if parsed.path == "/log":
            msg = urllib.parse.parse_qs(parsed.query).get("msg", [""])[0]
            print(f"[{_ts()}] TEST-LOG {msg}", flush=True)
            self._send(200, {"ok": True})
            return
        self._send(404, {"error": "not found"})

    def do_POST(self) -> None:
        self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        pass

    @staticmethod
    def _request_code(email: str) -> str | None:
        # Trigger a fresh challenge, then read the newest code for this exact
        # email from the server log (the server logs before its randomized
        # anti-enumeration delay, so the entry appears quickly).
        subprocess.run(
            ["curl", "-s", "-X", "POST", f"{BASE}/auth/send-code",
             "-H", "Content-Type: application/json",
             "-d", json.dumps({"email": email})],
            check=False,
            capture_output=True,
        )
        time.sleep(1.0)
        pattern = re.compile(rf"to={re.escape(email)} code=(\d{{8}})")
        try:
            with open(SERVER_LOG, encoding="utf-8", errors="replace") as f:
                matches = pattern.findall(f.read())
        except FileNotFoundError:
            return None
        return matches[-1] if matches else None


if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 9001), Handler)
    print("relay listening on 127.0.0.1:9001", flush=True)
    server.serve_forever()
