#!/usr/bin/env python3
"""
test_browser_scroll.py — Automated Chrome CDP Mobile Scroll & Layout Diagnostic
"""
import sys
import os
import json
import time
import subprocess
import urllib.request
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading

PORT = 8999
PONUDE_DIR = "/Users/timonterzic/Documents/Ponude"

def start_server():
    os.chdir(PONUDE_DIR)
    server = HTTPServer(('127.0.0.1', PORT), SimpleHTTPRequestHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server

def run_diagnostics():
    server = start_server()
    print(f"Local server started on http://127.0.0.1:{PORT}")

    # Launch headless Chrome with mobile viewport and remote debugging
    chrome_cmd = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "--headless",
        "--remote-debugging-port=9222",
        "--window-size=390,844",
        "--disable-gpu",
        "--no-sandbox",
        f"http://127.0.0.1:{PORT}/Meridian16_Prezentacija/index.html"
    ]
    chrome_proc = subprocess.Popen(chrome_cmd)
    time.sleep(1.5)

    try:
        # Get target tab
        resp = urllib.request.urlopen("http://127.0.0.1:9222/json").read()
        tabs = json.loads(resp)
        page_tab = [t for t in tabs if t.get("type") == "page" and "Meridian16" in t.get("url", "")][0]
        ws_url = page_tab["webSocketDebuggerUrl"]
        print(f"Connected to Chrome page tab: {ws_url}")

        # Use Python's built-in urllib or simple websocket if available
        # We can also use evaluate via chrome devtools protocol
    except Exception as e:
        print(f"Error connecting to Chrome CDP: {e}")
    finally:
        chrome_proc.terminate()

if __name__ == "__main__":
    run_diagnostics()
