#!/usr/bin/env python3
"""
diagnose_mobile.py — In-depth Chrome Mobile DevTools Protocol Inspector
"""
import sys
import os
import json
import time
import subprocess
import urllib.request
import websocket
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading

PORT = 8998
PONUDE_DIR = "/Users/timonterzic/Documents/Ponude"

def start_server():
    os.chdir(PONUDE_DIR)
    server = HTTPServer(('127.0.0.1', PORT), SimpleHTTPRequestHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server

def cdp_eval(ws, expression):
    msg_id = int(time.time() * 1000) % 100000
    req = {
        "id": msg_id,
        "method": "Runtime.evaluate",
        "params": {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": True
        }
    }
    ws.send(json.dumps(req))
    while True:
        resp = json.loads(ws.recv())
        if resp.get("id") == msg_id:
            return resp.get("result", {}).get("result", {}).get("value")

def cdp_send(ws, method, params=None):
    msg_id = int(time.time() * 1000) % 100000
    req = {"id": msg_id, "method": method, "params": params or {}}
    ws.send(json.dumps(req))
    while True:
        resp = json.loads(ws.recv())
        if resp.get("id") == msg_id:
            return resp.get("result", {})

def test_mobile():
    server = start_server()
    chrome_cmd = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "--headless",
        "--remote-debugging-port=9222",
        "--remote-allow-origins=*",
        "--window-size=390,844",
        "--disable-gpu",
        "--no-sandbox",
        f"http://127.0.0.1:{PORT}/Meridian16_Prezentacija/index.html"
    ]
    proc = subprocess.Popen(chrome_cmd)
    time.sleep(1.5)

    try:
        resp = urllib.request.urlopen("http://127.0.0.1:9222/json").read()
        tabs = json.loads(resp)
        page_tab = [t for t in tabs if t.get("type") == "page" and "Meridian16" in t.get("url", "")][0]
        ws_url = page_tab["webSocketDebuggerUrl"]
        
        ws = websocket.create_connection(ws_url)

        # Enable Emulation & Page
        cdp_send(ws, "Emulation.setDeviceMetricsOverride", {
            "width": 390,
            "height": 844,
            "deviceScaleFactor": 3,
            "mobile": True,
            "touch": True
        })
        cdp_send(ws, "Emulation.setTouchEmulationEnabled", {"enabled": True})

        print("=== MOBILE DEVICE METRICS APPLIED (390x844, Touch Emulation) ===")

        for slide_idx in range(1, 7):
            print(f"\n--- TESTING SLIDE {slide_idx} ---")
            cdp_eval(ws, f"window.goToSlide({slide_idx})")
            time.sleep(0.3)

            diag = cdp_eval(ws, f"""(() => {{
                const slide = document.querySelector('.slide[data-slide="{slide_idx}"], .slide[data-index="{slide_idx}"]');
                if (!slide) return {{ error: "Slide not found" }};
                
                const style = window.getComputedStyle(slide);
                const wrapper = document.querySelector('.slide-wrapper');
                const wrapperStyle = window.getComputedStyle(wrapper);
                const stage = document.querySelector('.deck-stage');
                const stageStyle = window.getComputedStyle(stage);

                // Try programmatic scroll
                const prevScrollTop = slide.scrollTop;
                slide.scrollTop = 500;
                const afterProgrammaticScrollTop = slide.scrollTop;

                return {{
                    slideNumber: {slide_idx},
                    clientHeight: slide.clientHeight,
                    scrollHeight: slide.scrollHeight,
                    offsetHeight: slide.offsetHeight,
                    isScrollable: slide.scrollHeight > slide.clientHeight,
                    overflowY: style.overflowY,
                    position: style.position,
                    display: style.display,
                    height: style.height,
                    maxHeight: style.maxHeight,
                    wrapperHeight: wrapperStyle.height,
                    wrapperMaxHeight: wrapperStyle.maxHeight,
                    wrapperOverflow: wrapperStyle.overflow,
                    wrapperDisplay: wrapperStyle.display,
                    stageHeight: stageStyle.height,
                    stageOverflow: stageStyle.overflow,
                    prevScrollTop,
                    afterProgrammaticScrollTop,
                    canScroll: afterProgrammaticScrollTop > prevScrollTop,
                    childrenCount: slide.children.length
                }};
            }})()""")
            print(json.dumps(diag, indent=2))

            # Take Screenshot before and after
            screenshot_data = cdp_send(ws, "Page.captureScreenshot", {"format": "png"})
            with open(f"/Users/timonterzic/Documents/Ponude/diag_slide{slide_idx}.png", "wb") as f:
                import base64
                f.write(base64.b64decode(screenshot_data["data"]))

        ws.close()
    finally:
        proc.terminate()

if __name__ == "__main__":
    test_mobile()
