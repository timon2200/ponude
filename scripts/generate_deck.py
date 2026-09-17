#!/Users/timonterzic/Documents/Ponude/venv/bin/python
"""
generate_deck.py — Modular Presentation Deck Generator & Scaffolder
Creates an agent-first modular presentation folder (deck.json + slides/*.html) from offer data and compiles it.
"""

import sys
import os
import json
import argparse
import shutil
from pathlib import Path

# Add scripts dir to python path to import build_deck
SCRIPTS_DIR = Path(__file__).resolve().parent
PONUDE_ROOT = SCRIPTS_DIR.parent
sys.path.insert(0, str(SCRIPTS_DIR))

from build_deck import compile_deck, ENGINE_DIR

def generate_presentation_workspace(offer_data, theme="eco-utility", target_dir=None, deploy=False):
    client_name = offer_data.get("client", {}).get("name", "Klijent")
    offer_num = offer_data.get("broj", "1")
    offer_date = offer_data.get("datum", "2026.")
    total_price = offer_data.get("total", "0,00 EUR")
    items = offer_data.get("items", [])

    slug = offer_data.get("slug", client_name.lower().replace(" ", "-").replace("č", "c").replace("ć", "c").replace("ž", "z").replace("š", "s").replace("đ", "dj"))

    if not target_dir:
        target_dir = PONUDE_ROOT / f"{slug.capitalize()}_Prezentacija"
    else:
        target_dir = Path(target_dir)

    target_dir.mkdir(parents=True, exist_ok=True)
    slides_dir = target_dir / "slides"
    slides_dir.mkdir(parents=True, exist_ok=True)
    assets_dir = target_dir / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)

    # 1. Generate deck.json manifest
    deck_manifest = {
        "title": f"{client_name} — Video Pitch | Studio Varaždin",
        "client_name": client_name,
        "slug": slug,
        "theme": theme,
        "header_tag": f"SLUŽBENA PONUDA BR. {offer_num} // {offer_date}",
        "contact_email": "timon.terzic@gmail.com",
        "total": total_price,
        "pdf_path": f"assets/Ponuda_{slug}.pdf",
        "issuer": {
            "name": "STUDIO VARAŽDIN",
            "owner": "Vl. Jasenka Martinčević",
            "address": "S. Vraza 10, Varaždin",
            "oib": "63287352089",
            "partner": "Lotus RC"
        },
        "slides": [
            {
                "id": 1,
                "file": "slides/01_hero.html",
                "title": "Strateška Vizija",
                "category": "Koncepcija & Pitch",
                "heading": f"VIZUALNA PREKRETNICA <br><span class=\"outline-text\">ZA {client_name.upper()}</span>",
                "sub": "Kinematografski video sustav koji komunicira stvarne rezultate i vrijednost.",
                "text": f"Ovaj projekt ne radi generičke video formate. Spajamo preciznu filmsku optiku na tlu s dinamičnim FPV sekvencama u zraku kako bismo stvorili cjelovit vizualni identitet prilagođen ciljevima {client_name}.",
                "image": "assets/01_hero.jpg"
            },
            {
                "id": 2,
                "file": "slides/02_concept.html",
                "title": "Kreativna Direkcija",
                "category": "Kreativna Direkcija",
                "heading": "DOKUMENTIRANJE VAŽNOSTI <br><span class=\"outline-text\">KROZ DVA POGLEDA</span>",
                "sub": "Od mikroskopskih detalja i ljudskog rada do monumentalnog tlocrta lokacije.",
                "text": "Filmski kontrast između pažljivo kadriranih procesa i širokih zračnih perspektiva stvara ritam koji drži pažnju gledatelja. Svaki kadar ima točno definiranu svrhu u narativu.",
                "image": "assets/02_concept.jpg"
            },
            {
                "id": 3,
                "file": "slides/03_formats.html",
                "title": "Formati & Distribucija",
                "category": "Ekosustav Isporuke",
                "heading": "1 MASTER FILMSKI REZ + <br><span class=\"outline-text\">3 VERTIKALE ZA MREŽE</span>",
                "sub": "Jedno produkcijsko snimanje donosi cjelovit paket formata za sve digitalne kanale."
            },
            {
                "id": 4,
                "file": "slides/04_production.html",
                "title": "Scenarij & Metodologija",
                "category": "Kadrovi & Stil",
                "heading": "STRUKTURA KROZ <br><span class=\"outline-text\">TRI FILMSKA ČINA</span>",
                "sub": "Jasna narativna linija od uvodnog konteksta do ključnih poruka za javnost i partnere."
            },
            {
                "id": 5,
                "file": "slides/05_offer.html",
                "title": "Komercijalna Ponuda",
                "category": f"Ponuda br. {offer_num} • {offer_date}",
                "heading": "TRANSPARENTNA <br><span class=\"outline-text\">RAŠČLAMBA ULAGANJA</span>",
                "sub": "Puni opseg angažmana i definirane isporuke."
            },
            {
                "id": 6,
                "file": "slides/06_auth.html",
                "title": "Autorizacija & Partnerstvo",
                "category": "Partnerstvo & Rokovi",
                "heading": "SPREMNI SMO ZA <br><span class=\"outline-text\">POČETAK PROJEKTA</span>",
                "sub": "Garantirani rokovi isporuke unutar 14 dana od snimanja."
            }
        ]
    }

    manifest_path = target_dir / "deck.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(deck_manifest, f, ensure_ascii=False, indent=2)

    # 2. Copy/Create Modular Slide Files
    default_slides_dir = ENGINE_DIR / "core" / "templates" / "default_slides"
    for s_file in default_slides_dir.glob("*.html"):
        dest_file = slides_dir / s_file.name
        if not dest_file.exists():
            shutil.copy(s_file, dest_file)

    # 3. Generate Offer Rows HTML for Slide 5
    offer_rows_html = []
    for item in items:
        title = item.get("title", "")
        desc = item.get("description", "")
        price = item.get("price", "")
        offer_rows_html.append(f"""        <div class="offer-item-row" style="background:var(--bg-card); border:2px solid var(--border-dark); border-radius:6px; padding:0.75rem 1rem; display:flex; justify-content:space-between; align-items:center; margin-bottom:0.6rem;">
          <div>
            <div class="offer-item-title" style="font-family:var(--font-hero); font-size:1rem; font-weight:800;">{title}</div>
            <div class="offer-item-desc" style="font-size:0.75rem; color:var(--text-secondary); margin-top:2px;">{desc}</div>
          </div>
          <div class="offer-item-price" style="font-family:var(--font-mono); font-weight:800; font-size:1rem; margin-left:1rem; white-space:nowrap;">{price}</div>
        </div>""")
    
    slide5_custom = f"""<section class="slide" data-slide="5" data-index="5" data-title="Komercijalna Ponuda">
  <div>
    <div class="category-badge-row">
      <span class="category-badge">Ponuda br. {offer_num} • {offer_date}</span>
      <span class="meta-coords">STRUKTURA ULAGANJA // {client_name.upper()}</span>
    </div>
    <h2 class="quote-title">TRANSPARENTNA <br><span class="outline-text">RAŠČLAMBA ULAGANJA</span></h2>
    <p class="quote-sub">Puni opseg angažmana i isporuka.</p>
  </div>

  <div class="offer-package-grid" style="display:grid; grid-template-columns:1.2fr 0.8fr; gap:1.5rem; margin-top:0.75rem;">
    <div class="offer-main-card">
{chr(10).join(offer_rows_html)}
    </div>
    <div class="offer-total-box" style="background:var(--accent-green-bg); border:2px solid var(--accent-green); border-radius:6px; padding:1.25rem; display:flex; flex-direction:column; justify-content:space-between; box-shadow:4px 4px 0px var(--accent-green);">
      <div class="offer-total-header">
        <span style="font-family:var(--font-mono); font-size:0.8rem; font-weight:800; color:var(--accent-green); display:block;">UKUPNO ZA PLAĆANJE</span>
        <span class="price" style="font-family:var(--font-hero); font-size:2.2rem; font-weight:900; color:var(--accent-green);">{total_price}</span>
      </div>
      <div style="font-family:var(--font-mono); font-size:0.72rem; color:var(--text-secondary); line-height:1.45; border-top:1px dashed var(--accent-green-border); padding-top:0.6rem; margin-top:0.6rem;">
        • Oslobođeno PDV-a temeljem članka 90. st. 2 Zakona o PDV-u.<br>
        • Neograničena autorska prava korištenja.<br>
        • Rok valjanosti ponude: 30 dana.
      </div>
    </div>
  </div>
</section>"""
    
    with open(slides_dir / "05_offer.html", "w", encoding="utf-8") as f:
        f.write(slide5_custom)

    # 4. Compile Deck
    compile_deck(target_dir, deploy=deploy)
    return target_dir

