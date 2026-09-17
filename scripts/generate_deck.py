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

    # 3. Create Default custom.css if not present
    custom_css_path = target_dir / "custom.css"
    if not custom_css_path.exists():
        default_custom_css = """/* ======================================================== */
/* PRESENTATION CUSTOM STYLES & CANVAS UI                   */
/* ======================================================== */

.slide-meta-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-muted);
  border-bottom: 2px solid var(--text-primary);
  padding-bottom: 0.45rem;
  margin-bottom: 0.85rem;
}

.slide-meta-top .category {
  color: var(--accent-green);
  background: var(--accent-green-bg);
  padding: 2px 8px;
  border-radius: 3px;
  border: 1px solid var(--accent-green-border);
}

.punchy-narration {
  font-family: var(--font-sans);
  font-size: clamp(0.92rem, 1.15vw, 1.05rem);
  font-weight: 500;
  color: var(--text-secondary);
  line-height: 1.45;
  margin-bottom: 1rem;
}

.media-frame-bold {
  position: relative;
  background: #000;
  border: 2px solid var(--text-primary);
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 6px 6px 0px var(--text-primary);
  height: 100%;
  min-height: 280px;
}

.media-frame-bold img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

/* Slide 5 Dual Offers Grid with CanvasUI Cloth */
.dual-offers-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  height: 100%;
}

.cloth-card-container {
  position: relative;
  width: 100%;
  height: 100%;
  perspective: 1200px;
}

.cloth-card-canvas {
  position: absolute;
  top: 0;
  left: 0;
  pointer-events: none;
  z-index: 2;
}

.offer-box {
  border: 2px solid var(--text-primary);
  border-radius: 8px;
  padding: 1.25rem 1.4rem;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: 100%;
  position: relative;
  box-sizing: border-box;
  transition: opacity 0.4s ease;
}

.offer-box.cloth-active {
  opacity: 0;
}

.offer-box.essential {
  background: var(--bg-card-subtle);
  box-shadow: 4px 4px 0px var(--text-primary);
}

.offer-box.signature {
  background: #0d1815;
  color: #ffffff;
  border: 2px solid #10b981;
  box-shadow: 6px 6px 0px var(--accent-green);
}

.tier-badge {
  display: inline-block;
  font-family: var(--font-mono);
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  padding: 3px 8px;
  background: var(--text-primary);
  color: #ffffff;
  border-radius: 3px;
  margin-bottom: 0.5rem;
}

.offer-box.essential .tier-badge {
  background: var(--bg-card);
  border: 1.5px solid var(--text-primary);
  color: var(--text-primary);
}

.offer-box.signature .tier-badge {
  background: #10b981;
  color: #0d1815;
  border: 1.5px solid #ffffff;
  font-weight: 900;
}

.tier-title {
  font-family: var(--font-hero);
  font-size: 1.45rem;
  font-weight: 900;
  line-height: 1.0;
  margin-bottom: 0.4rem;
}

.offer-box.signature .tier-title {
  color: #ffffff;
}

.tier-desc {
  font-size: 0.78rem;
  line-height: 1.35;
  margin-bottom: 0.8rem;
}

.offer-box.essential .tier-desc {
  color: var(--text-secondary);
}

.offer-box.signature .tier-desc {
  color: #9cb1a8;
}

.tier-features {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.tier-features li {
  display: flex;
  align-items: baseline;
  gap: 6px;
  font-size: 0.8rem;
  line-height: 1.3;
}

.offer-box.essential .tier-features li {
  color: var(--text-primary);
}

.offer-box.signature .tier-features li {
  color: #ffffff;
}

.tier-features .bullet {
  font-weight: 900;
  font-family: var(--font-mono);
}

.offer-box.essential .tier-features .bullet {
  color: var(--accent-green);
}

.offer-box.signature .tier-features .bullet {
  color: #10b981;
}

.tier-price-row {
  border-top: 1.5px solid var(--border-color);
  padding-top: 0.65rem;
  margin-top: 0.65rem;
}

.offer-box.signature .tier-price-row {
  border-top: 1.5px dashed rgba(16, 185, 129, 0.35);
}

.tier-price-row .price-label {
  font-family: var(--font-mono);
  font-size: 0.65rem;
  font-weight: 800;
}

.offer-box.essential .tier-price-row .price-label {
  color: var(--text-muted);
}

.offer-box.signature .tier-price-row .price-label {
  color: #10b981;
}

.tier-price-row .price-val {
  font-family: var(--font-hero);
  font-size: 1.85rem;
  font-weight: 900;
  line-height: 1.1;
}

.offer-box.essential .tier-price-row .price-val {
  color: var(--text-primary);
}

.offer-box.signature .tier-price-row .price-val {
  color: #ffffff;
}

.tier-price-row .vat-text {
  font-family: var(--font-mono);
  font-size: 0.68rem;
}

.offer-box.essential .tier-price-row .vat-text {
  color: var(--text-muted);
}

.offer-box.signature .tier-price-row .vat-text {
  color: #10b981;
}

/* Slide 6 PDF Download & Contact Grid */
.pdf-download-card {
  background: var(--bg-card);
  border: 2px solid var(--text-primary);
  border-radius: 6px;
  padding: 0.75rem 0.9rem;
  margin-bottom: 0.55rem;
  box-shadow: 3px 3px 0px var(--text-primary);
}

.pdf-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.45rem;
}

.pdf-card-tag {
  font-family: var(--font-mono);
  font-size: 0.68rem;
  font-weight: 800;
  color: var(--accent-green);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  display: flex;
  align-items: center;
  gap: 5px;
}

.pdf-spec-badge {
  font-family: var(--font-mono);
  font-size: 0.64rem;
  font-weight: 700;
  color: var(--text-muted);
  background: var(--bg-card-subtle);
  padding: 1px 5px;
  border-radius: 3px;
}

.pdf-download-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
  margin-bottom: 0.5rem;
}

.btn-pdf-download {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 7px 9px;
  border: 2px solid var(--text-primary);
  border-radius: 5px;
  background: var(--bg-card-subtle);
  color: var(--text-primary);
  text-decoration: none;
  box-shadow: 2px 2px 0px var(--text-primary);
  transition: all 0.15s ease;
}

.btn-pdf-download:hover {
  transform: translate(-2px, -2px) !important;
  box-shadow: 4px 4px 0px var(--text-primary) !important;
  background: var(--accent-green-bg);
}

.btn-pdf-download.signature-dl {
  border: 2px solid var(--accent-green-bright);
  border-radius: 5px;
  background: #0a0e12;
  color: #ffffff;
  box-shadow: 2px 2px 0px var(--accent-green);
}

.btn-pdf-download.signature-dl:hover {
  transform: translate(-2px, -2px) !important;
  box-shadow: 5px 5px 0px var(--accent-green) !important;
  background: #000000;
}

.btn-dl-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.dl-quote-num {
  font-family: var(--font-mono);
  font-size: 0.64rem;
  font-weight: 800;
  color: var(--accent-green);
}

.btn-pdf-download.signature-dl .dl-quote-num {
  color: #7de095;
}

.dl-quote-title {
  font-family: var(--font-hero);
  font-size: 0.95rem;
  font-weight: 900;
  line-height: 1.1;
  color: var(--text-primary);
}

.btn-pdf-download.signature-dl .dl-quote-title {
  color: #ffffff;
}

.dl-quote-sub {
  font-size: 0.66rem;
  color: var(--text-secondary);
  font-weight: 600;
}

.btn-pdf-download.signature-dl .dl-quote-sub {
  color: #9cb3a2;
}

.pdf-auth-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-top: 1px dashed var(--border-color);
  padding-top: 0.6rem;
}

.schedule-text {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  color: var(--text-secondary);
}

.btn-auth-action {
  background: var(--text-primary);
  color: #ffffff;
  padding: 6px 14px;
  border-radius: 4px;
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 800;
  text-decoration: none;
  transition: all 0.2s;
}

.btn-auth-action:hover {
  background: var(--accent-green);
}
"""
        with open(custom_css_path, "w", encoding="utf-8") as f:
            f.write(default_custom_css)

    # 4. Create Default custom.js (WebGL Cloth Texture Renderers) if not present
    custom_js_path = target_dir / "custom.js"
    if not custom_js_path.exists():
        default_custom_js = f"""// Presentation Custom Scripts & WebGL Cloth Card Texture Renderers

function roundRect(ctx, x, y, width, height, radius, fill, stroke) {{
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + width - radius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
  ctx.lineTo(x + width, y + height - radius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  ctx.lineTo(x + radius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
  if (fill) ctx.fill();
  if (stroke) ctx.stroke();
}}

function wrapText(ctx, text, x, y, maxWidth, lineHeight) {{
  const words = text.split(' ');
  let line = '';
  for (let n = 0; n < words.length; n++) {{
    const testLine = line + words[n] + ' ';
    const metrics = ctx.measureText(testLine);
    if (metrics.width > maxWidth && n > 0) {{
      ctx.fillText(line, x, y);
      line = words[n] + ' ';
      y += lineHeight;
    }} else {{
      line = testLine;
    }}
  }}
  ctx.fillText(line, x, y);
}}

function renderCardTextureA(canvas, w, h, dpr) {{
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  ctx.fillStyle = '#ffffff';
  ctx.strokeStyle = '#111518';
  ctx.lineWidth = 2;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  ctx.fillStyle = '#111518';
  roundRect(ctx, 22, 20, 195, 24, 4, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA A • STANDARD', 30, 36);

  ctx.fillStyle = '#111518';
  ctx.font = '900 20px "Syne", sans-serif';
  ctx.fillText('STANDARDNI', 22, 65);
  ctx.fillText('PAKET', 22, 86);

  ctx.fillStyle = '#3b454e';
  ctx.font = '500 12px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Filmsko snimanje, 4K Master, dinamični FPV kadrovi i vertikale za mreže.', 22, 105, w - 44, 16);

  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const features = [
    ['1 Master Filmski Rez (4K)', ' (16:9 Cinema Master)'],
    ['3x Vertikalna Video Reelsa', ' (LinkedIn & Instagram)'],
    ['FPV Zračne Sekvence', ' + Puni tlocrt lokacije'],
    ['Predprodukcija & Scenarij', ' (Knjiga snimanja i priprema)'],
    ['100% Prijenos Autorskih Prava', ' klijentu']
  ];

  const startY = 162;
  const featSpacing = 26;

  features.forEach(([bold, norm], idx) => {{
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#11421f';
    ctx.font = '800 13px "JetBrains Mono", monospace';
    ctx.fillText('✓', 24, featY);

    ctx.fillStyle = '#111518';
    ctx.font = '700 12px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#3b454e';
    ctx.font = '500 12px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  }});

  const boxH = 72;
  const boxY = h - boxH - 18;

  ctx.fillStyle = '#f4efe4';
  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#79828a';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('UKUPNO ULAGANJE (OPCIJA A)', 28, boxY + 20);

  ctx.fillStyle = '#111518';
  ctx.font = '900 26px "Syne", sans-serif';
  ctx.fillText('{total_price}', 28, boxY + 46);

  ctx.fillStyle = '#79828a';
  ctx.font = '600 9.5px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('Oslobođeno PDV-a (Čl. 90. st. 2) • 0% PDV', 28, boxY + 62);
}}

function renderCardTextureB(canvas, w, h, dpr) {{
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  ctx.fillStyle = '#0d1815';
  ctx.strokeStyle = '#10b981';
  ctx.lineWidth = 2.5;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  const grad = ctx.createRadialGradient(w - 60, 40, 10, w - 60, 40, 260);
  grad.addColorStop(0, 'rgba(16, 185, 129, 0.16)');
  grad.addColorStop(1, 'rgba(13, 24, 21, 0)');
  ctx.fillStyle = grad;
  roundRect(ctx, 2, 2, w - 4, h - 4, 11, true, false);

  ctx.fillStyle = '#10b981';
  roundRect(ctx, 22, 20, 275, 24, 4, true, false);
  ctx.fillStyle = '#0d1815';
  ctx.font = '900 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA B • FULL VISION (PREPORUKA)', 30, 36);

  ctx.fillStyle = '#ffffff';
  ctx.font = '900 20px "Syne", sans-serif';
  ctx.fillText('FULL VISION', 22, 65);
  ctx.fillText('PAKET ★', 22, 86);

  ctx.fillStyle = '#9cb1a8';
  ctx.font = '500 12px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Cjelovita filmska kampanja: teaser trailer, intervjui, audio dizajn i neograničena prava.', 22, 105, w - 44, 16);

  ctx.strokeStyle = '#1d362a';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const boxH = 72;
  const boxY = h - boxH - 18;

  const features = [
    ['Hero Film 4K + 60s Teaser Trailer', ' (Filmski Master)'],
    ['Intervjui s vodstvom + Teleprompter', ' (2 Kamere & Rasvjeta)'],
    ['4x Vertikalna Video Reelsa', ' (Društvene Mreže)'],
    ['Cjelovit FPV Paket sa Spotterom', ' + Test rute'],
    ['Autorski Sound Design & SFX', ' + Color Grade'],
    ['100% Prijenos Autorskih Prava', ' klijentu']
  ];

  const startY = 158;
  const availH = boxY - 14 - startY;
  const featSpacing = availH / (features.length - 1);

  features.forEach(([bold, norm], idx) => {{
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#10b981';
    ctx.font = '800 13px "JetBrains Mono", monospace';
    ctx.fillText('★', 24, featY);

    ctx.fillStyle = '#ffffff';
    ctx.font = '700 11.5px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#9cb1a8';
    ctx.font = '500 11.5px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  }});

  ctx.fillStyle = '#13231e';
  ctx.strokeStyle = '#10b981';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#10b981';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('UKUPNO ULAGANJE (OPCIJA B)', 28, boxY + 20);

  ctx.fillStyle = '#ffffff';
  ctx.font = '900 26px "Syne", sans-serif';
  ctx.fillText('{total_price}', 28, boxY + 46);

  ctx.fillStyle = '#10b981';
  ctx.font = '600 9.5px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('Oslobođeno PDV-a (Čl. 90. st. 2) • 0% PDV', 28, boxY + 62);
}}

window.customClothRenderers = {{
  0: renderCardTextureA,
  1: renderCardTextureB
}};
window.renderCardTextureA = renderCardTextureA;
window.renderCardTextureB = renderCardTextureB;

if (window.initClothCardPhysics) {{
  window.initClothCardPhysics(window.customClothRenderers);
}}
"""
        with open(custom_js_path, "w", encoding="utf-8") as f:
            f.write(default_custom_js)

    # 5. Compile Deck
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

