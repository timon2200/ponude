#!/usr/bin/env python3
"""
generate_deck_pdf.py — Compiles all slides into a 6-page 16:9 presentation PDF using Chrome headless.
"""

import os
import re
import json
import subprocess
import tempfile
from pathlib import Path

CHROME_BIN = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DECK_DIR = Path("/Users/timonterzic/Documents/Ponude/Meridian16_Prezentacija")
ENGINE_DIR = Path("/Users/timonterzic/Documents/Ponude/deck_engine")

def load_file(p):
    if not os.path.exists(p):
        return ""
    with open(p, 'r', encoding='utf-8') as f:
        return f.read()

def build_pdf():
    manifest = json.loads(load_file(DECK_DIR / "deck.json"))
    theme_data = json.loads(load_file(ENGINE_DIR / "themes" / f"{manifest.get('theme', 'editorial-canvas')}.json"))
    
    css_vars = [":root {"]
    for k, v in theme_data.get("variables", {}).items():
        css_vars.append(f"  --{k}: {v};")
    css_vars.append("}")
    css_vars_str = "\n".join(css_vars)
    
    core_css = load_file(ENGINE_DIR / "core" / "css" / "base.css")
    custom_css = load_file(DECK_DIR / "custom.css")
    
    slides_html = []
    for s in manifest.get("slides", []):
        fpath = DECK_DIR / s["file"]
        content = load_file(fpath)
        slides_html.append(f"""
        <div class="deck-page">
            <div class="slide-wrapper-print">
                {content}
            </div>
        </div>
        """)
        
    all_slides = "\n".join(slides_html)
    
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700;800;900&family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&family=Syne:wght@700;800;900&display=swap" rel="stylesheet">
    <style>
        {css_vars_str}
        
        @page {{
            size: 1920px 1080px;
            margin: 0;
        }}
        
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
        }}
        
        body {{
            background: var(--bg-canvas);
            font-family: var(--font-sans);
            color: var(--text-primary);
        }}
        
        .deck-page {{
            width: 1920px;
            height: 1080px;
            page-break-after: always;
            break-after: page;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 40px;
            background: var(--bg-canvas);
            position: relative;
            overflow: hidden;
        }}
        
        .slide-wrapper-print {{
            width: 1840px;
            height: 1000px;
            background: var(--bg-card);
            border: 3px solid var(--text-primary);
            border-radius: 12px;
            box-shadow: 10px 10px 0px rgba(17, 21, 24, 0.2);
            padding: 45px 55px;
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }}
        
        .slide {{
            display: flex !important;
            opacity: 1 !important;
            position: relative !important;
            width: 100% !important;
            height: 100% !important;
            padding: 0 !important;
            flex-direction: column;
            justify-content: space-between;
            overflow: hidden !important;
        }}
        
        .quote-title {{
            font-family: var(--font-hero);
            font-size: 2.5rem;
            font-weight: 900;
            line-height: 1.05;
            letter-spacing: -0.02em;
            text-transform: uppercase;
            margin-bottom: 0.4rem;
        }}
        
        .outline-text {{
            color: transparent;
            -webkit-text-stroke: 1.8px var(--text-primary);
        }}
        
        .quote-sub {{
            font-family: var(--font-sans);
            font-size: 1.25rem;
            font-weight: 700;
            color: var(--accent-green);
            margin-bottom: 0.75rem;
        }}
        
        .grid-2col {{
            display: grid;
            grid-template-columns: 1.15fr 0.85fr;
            gap: 2.5rem;
            align-items: center;
            height: 100%;
        }}
        
        .grid-2col.equal {{
            grid-template-columns: 1fr 1fr;
        }}
        
        .grid-3col {{
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 1.5rem;
            height: 100%;
            margin-top: 0.8rem;
        }}
        
        .cloth-card-canvas {{
            display: none !important;
        }}
        
        .offer-box {{
            opacity: 1 !important;
        }}
        
        {custom_css}
    </style>
</head>
<body>
    {all_slides}
</body>
</html>"""
    
    with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False, encoding='utf-8') as f:
        # Resolve relative image paths to absolute
        abs_html = html.replace('src="slike/', f'src="{DECK_DIR}/slike/')
        abs_html = abs_html.replace("src='slike/", f"src='{DECK_DIR}/slike/")
        f.write(abs_html)
        temp_html = f.name
        
    out_pdf = DECK_DIR / "Meridian16_Brand_Film_Presentation.pdf"
    try:
        cmd = [
            CHROME_BIN,
            "--headless=new",
            "--disable-gpu",
            "--no-pdf-header-footer",
            "--window-size=1920,1080",
            f"--print-to-pdf={out_pdf}",
            temp_html
        ]
        subprocess.run(cmd, check=True)
        print(f"🎉 Generated multi-page presentation PDF -> {out_pdf}")
    finally:
        if os.path.exists(temp_html):
            os.remove(temp_html)

if __name__ == '__main__':
    build_pdf()