def main():
    parser = argparse.ArgumentParser(description="Generate presentation microsite from offer data")
    parser.add_argument("--json", help="Path to offer JSON file")
    parser.add_argument("--theme", default="eco-utility", choices=["eco-utility", "editorial-canvas", "dark-luxury"], help="Theme preset")
    parser.add_argument("--out-dir", help="Output directory for modular deck")
    parser.add_argument("--deploy", action="store_true", help="Deploy to varazdin.studio website")
    args = parser.parse_args()

    if args.json and os.path.exists(args.json):
        with open(args.json, 'r', encoding='utf-8') as f:
            data = json.load(f)
    else:
        # Default mock data
        data = {
            "client": {"name": "Grad Varaždin"},
            "broj": "17",
            "datum": "11.09.2026.",
            "total": "4.800,00 EUR",
            "items": [
                {"index": 1, "title": "Predprodukcija", "description": "Knjiga snimanja i priprema", "price": "1.000,00 €"},
                {"index": 2, "title": "Produkcija", "description": "4K snimanje na ciklorami", "price": "2.000,00 €"},
                {"index": 3, "title": "Postprodukcija", "description": "Montaža i voiceover", "price": "1.800,00 €"}
            ]
        }

    generate_presentation_workspace(data, theme=args.theme, target_dir=args.out_dir, deploy=args.deploy)

if __name__ == '__main__':
    main()
