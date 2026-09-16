#!/Users/timonterzic/Documents/Ponude/venv/bin/python
"""
orchestrate_presentation.py — Master Orchestrator for Presentation Microsites.
Extracts offer data, builds the presentation deck, validates quality, and deploys to varazdin.studio.
"""

import sys
import os
import re
import json
import subprocess
import argparse

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
PONUDE_ROOT = "/Users/timonterzic/Documents/Ponude"
VARAZDIN_STUDIO_ROOT = "/Users/timonterzic/Documents/Studio Varazdin/varazdin.studio"

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
    print("🚀 PRESENTATION DECK ORCHESTRATOR SWARM")
    print("==================================================")

    # 1. EXTRACT OFFER DATA (Subagent: Ponude Extractor)
    print("\n[FAZA 1] Ekstrakcija ponude iz izvora...")
    fetch_cmd = [sys.executable, os.path.join(SCRIPTS_DIR, "fetch_ponuda.py"), pdf_or_json_path]
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

    # Determine slug
    if not slug:
        slug = slugify(client_name)
    print(f"✓ Identificiran slug: '{slug}'")

    # 2. GENERATE PRESENTATION DECK (Subagent: Frontend & Theme Architect)
    print(f"\n[FAZA 2] Generiranje 16:9 prezentacijskog decka (Tema: {theme})...")
    local_dir = os.path.join(PONUDE_ROOT, f"{slug.capitalize()}_Prezentacija")
    web_dir = os.path.join(VARAZDIN_STUDIO_ROOT, "website", slug)
    
    os.makedirs(local_dir, exist_ok=True)
    os.makedirs(web_dir, exist_ok=True)
    
    local_index = os.path.join(local_dir, "index.html")
    web_index = os.path.join(web_dir, "index.html")

    # Save temp JSON for generator
    temp_json = os.path.join(SCRIPTS_DIR, "temp_ponuda.json")
    with open(temp_json, "w", encoding="utf-8") as f:
        json.dump(ponuda_data, f, ensure_ascii=False, indent=2)

    gen_cmd = [
        sys.executable, os.path.join(SCRIPTS_DIR, "generate_deck.py"),
        "--json", temp_json,
        "--theme", theme,
        "--out", local_index
    ]
    subprocess.run(gen_cmd, check=True)

    # Copy to varazdin.studio website
    with open(local_index, 'r', encoding='utf-8') as f:
        content = f.read()
    with open(web_index, 'w', encoding='utf-8') as f:
        f.write(content)

    # Copy assets
    for target in [os.path.join(local_dir, "assets"), os.path.join(web_dir, "assets")]:
        os.makedirs(target, exist_ok=True)
        meridian_assets = os.path.join(PONUDE_ROOT, "Meridian16_Prezentacija", "slike")
        if os.path.exists(meridian_assets):
            subprocess.run(f"cp -r '{meridian_assets}'/* '{target}'/ 2>/dev/null || true", shell=True)

    # 3. QA AUDIT & VALIDATION (Subagent: QA Auditor)
    print("\n[FAZA 3] Pokretanje automatskog QA audita...")
    val_cmd = [sys.executable, os.path.join(SCRIPTS_DIR, "validate_deck.py"), local_index]
    val_res = subprocess.run(val_cmd, capture_output=True, text=True)
    print(val_res.stdout)
    if val_res.returncode != 0:
        print("❌ QA Audit nije prošao.")
        return False

    # 4. FINAL DEPLOYMENT SUMMARY
    print("\n==================================================")
    print("🎉 PREZENTACIJSKI MIKROSAJT USPJEŠNO GENERIRAN!")
    print("==================================================")
    print(f"📁 Lokalna mapa: {local_dir}")
    print(f"🌐 Web mapa:     {web_dir}")
    print(f"🔗 Live URL:     https://varazdin.studio/{slug}/")
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
