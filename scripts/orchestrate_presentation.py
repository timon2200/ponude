#!/Users/timonterzic/Documents/Ponude/venv/bin/python
"""
orchestrate_presentation.py — Master Orchestrator for Presentation Microsites.
Extracts offer data, scaffolds modular presentation workspace, builds zero-dependency bundle, validates quality, and deploys to varazdin.studio.
"""

import sys
import os
import re
import json
import subprocess
import argparse
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
PONUDE_ROOT = SCRIPTS_DIR.parent
VARAZDIN_STUDIO_ROOT = Path("/Users/timonterzic/Documents/Studio Varazdin/varazdin.studio")
VENV_PYTHON = PONUDE_ROOT / "venv" / "bin" / "python"
PYTHON_BIN = str(VENV_PYTHON) if VENV_PYTHON.exists() else sys.executable

def slugify(text):
    text = text.lower().strip()
    text = re.sub(r'[čć]', 'c', text)
    text = re.sub(r'ž', 'z', text)
    text = re.sub(r'š', 's', text)
    text = re.sub(r'đ', 'dj', text)
    text = re.sub(r'[^a-z0-9\-]+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')

def orchestrate(pdf_or_json_path, slug=None, theme="eco-utility"):
    print("==================================================")
    print("🚀 MODULAR PRESENTATION DECK ORCHESTRATOR")
    print("==================================================")

    # 1. EXTRACT OFFER DATA (Subagent: Ponude Extractor)
    print("\n[FAZA 1] Ekstrakcija ponude iz izvora...")
    fetch_cmd = [PYTHON_BIN, str(SCRIPTS_DIR / "fetch_ponuda.py"), pdf_or_json_path]
    res = subprocess.run(fetch_cmd, capture_output=True, text=True)
    if res.returncode != 0 or not res.stdout.strip():
        print(f"❌ Neuspjela ekstrakcija: {res.stderr}")
        return False

    try:
        ponuda_data = json.loads(res.stdout)
    except Exception as e:
        print(f"❌ Greška pri parsiranju JSON ponude: {e}")
        return False

    client_name = ponuda_data.get("client", {}).get("name", "Klijent")
    print(f"✓ Uspješno dohvaćena ponuda za klijenta: {client_name}")
    print(f"  Iznos: {ponuda_data.get('total')} | Stavaka: {len(ponuda_data.get('items', []))}")

    if not slug:
        slug = slugify(client_name)
    ponuda_data["slug"] = slug
    print(f"✓ Identificiran slug: '{slug}'")

    # 2. GENERATE & COMPILE MODULAR PRESENTATION DECK
    print(f"\n[FAZA 2] Generiranje modularnog prezentacijskog workspacea (Tema: {theme})...")
    local_dir = PONUDE_ROOT / f"{slug.capitalize()}_Prezentacija"
    web_dir = VARAZDIN_STUDIO_ROOT / "website" / slug
    
    local_dir.mkdir(parents=True, exist_ok=True)
    web_dir.mkdir(parents=True, exist_ok=True)

    temp_json = SCRIPTS_DIR / "temp_ponuda.json"
    with open(temp_json, "w", encoding="utf-8") as f:
        json.dump(ponuda_data, f, ensure_ascii=False, indent=2)

    gen_cmd = [
        PYTHON_BIN, str(SCRIPTS_DIR / "generate_deck.py"),
        "--json", str(temp_json),
        "--theme", theme,
        "--out-dir", str(local_dir),
        "--deploy"
    ]
    subprocess.run(gen_cmd, check=True)

    local_index = local_dir / "index.html"

    # 3. QA AUDIT & VALIDATION (Subagent: QA Auditor)
    print("\n[FAZA 3] Pokretanje automatskog QA audita...")
    val_cmd = [PYTHON_BIN, str(SCRIPTS_DIR / "validate_deck.py"), str(local_index)]
    val_res = subprocess.run(val_cmd, capture_output=True, text=True)
    print(val_res.stdout)
    if val_res.returncode != 0:
        print("❌ QA Audit nije prošao.")
        return False

    # 4. FINAL DEPLOYMENT SUMMARY
    print("\n==================================================")
    print("🎉 MODULARNI PREZENTACIJSKI MIKROSAJT USPJEŠNO GENERIRAN!")
    print("==================================================")
    print(f"📁 Modularni workspace: {local_dir}")
    print(f"   ├── deck.json       (Konfiguracija, cijene, kontakt)")
    print(f"   └── slides/         (Pojedinačni HTML predlošci slajdova 1–6)")
    print(f"🌐 Web deployment:    {web_dir}")
    print(f"🔗 Live URL:          https://varazdin.studio/{slug}/")
    print("Za objavu na webu pokrenite `git push` u repozitoriju `varazdin.studio`.")
    return True

def main():
    parser = argparse.ArgumentParser(description="Orchestrate presentation microsite creation")
    parser.add_argument("source", help="Path to PDF offer or JSON file")
    parser.add_argument("--slug", help="Custom URL slug for the presentation")
    parser.add_argument("--theme", default="eco-utility", choices=["eco-utility", "editorial-canvas", "dark-luxury"], help="Theme preset")
    args = parser.parse_args()

    orchestrate(args.source, slug=args.slug, theme=args.theme)

if __name__ == '__main__':
    main()
