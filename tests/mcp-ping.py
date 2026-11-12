#!/usr/bin/env python3
"""One hardcoded MCP exchange and a doctor call. No agent.

Fails unless doctor reports a screenshot route, an input route and, unless
EXPECT_WINDOW_CONTROL=0, a window-control backend.
"""
import json
import os
import sys
import urllib.request

url = os.environ.get("MCP_URL", "http://127.0.0.1:5200/mcp")
token = os.environ["COMPUTER_USE_LINUX_MCP_TOKEN"]


def post(body, session=None):
    data = json.dumps(body).encode()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if session:
        headers["Mcp-Session-Id"] = session
    request = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read().decode()
        session = response.headers.get("Mcp-Session-Id", session)
    messages = []
    for line in raw.splitlines():
        if line.startswith("data:") and line[5:].strip():
            messages.append(json.loads(line[5:].strip()))
    if not messages and raw.strip():
        messages.append(json.loads(raw))
    return session, messages


session, init = post({
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2025-06-18",
        "capabilities": {},
        "clientInfo": {"name": "mod-install-test", "version": "0"},
    },
})
if init[0].get("result", {}).get("protocolVersion") != "2025-06-18":
    sys.exit(f"initialize failed: {init}")
post({"jsonrpc": "2.0", "method": "notifications/initialized"}, session)
_, listed = post({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}, session)
names = [tool["name"] for tool in listed[0]["result"]["tools"]]
if "get_app_state" not in names:
    sys.exit(f"tools/list missing get_app_state: {names}")
print(f"ok mcp tools={len(names)}")

_, called = post({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                  "params": {"name": "doctor", "arguments": {}}}, session)
result = called[0]["result"]
report = result.get("structuredContent") or json.loads(result["content"][0]["text"])
caps = report.get("capabilities", {})
summary = {key: caps.get(key) for key in ("screenshot", "input", "window_control")}
print(f"doctor {json.dumps(summary)} blockers={report.get('blockers')}")
required = ["screenshot", "input"]
if os.environ.get("EXPECT_WINDOW_CONTROL", "1") != "0":
    required.append("window_control")
missing = [key for key in required if not caps.get(key)]
if missing:
    sys.exit(f"doctor reports no {', '.join(missing)}")
