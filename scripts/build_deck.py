#!/Users/timonterzic/Documents/Ponude/venv/bin/python
"""
build_deck.py — Modular Presentation Deck Compiler
Bundles atomic slide files, theme tokens, and core deck engine into a 100% zero-dependency standalone HTML file.
"""

import sys
import os
import json
import re
import time
import argparse
from pathlib import Path
import urllib.parse

PONUDE_ROOT = Path("/Users/timonterzic/Documents/Ponude")
ENGINE_DIR = PONUDE_ROOT / "deck_engine"
VARAZDIN_STUDIO_ROOT = Path("/Users/timonterzic/Documents/Studio Varazdin/varazdin.studio")

def load_json(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def load_file(filepath):
    if not os.path.exists(filepath):
        return ""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def build_theme_css(theme_data):
    lines = [":root {"]
    for key, val in theme_data.get("variables", {}).items():
        lines.append(f"  --{key}: {val};")
    lines.append("  --transition-smooth: cubic-bezier(0.16, 1, 0.3, 1);")
    lines.append("}")
    return "\n".join(lines)

def bundle_core_css():
    css_dir = ENGINE_DIR / "core" / "css"
    order = [
        "variables.css",
        "base.css",
        "header.css",
        "footer.css",
        "components.css",
        "modal.css"
    ]
    parts = []
    for fname in order:
        fpath = css_dir / fname
        if fpath.exists():
            parts.append(f"/* --- Core: {fname} --- */\n" + load_file(fpath))
    return "\n\n".join(parts)

def load_mobile_css():
    mobile_file = ENGINE_DIR / "core" / "css" / "mobile.css"
    if mobile_file.exists():
        return f"/* --- Responsive: mobile.css --- */\n" + load_file(mobile_file)
    return ""

def bundle_core_js():
    js_dir = ENGINE_DIR / "core" / "js"
    order = [
        "audio.js",
        "odometer.js",
        "modal.js",
        "particles.js",
        "cloth.js",
        "navigation.js"
    ]
    parts = []
    for fname in order:
        fpath = js_dir / fname
        if fpath.exists():
            code = load_file(fpath)
            # Strip ES module export / import statements so it bundles cleanly in a single script tag
            code = re.sub(r'^\s*import\s+.*?;?\s*$', '', code, flags=re.MULTILINE)
            code = re.sub(r'^\s*export\s+(function|class|const|let|var)\s+', r'\1 ', code, flags=re.MULTILINE)
            code = re.sub(r'^\s*export\s+\{.*?\};?\s*$', '', code, flags=re.MULTILINE)
            parts.append(f"// --- Core Module: {fname} ---\n" + code.strip())
    return "\n\n".join(parts)

def interpolate_vars(text, context):
    """Replaces {{KEY}} in text with context[KEY]."""
    for key, val in context.items():
        placeholder = f"{{{{{key}}}}}"
        text = text.replace(placeholder, str(val))
    return text

def compile_deck(deck_dir, deploy=False, theme_override=None):
    deck_dir = Path(deck_dir).resolve()
    manifest_path = deck_dir / "deck.json"

    if not manifest_path.exists():
        print(f"❌ Error: Missing deck.json in {deck_dir}")
        return False

    start_time = time.time()
    manifest = load_json(manifest_path)

    slug = manifest.get("slug", deck_dir.name.lower().replace("_prezentacija", ""))
    theme_id = theme_override or manifest.get("theme", "eco-utility")

    # 1. Resolve Theme
    theme_file = ENGINE_DIR / "themes" / f"{theme_id}.json"
    if not theme_file.exists():
        theme_file = ENGINE_DIR / "themes" / "eco-utility.json"
    theme_data = load_json(theme_file)
    theme_css = build_theme_css(theme_data)

    # 2. Core CSS & JS
    core_css = bundle_core_css()
    mobile_css = load_mobile_css()
    core_js = bundle_core_js()

    # 3. Project custom CSS & JS
    custom_css = load_file(deck_dir / "custom.css")
    project_js = load_file(deck_dir / "project.js") or load_file(deck_dir / "custom.js")

    # 4. Context variables for interpolation
    client_name = manifest.get("client_name", "Klijent")
    total_price = manifest.get("total", "0,00 EUR")
    contact_email = manifest.get("contact_email", "timon.terzic@gmail.com")
    issuer = manifest.get("issuer", {})

    context = {
        "TITLE": manifest.get("title", f"{client_name} — Pitch Deck | Studio Varaždin"),
        "CLIENT_NAME": client_name,
        "CLIENT_NAME_URL": urllib.parse.quote(client_name),
        "CLIENT_SLUG": slug,
        "TOTAL_PRICE": total_price,
        "TOTAL_PRICE_URL": urllib.parse.quote(total_price),
        "CONTACT_EMAIL": contact_email,
        "PDF_DOWNLOAD_PATH": manifest.get("pdf_path", f"assets/Ponuda_{slug}.pdf"),
        "HEADER_TAG": manifest.get("header_tag", "SLUŽBENA PONUDA // 2026"),
        "ISSUER_NAME": issuer.get("name", "STUDIO VARAŽDIN"),
        "ISSUER_OWNER": issuer.get("owner", "Vl. Jasenka Martinčević"),
        "ISSUER_ADDRESS": issuer.get("address", "S. Vraza 10, Varaždin"),
        "ISSUER_OIB": issuer.get("oib", "63287352089"),
        "ISSUER_PARTNER": issuer.get("partner", "Lotus RC")
    }

    # 5. Process Slides
    slides_config = manifest.get("slides", [])
    slides_html_parts = []
    slide_dots_parts = []
    slide_titles = []

    slides_dir = deck_dir / "slides"
    if not slides_dir.exists():
        # Fallback to default slides
        slides_dir = ENGINE_DIR / "core" / "templates" / "default_slides"

    for idx, slide_info in enumerate(slides_config, start=1):
        file_name = slide_info.get("file", f"0{idx}_slide.html")
        slide_file = deck_dir / file_name
        if not slide_file.exists():
            slide_file = deck_dir / "slides" / Path(file_name).name
        if not slide_file.exists():
            slide_file = ENGINE_DIR / "core" / "templates" / "default_slides" / Path(file_name).name

        slide_content = load_file(slide_file) if slide_file.exists() else f"<section class='slide'><h2>Slide {idx}</h2></section>"

        # Slide-specific substitutions
        slide_title = slide_info.get("title", f"Slajd {idx}")
        slide_titles.append(slide_title)

        slide_context = {
            **context,
            f"SLIDE_{idx}_TITLE": slide_title,
            f"SLIDE_{idx}_CATEGORY": slide_info.get("category", "PREGLED"),
            f"SLIDE_{idx}_HEADING": slide_info.get("heading", slide_title),
            f"SLIDE_{idx}_SUB": slide_info.get("sub", ""),
            f"SLIDE_{idx}_TEXT": slide_info.get("text", ""),
            f"SLIDE_{idx}_IMAGE": slide_info.get("image", "")
        }

        rendered_slide = interpolate_vars(slide_content, slide_context)
        slides_html_parts.append(rendered_slide)

        # Dot / Pill Glider Item
        is_active = " active" if idx == 1 else ""
        pad_idx = f"0{idx}" if idx < 10 else f"{idx}"
        slide_dots_parts.append(f"""        <button class="slide-dot{is_active}" data-slide-index="{idx}" onclick="goToSlide({idx})" aria-label="Slajd {idx}">
          <div class="slide-dot-fill"></div>
          <div class="slide-dot-tooltip">
            <span class="dot-tt-index">{pad_idx}</span>
            <span class="dot-tt-title">{slide_title}</span>
          </div>
        </button>""")

    # 6. Master Layout
    layout_template = load_file(ENGINE_DIR / "core" / "templates" / "layout.html")
    total_slides = len(slides_config)
    first_title = slide_titles[0] if slide_titles else "Uvod"

    master_context = {
        **context,
        "THEME_CSS": theme_css,
        "CORE_CSS": core_css,
        "CUSTOM_CSS": custom_css,
        "MOBILE_CSS": mobile_css,
        "SLIDES": "\n".join(slides_html_parts),
        "SLIDE_DOTS": "\n".join(slide_dots_parts),
        "TOTAL_SLIDES": total_slides,
        "FIRST_SLIDE_TITLE": first_title,
        "SLIDE_TITLES_JSON": json.dumps(slide_titles, ensure_ascii=False),
        "CORE_JS": core_js,
        "PROJECT_JS": project_js
    }

    final_html = interpolate_vars(layout_template, master_context)

    # 7. Write Output HTML
    output_index = deck_dir / "index.html"
    with open(output_index, 'w', encoding='utf-8') as f:
        f.write(final_html)

    elapsed = (time.time() - start_time) * 1000
    print(f"✨ Compiled [{slug}] in {elapsed:.1f}ms -> {output_index}")

    # 8. Deploy to varazdin.studio website folder if requested
    if deploy:
        web_dir = VARAZDIN_STUDIO_ROOT / "website" / slug
        os.makedirs(web_dir, exist_ok=True)
        web_index = web_dir / "index.html"
        with open(web_index, 'w', encoding='utf-8') as f:
            f.write(final_html)

        # Sync assets/slike if they exist to both assets and slike web directories
        for asset_src in [deck_dir / "assets", deck_dir / "slike"]:
            if asset_src.exists():
                for sub in ["assets", "slike"]:
                    target_sub = web_dir / sub
                    os.makedirs(target_sub, exist_ok=True)
                    os.system(f"cp -r '{asset_src}'/* '{target_sub}'/ 2>/dev/null || true")

        # Also copy any root-level PDFs
        for pdf_file in deck_dir.glob("*.pdf"):
            shutil_cmd = f"cp '{pdf_file}' '{web_dir}'/ 2>/dev/null || true"
            os.system(shutil_cmd)

        print(f"🚀 Deployed to varazdin.studio website: {web_dir}")

        # Auto-update central pitches dashboard
        dashboard_script = PONUDE_ROOT / "scripts" / "build_dashboard.py"
        if dashboard_script.exists():
            os.system(f"python3 '{dashboard_script}' --deploy >/dev/null 2>&1 || true")

    return True

def watch_deck(deck_dir, deploy=False):
    deck_dir = Path(deck_dir).resolve()
    print(f"👀 Watching for changes in {deck_dir} and deck_engine/ ... (Press Ctrl+C to stop)")
    last_mtimes = {}

    def get_files():
        files = list(deck_dir.glob("**/*")) + list(ENGINE_DIR.glob("**/*"))
        return [f for f in files if f.is_file() and not f.name.endswith(".png") and f.name != "index.html"]

    try:
        while True:
            changed = False
            for f in get_files():
                try:
                    mtime = f.stat().st_mtime
                    if f in last_mtimes and last_mtimes[f] != mtime:
                        changed = True
                    last_mtimes[f] = mtime
                except Exception:
                    pass
            if changed:
                print(f"⚡ File change detected, recompiling...")
                compile_deck(deck_dir, deploy=deploy)
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n🛑 Stopped watching.")

def main():
    parser = argparse.ArgumentParser(description="Modular Presentation Deck Builder")
    parser.add_argument("target", nargs="?", default="Meridian16_Prezentacija", help="Path to deck folder")
    parser.add_argument("--deploy", action="store_true", help="Deploy compiled deck to varazdin.studio/website/<slug>")
    parser.add_argument("--watch", action="store_true", help="Watch for file changes and recompile automatically")
    parser.add_argument("--theme", help="Override theme preset")
    parser.add_argument("--all", action="store_true", help="Compile all presentations in Ponude/")
    args = parser.parse_args()

    if args.all:
        for item in PONUDE_ROOT.iterdir():
            if item.is_dir() and (item / "deck.json").exists():
                compile_deck(item, deploy=args.deploy, theme_override=args.theme)
        return

    target_dir = Path(args.target)
    if not target_dir.is_absolute():
        target_dir = PONUDE_ROOT / target_dir

    if args.watch:
        compile_deck(target_dir, deploy=args.deploy, theme_override=args.theme)
        watch_deck(target_dir, deploy=args.deploy)
    else:
        compile_deck(target_dir, deploy=args.deploy, theme_override=args.theme)

if __name__ == '__main__':
    main()
