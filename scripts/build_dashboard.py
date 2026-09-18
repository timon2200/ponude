#!/usr/bin/env python3
"""
build_dashboard.py — Central Web Pitches Dashboard Generator
Studio Varaždin (varazdin.studio/ponude)

Meridian 16 Identity:
- Identical deck-header navigation bar (brand-mark with Studio Varaždin font & tag, sound & fullscreen controls)
- Big bold quote-title with outline-text
- Clean search box with 6px solid shadow
- video-card-crazy grid with Full-Card CanvasUI 4x4 Bayer Dither hover lens (excluding buttons)
- Interactive Card-Fan Status Switcher (POSLANO / ODOBRENO [maslinasto zeleni] / ODBIJENO [trešnja crveni]) with fluid card spread animation
- Direct click-to-open on thumbnails and titles
- Price hover tooltip for package options
"""

import sys
import os
import json
import re
import shutil
import time
import argparse
from pathlib import Path

PONUDE_ROOT = Path("/Users/timonterzic/Documents/Ponude")
VARAZDIN_STUDIO_ROOT = Path("/Users/timonterzic/Documents/Studio Varazdin/varazdin.studio")
OUTPUT_LOCAL_DIR = PONUDE_ROOT / "dashboard"
OUTPUT_WEB_DIR = VARAZDIN_STUDIO_ROOT / "website" / "ponude"

DECK_CATALOG = {
    "meridian16": {
        "slug": "meridian16",
        "folder": "Meridian16_Prezentacija",
        "client": "Meridian 16 Business Park",
        "title": "Meridian 16 — Cinematic Film Pitch",
        "category": "Industrija & Parkovi",
        "sector_id": "industry",
        "tagline": "1.000.000 m² vodećeg poslovno-logističkog parka. Master 4K film i modularne vertikale za društvene mreže.",
        "price_display": "€ 13.000 — € 17.000",
        "numeric_val": 17000,
        "options_summary": "Opcija A: € 13.000 · Opcija B Signature: € 17.000",
        "badge": "SIGNATURE PACK",
        "badge_color": "gold",
        "is_signature": True,
        "theme": "editorial-canvas",
        "hero_rel": "slike/meridian_fpv_interior_flow.jpg",
        "pdf_rel": "Quote_No15_OptionB_17000.pdf",
        "date": "2026-09"
    },
    "komunalni-projekt": {
        "slug": "komunalni-projekt",
        "folder": "Komunalni_Prezentacija",
        "client": "Grad Varaždin & Čistoća d.o.o.",
        "title": "7 KILOGRAMA — Edukativni Video Sustav",
        "category": "Ekologija & Javni sektor",
        "sector_id": "eco",
        "tagline": "7 kg hrane po stanovniku. Modularni video sustav za razvrstavanje otpada i novu sortirnicu.",
        "price_display": "4.800,00 €",
        "numeric_val": 4800,
        "options_summary": "Kompletan edukativni video sustav (4 epizode + reels)",
        "badge": "JAVNI SEKTOR",
        "badge_color": "green",
        "is_signature": False,
        "theme": "eco-utility",
        "hero_rel": "assets/01_Studio_Pad_Otpada_Hook.jpg",
        "pdf_rel": "assets/Ponuda_Grad_Varazdin_Cistoca_Br17.pdf",
        "date": "2026-09"
    },
    "cakovec": {
        "slug": "cakovec",
        "folder": "Cakovec_Prezentacija",
        "client": "Grad Čakovec & Međimurska županija",
        "title": "101 MILIJUN — Kronika međimurskog gradilišta",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "heritage",
        "tagline": "101 milijun eura investicija. Kronika povijesnog zamašnjaka Čakovca kroz 4K FPV i dokumentarnu formu.",
        "price_display": "14.000,00 € — 17.500,00 €",
        "numeric_val": 17500,
        "options_summary": "Opcija A: 14.000,00 € · Opcija B FPV Spektakl: 17.500,00 €",
        "badge": "INFRASTRUKTURA",
        "badge_color": "green",
        "is_signature": False,
        "theme": "eco-utility",
        "hero_rel": "assets/01_cakovec_skola_fpv.jpg",
        "pdf_rel": "assets/Ponuda_Grad_Cakovec_Medimurje_2026_CK_03.pdf",
        "date": "2026-09"
    },
    "djurdjevac": {
        "slug": "djurdjevac",
        "folder": "Djurdjevac_Prezentacija",
        "client": "Grad Đurđevac & TZ Đurđevac",
        "title": "OPSADA WASSERBURGA 1552. — Picokijada & Novo jezero",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "heritage",
        "tagline": "Novo jezero Starog grada, Picokijada i Đurđevački peski. Kinematografski prikaz Wasserburga.",
        "price_display": "16.000,00 € — 20.000,00 €",
        "numeric_val": 20000,
        "options_summary": "Opcija A: 16.000,00 € · Opcija B Noćni Spektakl: 20.000,00 €",
        "badge": "TURIZAM & SPEKTAKL",
        "badge_color": "gold",
        "is_signature": True,
        "theme": "dark-luxury",
        "hero_rel": "assets/01_djurdjevac_wasserburg_1552.jpg",
        "pdf_rel": "assets/Ponuda_Djurdjevac_Wasserburg_2026_DJ_02.pdf",
        "date": "2026-09"
    },
    "krapina": {
        "slug": "krapina",
        "folder": "Krapina_Prezentacija",
        "client": "Krapinsko-zagorska županija & Grad Krapina",
        "title": "TRI KULE NAD KRAPINČICOM — Filmska Produkcija",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "heritage",
        "tagline": "Mit o Čehu, Lehu i Mehu, Hušnjakovo i tri utvrde. Spoj pretpovijesti i FPV kinematografije.",
        "price_display": "16.000,00 €",
        "numeric_val": 16000,
        "options_summary": "Master 4K film (7 min) + 3 vertikalna formata za muzeje",
        "badge": "KULTURNA BAŠTINA",
        "badge_color": "green",
        "is_signature": False,
        "theme": "eco-utility",
        "hero_rel": "assets/01_krapina_ceh_leh_meh.jpg",
        "pdf_rel": "assets/Ponuda_Krapina_Tri_Kule_2026_KR_05.pdf",
        "date": "2026-09"
    },
    "samobor": {
        "slug": "samobor",
        "folder": "Samobor_Prezentacija",
        "client": "Grad Samobor & TZ Samobor",
        "title": "VRUDNIK & Samobor 2026 — Kinematografski Pitch",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "heritage",
        "tagline": "Živi rov saskih rudara iz 1540., Tepec i Bela IV. Kinematografski i VR postavi umjesto statičnih panoa.",
        "price_display": "24.000,00 € — 30.000,00 €",
        "numeric_val": 30000,
        "options_summary": "Opcija A: 24.000,00 € · Opcija B VR MetaQuest Kiosk: 30.000,00 €",
        "badge": "VR & FILM",
        "badge_color": "gold",
        "is_signature": True,
        "theme": "eco-utility",
        "hero_rel": "assets/01_vrudnik_rov_kokel_1540.jpg",
        "pdf_rel": "assets/Ponuda_Grad_Samobor_2026_SA_04.pdf",
        "date": "2026-09"
    },
    "ogulin": {
        "slug": "ogulin",
        "folder": "Ogulin_Prezentacija",
        "client": "Grad Ogulin & TZ Ogulin",
        "title": "KORIJENI PONORA — Zavičaj bajki & Frankopani",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "heritage",
        "tagline": "Đulin ponor, Frankopanski kaštel i Klek. Pripovijedanje temeljeno na zavičaju bajki Ivane Brlić-Mažuranić.",
        "price_display": "14.500,00 € — 24.000,00 €",
        "numeric_val": 24000,
        "options_summary": "Opcija A: 14.500,00 € · Opcija B Prozor u prošlost: 24.000,00 €",
        "badge": "DESTINACIJSKI FILM",
        "badge_color": "green",
        "is_signature": False,
        "theme": "eco-utility",
        "hero_rel": "assets/dvorac_ogulin.webp",
        "pdf_rel": "assets/Ponuda_ogulin.pdf",
        "date": "2026-09"
    },
    "kb-pogon": {
        "slug": "kb-pogon",
        "folder": "Kb-pogon_Prezentacija",
        "client": "KB d.o.o. Pogon",
        "title": "KB D.O.O. — Industrijski Video Pitch",
        "category": "Industrija & Parkovi",
        "sector_id": "industry",
        "tagline": "Proizvodni pogoni, robotske ćelije i inženjerska preciznost. Autorski industrijski video i FPV prolet.",
        "price_display": "5.800,00 €",
        "numeric_val": 5800,
        "options_summary": "Industrijski video paket + FPV snimanje proizvodnje",
        "badge": "INDUSTRIJA",
        "badge_color": "green",
        "is_signature": False,
        "theme": "eco-utility",
        "hero_rel": "assets/meridian_fpv_interior_flow.jpg",
        "pdf_rel": "assets/Ponuda_KB_Pogon_Br16.pdf",
        "date": "2026-09"
    },
    "zagrebacka-zupanija": {
        "slug": "zagrebacka-zupanija",
        "folder": "Zagrebacka_Prezentacija",
        "client": "Zagrebačka županija",
        "title": "PRSTEN KOJI POKREĆE — Kinematografska kronika",
        "category": "Županije & Regije",
        "sector_id": "heritage",
        "tagline": "110+ mil. € vodovod Zagreb istok, 15 škola i logistički megakompleksi. Master 4K film za Dan županije (17. srpnja).",
        "price_display": "18.000,00 € — 22.000,00 €",
        "numeric_val": 22000,
        "options_summary": "Opcija A: 18.000,00 € · Opcija B Signature: 22.000,00 €",
        "badge": "FLAGSHIP ŽUPANIJA",
        "badge_color": "gold",
        "is_signature": True,
        "theme": "editorial-canvas",
        "hero_rel": "assets/hero_landscape.jpg",
        "pdf_rel": "assets/Ponuda_Zagrebacka_Zupanija_OpcijaB_22000.pdf",
        "date": "2026-09"
    },
    "koprivnica": {
        "slug": "koprivnica",
        "folder": "Koprivnica_Prezentacija",
        "client": "Koprivničko-križevačka županija & Grad Koprivnica",
        "title": "ZEMLJA KOJA GRADI — Filmska kronika",
        "category": "Županije & Regije",
        "sector_id": "heritage",
        "tagline": "5 sportskih dvorana, CEKOM labovi i nova OŠ Koprivnički Ivanec. Master 4K film za Dan županije (13. travnja) i Dan grada.",
        "price_display": "14.500,00 € — 18.500,00 €",
        "numeric_val": 18500,
        "options_summary": "Opcija A: 14.500,00 € · Opcija B Signature: 18.500,00 €",
        "badge": "INFRASTRUKTURA",
        "badge_color": "green",
        "is_signature": False,
        "theme": "eco-utility",
        "hero_rel": "assets/01_koprivnica_dvorane.jpg",
        "pdf_rel": "assets/Ponuda_Koprivnica_Zemlja_Gradi_2026_KK_06.pdf",
        "date": "2026-09"
    },
    "bjelovar": {
        "slug": "bjelovar",
        "folder": "Bjelovar_Prezentacija",
        "client": "Grad Bjelovar & Bjelovarsko-bilogorska županija",
        "title": "WELLNESS IZ DUBINE — Geotermalni Bjelovar",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "eco",
        "tagline": "50+ mil. € Terme Bjelovar, bušotina Korenovo GT-1 i nova bolnica. Master 4K film za Dan grada (29. rujna) i Dan županije.",
        "price_display": "14.000,00 € — 18.000,00 €",
        "numeric_val": 18000,
        "options_summary": "Opcija A: 14.000,00 € · Opcija B Signature: 18.000,00 €",
        "badge": "GEOTERMALNA ENERGIJA",
        "badge_color": "gold",
        "is_signature": True,
        "theme": "eco-utility",
        "hero_rel": "assets/01_bjelovar_terme_korenovo.jpg",
        "pdf_rel": "assets/Ponuda_Grad_Bjelovar_Terme_2026_BJ_07.pdf",
        "date": "2026-09"
    },
    "sveta-nedelja": {
        "slug": "sveta-nedelja",
        "folder": "SvetaNedelja_Prezentacija",
        "client": "Grad Sveta Nedelja & Zagrebačka županija",
        "title": "DVORAC I KAMPUS — Kinematografski film",
        "category": "Gradovi & Kulturna baština",
        "sector_id": "industry",
        "tagline": "200 mil. € Rimac Campus vs 17 mil. € obnovljeni dvorac Erdödy. Master 4K film za Dan grada (lipanj) i Dan županije.",
        "price_display": "15.000,00 € — 19.500,00 €",
        "numeric_val": 19500,
        "options_summary": "Opcija A: 15.000,00 € · Opcija B Signature: 19.500,00 €",
        "badge": "INOVACIJE & BAŠTINA",
        "badge_color": "green",
        "is_signature": False,
        "theme": "editorial-canvas",
        "hero_rel": "assets/sveta_nedelja_hero.jpg",
        "pdf_rel": "assets/Ponuda_Sveta_Nedelja_OpcijaB_19500.pdf",
        "date": "2026-09"
    }
}

def scan_decks():
    """Scans all presentation directories and combines with curated catalog."""
    decks = []
    
    for slug, meta in DECK_CATALOG.items():
        folder_path = PONUDE_ROOT / meta["folder"]
        deck_json_path = folder_path / "deck.json"
        
        if deck_json_path.exists():
            try:
                with open(deck_json_path, 'r', encoding='utf-8') as f:
                    dj = json.load(f)
                    if "client_name" in dj:
                        meta["client"] = dj["client_name"]
                    if "title" in dj:
                        meta["title"] = dj["title"]
                    if "total" in dj:
                        meta["price_display"] = dj["total"]
                    if "theme" in dj:
                        meta["theme"] = dj["theme"]
                    if "pdf_path" in dj:
                        meta["pdf_rel"] = dj["pdf_path"]
            except Exception as e:
                print(f"⚠️ Warning reading {deck_json_path}: {e}")
                
        # Resolve hero image
        hero_file = folder_path / meta["hero_rel"]
        if not hero_file.exists():
            for sub in ["assets", "slike"]:
                cand_dir = folder_path / sub
                if cand_dir.exists():
                    cands = [f for f in cand_dir.iterdir() if f.suffix.lower() in [".jpg", ".jpeg", ".webp", ".png"]]
                    if cands:
                        hero_file = cands[0]
                        meta["hero_rel"] = f"{sub}/{hero_file.name}"
                        break
                        
        meta["hero_abs"] = str(hero_file) if hero_file.exists() else ""
        meta["live_url"] = f"https://varazdin.studio/{meta['slug']}/"
        meta["live_pdf_url"] = f"https://varazdin.studio/{meta['slug']}/{meta['pdf_rel']}"
        meta["local_url"] = f"../{meta['folder']}/index.html"
        meta["local_pdf_url"] = f"../{meta['folder']}/{meta['pdf_rel']}"
        decks.append(meta)
        
    return decks

def generate_dashboard_html(decks):
    """Generates the full standalone HTML for the Web Pitches Dashboard."""
    
    total_decks = len(decks)
    
    # Build Deck Cards HTML
    grid_cards_html = []
    for d in decks:
        badge_cls = f"badge-{d['badge_color']}"
        thumb_name = f"thumb_{d['slug']}.jpg"
        signature_class = " signature-card" if d.get("is_signature") else ""
        
        card = f"""
        <article class="deck-card video-card-crazy{signature_class}" data-slug="{d['slug']}" data-folder="{d['folder']}" data-client="{d['client'].lower()}" data-title="{d['title'].lower()}" data-status="poslano" data-price="{d['numeric_val']}">
          <!-- Full-card CanvasUI 4x4 Bayer Dither layer -->
          <canvas class="card-dither-canvas"></canvas>

          <div class="video-thumb-crazy-wrapper">
            <!-- Direct click to open deck in new tab -->
            <a href="{d['live_url']}" target="_blank" class="video-thumb-crazy" title="Otvori {d['title']}">
              <img src="assets/thumbnails/{thumb_name}" alt="{d['title']}" class="card-thumb" loading="lazy" onerror="this.onerror=null; this.src='../{d['slug']}/{d['hero_rel']}';">
              <div class="play-btn-crazy">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
              </div>
              <div class="scanline-overlay"></div>
            </a>

            <!-- Interactive Card-Fan Status Switcher on top-left of thumbnail -->
            <div class="status-fan-container" data-slug="{d['slug']}" onclick="event.stopPropagation();">
              <button type="button" class="status-badge active-status-badge status-poslano" onclick="cycleStatus('{d['slug']}', event)" title="Status ponude (hoveraj za opcije, klikni za rotaciju)">
                <span class="status-dot"></span>
                <span class="status-label">POSLANO</span>
              </button>
              <div class="status-fan-deck">
                <button type="button" class="status-badge status-card-flyout status-odobreno card-slot-1" data-status-val="odobreno" onclick="setStatus('{d['slug']}', 'odobreno', event)" title="Označi: ODOBRENO">
                  <span class="status-dot"></span>
                  <span class="status-label">ODOBRENO</span>
                </button>
                <button type="button" class="status-badge status-card-flyout status-odbijeno card-slot-2" data-status-val="odbijeno" onclick="setStatus('{d['slug']}', 'odbijeno', event)" title="Označi: ODBIJENO">
                  <span class="status-dot"></span>
                  <span class="status-label">ODBIJENO</span>
                </button>
                <button type="button" class="status-badge status-card-flyout status-poslano" data-status-val="poslano" style="display:none;" onclick="setStatus('{d['slug']}', 'poslano', event)" title="Označi: POSLANO">
                  <span class="status-dot"></span>
                  <span class="status-label">POSLANO</span>
                </button>
              </div>
            </div>
          </div>

          <div class="video-info-crazy">
            <div class="card-client-row">
              <span class="card-client-name">{d['client']}</span>
            </div>

            <!-- Direct Title Click to Open in New Tab -->
            <a href="{d['live_url']}" target="_blank" class="card-title-link">
              <h3 class="card-title" title="{d['title']}">{d['title']}</h3>
            </a>
            
            <p class="card-tagline">{d['tagline']}</p>

            <!-- Price Box with Hover Tooltip for Multiple Options -->
            <div class="card-pricing-box" title="Detalji opcija: {d['options_summary']}">
              <div class="pricing-amount-wrapper">
                <span class="pricing-amount">{d['price_display']}</span>
                <div class="pricing-tooltip">
                  <span class="tooltip-label">DOSTUPNE OPCIJE:</span>
                  <span class="tooltip-val">{d['options_summary']}</span>
                </div>
              </div>
              <span class="pricing-hint-icon" title="Hover za opcije">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>
              </span>
            </div>

            <!-- Action Buttons (Kept crisp and excluded from dither) -->
            <div class="card-actions-grid">
              <a href="{d['live_url']}" target="_blank" class="btn-card-action btn-primary" title="Otvori web pitch deck">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>
                <span>OTVORI DECK</span>
              </a>

              <a href="{d['live_pdf_url']}" target="_blank" class="btn-card-action btn-subtle" title="Preuzmi službenu A4 PDF ponudu">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                <span>PDF</span>
              </a>

              <button type="button" class="btn-card-action btn-icon" onclick="copyDeckUrl('{d['live_url']}', this)" title="Kopiraj poveznicu">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
              </button>

              <button type="button" class="btn-card-action btn-icon" onclick="openQrModal('{d['slug']}', '{d['title']}', '{d['live_url']}')" title="Pokaži QR kod za mobitel">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>
              </button>
            </div>
          </div>
        </article>
        """
        grid_cards_html.append(card)

    html = f"""<!DOCTYPE html>
<html lang="hr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Katalog Web Ponuda & Pitch Deckova — Studio Varaždin</title>
  <meta name="description" content="Službeni centralni katalog interaktivnih 16:9 prezentacijskih mikrosajtova i ponuda Studija Varaždin.">
  <meta name="robots" content="noindex, nofollow">
  
  <link rel="icon" type="image/svg+xml" href="https://varazdin.studio/favicon.svg">
  <link rel="apple-touch-icon" href="https://varazdin.studio/apple-touch-icon.png">

  <!-- Google Fonts: Plus Jakarta Sans, JetBrains Mono -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">

  <style>
    /* ==========================================================================
       MERIDIAN 16 EXACT DESIGN SYSTEM
       ========================================================================== */
    :root {{
      --bg-canvas: #f4efe4;
      --bg-card: #fbf7ee;
      --bg-card-subtle: #eae3d2;
      
      --text-primary: #111518;
      --text-secondary: #3b454e;
      --text-muted: #79828a;
      
      --border-dark: #111518;
      --border-color: #d5ccba;
      
      --accent-green: #11421f;
      --accent-green-bright: #177331;
      --accent-green-bg: #e1ede4;
      --accent-green-border: #a6cbb4;
      
      --accent-gold: #c9933b;
      --accent-gold-bg: #faeed4;
      
      --font-display: 'Plus Jakarta Sans', sans-serif;
      --font-hero: 'Plus Jakarta Sans', sans-serif;
      --font-sans: 'Plus Jakarta Sans', sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
      
      --radius-sm: 4px;
      --radius-md: 6px;
      --radius-lg: 8px;
      
      --shadow-bold-sm: 3px 3px 0px var(--text-primary);
      --shadow-bold-md: 6px 6px 0px var(--text-primary);
      --shadow-bold-lg: 9px 9px 0px var(--text-primary);
      --shadow-bold-modal: 10px 10px 0px var(--text-primary);
      
      --transition-smooth: cubic-bezier(0.16, 1, 0.3, 1);
    }}

    *, *::before, *::after {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
    }}

    html {{
      font-size: 16px;
      scroll-behavior: smooth;
    }}

    body {{
      font-family: var(--font-sans);
      background-color: var(--bg-canvas);
      color: var(--text-primary);
      min-height: 100vh;
      overflow-x: hidden;
      line-height: 1.45;
      position: relative;
    }}

    /* Paper texture pattern layer */
    body::before {{
      content: "";
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-image: 
        radial-gradient(#111518 0.65px, transparent 0.65px),
        radial-gradient(#111518 0.65px, var(--bg-canvas) 0.65px);
      background-size: 26px 26px;
      background-position: 0 0, 13px 13px;
      opacity: 0.035;
      pointer-events: none;
      z-index: 1;
    }}

    /* Paper noise overlay */
    .paper-noise-overlay {{
      position: fixed;
      inset: 0;
      pointer-events: none;
      z-index: 1;
      opacity: 0.04;
      background: repeating-radial-gradient(#000 0 0.0001%, #fff 0 0.0002%);
      mix-blend-mode: multiply;
    }}

    /* Ambient CanvasUI particles */
    #canvasUiParticles {{
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 2;
    }}

    /* ==========================================================================
       MERIDIAN 16 EXACT DECK-HEADER
       ========================================================================== */
    header.deck-header {{
      height: 56px;
      background: rgba(244, 239, 228, 0.95);
      backdrop-filter: blur(16px);
      border-bottom: 2px solid var(--text-primary);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 2.5rem;
      position: sticky;
      top: 0;
      z-index: 100;
      flex-shrink: 0;
    }}

    .brand-mark {{
      display: flex;
      align-items: center;
      gap: 12px;
      font-family: var(--font-display);
      font-weight: 900;
      font-size: 1.05rem;
      letter-spacing: -0.03em;
      color: var(--text-primary);
      text-decoration: none;
    }}

    .brand-mark .tag {{
      font-family: var(--font-mono);
      font-size: 0.72rem;
      font-weight: 800;
      background: var(--text-primary);
      color: #ffffff;
      padding: 3px 10px;
      border-radius: 3px;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }}

    .deck-controls-top {{
      display: flex;
      align-items: center;
      gap: 12px;
    }}

    .btn-action {{
      background: var(--bg-card);
      border: 2px solid var(--text-primary);
      color: var(--text-primary);
      padding: 6px 14px;
      font-size: 0.78rem;
      font-weight: 800;
      font-family: var(--font-mono);
      border-radius: 4px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s var(--transition-smooth);
      box-shadow: 2px 2px 0px var(--text-primary);
      text-decoration: none;
    }}

    .btn-action:hover {{
      transform: translate(-1px, -1px);
      box-shadow: 3.5px 3.5px 0px var(--text-primary);
      background: var(--accent-green-bg);
    }}

    .btn-action:active {{
      transform: translate(1px, 1px);
      box-shadow: 1px 1px 0px var(--text-primary);
    }}

    /* ==========================================================================
       MAIN DASHBOARD CONTAINER & HERO
       ========================================================================== */
    .dashboard-wrapper {{
      position: relative;
      z-index: 3;
      max-width: 1380px;
      margin: 0 auto;
      padding: 2.5rem 2.5rem 5rem 2.5rem;
    }}

    .quote-title {{
      font-family: var(--font-hero);
      font-size: clamp(2.1rem, 4vw, 3.6rem);
      font-weight: 900;
      line-height: 0.98;
      letter-spacing: -0.035em;
      margin-bottom: 1.75rem;
      text-transform: uppercase;
    }}

    .quote-title .outline-text {{
      font-family: var(--font-hero);
      font-weight: 900;
      color: transparent;
      -webkit-text-stroke: 1.8px var(--text-primary);
      letter-spacing: -0.02em;
    }}

    /* ==========================================================================
       MERIDIAN 16 BOLD SEARCH BOX
       ========================================================================== */
    .meridian-search-card {{
      background: var(--bg-card);
      border: 2px solid var(--text-primary);
      border-radius: 6px;
      padding: 1.15rem 1.35rem;
      box-shadow: var(--shadow-bold-md);
      margin-bottom: 2.75rem;
      display: flex;
      flex-direction: column;
      gap: 0.65rem;
    }}

    .search-input-box {{
      position: relative;
      width: 100%;
    }}

    .search-icon {{
      position: absolute;
      left: 1.15rem;
      top: 50%;
      transform: translateY(-50%);
      color: var(--text-muted);
      pointer-events: none;
    }}

    .search-input {{
      width: 100%;
      background: var(--bg-card-subtle);
      border: 2px solid var(--text-primary);
      border-radius: var(--radius-sm);
      padding: 0.85rem 2.8rem 0.85rem 3.1rem;
      font-family: var(--font-sans);
      font-size: 1rem;
      font-weight: 700;
      color: var(--text-primary);
      outline: none;
      transition: all 0.18s var(--transition-smooth);
    }}

    .search-input:focus {{
      background: #ffffff;
      border-color: var(--accent-green);
      box-shadow: 0 0 0 3px var(--accent-green-bg);
    }}

    .search-kbd-hint {{
      position: absolute;
      right: 1rem;
      top: 50%;
      transform: translateY(-50%);
      font-family: var(--font-mono);
      font-size: 0.75rem;
      font-weight: 800;
      color: var(--text-muted);
      background: var(--bg-card);
      border: 1.5px solid var(--text-primary);
      padding: 0.18rem 0.45rem;
      border-radius: 3px;
      pointer-events: none;
    }}

    .search-meta-row {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-family: var(--font-mono);
      font-size: 0.75rem;
      font-weight: 700;
      color: var(--text-muted);
    }}

    .search-count-badge {{
      font-weight: 800;
      color: var(--accent-green);
      background: var(--accent-green-bg);
      padding: 2px 8px;
      border-radius: 3px;
      border: 1px solid var(--accent-green-border);
    }}

    /* ==========================================================================
       PITCH DECK CARDS (Meridian 16 video-card-crazy style)
       ========================================================================== */
    .decks-grid-view {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(390px, 1fr));
      gap: 2.25rem;
    }}

    .video-card-crazy {{
      background: var(--bg-card);
      border: 2px solid var(--text-primary);
      border-radius: 6px;
      overflow: visible; /* Allows fanned status cards and tooltips to be visible */
      box-shadow: var(--shadow-bold-md);
      transition: transform 0.25s var(--transition-smooth), box-shadow 0.25s var(--transition-smooth);
      display: flex;
      flex-direction: column;
      position: relative;
    }}

    .video-card-crazy:hover {{
      transform: translate(-3px, -3px);
      box-shadow: var(--shadow-bold-lg);
    }}

    /* Full-Card CanvasUI 4x4 Bayer Dither Layer */
    .card-dither-canvas {{
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 7;
      opacity: 0;
      border-radius: 5px;
      transition: opacity 0.2s ease;
      mix-blend-mode: multiply;
    }}

    .video-thumb-crazy-wrapper {{
      position: relative;
      width: 100%;
      overflow: visible;
    }}

    .video-thumb-crazy {{
      position: relative;
      width: 100%;
      aspect-ratio: 16 / 9;
      overflow: hidden;
      background: #000;
      cursor: pointer;
      display: block;
      border-bottom: 2px solid var(--text-primary);
      text-decoration: none;
      border-top-left-radius: 4px;
      border-top-right-radius: 4px;
    }}

    .video-thumb-crazy img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
      transition: transform 0.4s var(--transition-smooth);
    }}

    .video-card-crazy:hover .video-thumb-crazy img {{
      transform: scale(1.04);
    }}

    .play-btn-crazy {{
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 52px;
      height: 52px;
      background: var(--accent-green);
      color: #ffffff;
      border: 2px solid var(--text-primary);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 3px 3px 0px var(--text-primary);
      transition: transform 0.2s var(--transition-smooth), background 0.2s;
      z-index: 5;
    }}

    .video-card-crazy:hover .play-btn-crazy {{
      transform: translate(-50%, -50%) scale(1.12);
      background: var(--accent-green-bright);
    }}

    .scanline-overlay {{
      position: absolute;
      inset: 0;
      background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%);
      background-size: 100% 4px;
      z-index: 3;
      pointer-events: none;
      opacity: 0.35;
    }}

    .video-info-crazy {{
      padding: 1.35rem 1.4rem;
      display: flex;
      flex-direction: column;
      flex: 1;
      background: var(--bg-card);
      position: relative;
      z-index: 8;
      border-bottom-left-radius: 4px;
      border-bottom-right-radius: 4px;
    }}

    .card-client-row {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 0.75rem;
      margin-bottom: 0.6rem;
      position: relative;
      z-index: 25;
    }}

    .card-client-name {{
      font-family: var(--font-mono);
      font-size: 0.75rem;
      font-weight: 800;
      color: var(--accent-green);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }}

    /* ==========================================================================
       CARD FAN STATUS SWITCHER (Top-Left Thumbnail & Upward Fan with Deadzone Bridge)
       ========================================================================== */
    .status-fan-container {{
      position: absolute;
      top: 10px;
      left: 10px;
      display: inline-flex;
      align-items: center;
      z-index: 35;
      user-select: none;
    }}

    /* Seamless hover deadzone / bridge extending upward over fanned cards */
    .status-fan-container::before {{
      content: '';
      position: absolute;
      left: -15px;
      right: -30px;
      bottom: -12px;
      top: -95px; /* Bridges entire upward fanned area so hover is never accidentally dropped */
      background: transparent;
      pointer-events: none;
      z-index: 10;
    }}

    .status-fan-container:hover::before {{
      pointer-events: auto; /* Active hover bridge while hovering */
    }}

    .status-badge {{
      font-family: var(--font-mono);
      font-size: 0.68rem;
      font-weight: 800;
      letter-spacing: 0.05em;
      padding: 4px 10px;
      border-radius: 3px;
      text-transform: uppercase;
      border: 1.5px solid var(--text-primary);
      box-shadow: 2px 2px 0px var(--text-primary);
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
      transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.2s, opacity 0.2s, background 0.2s;
      outline: none;
      position: relative;
      z-index: 20;
    }}

    .status-badge .status-dot {{
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: currentColor;
      display: inline-block;
      flex-shrink: 0;
    }}

    /* Color Variants: Oker Gold, Maslinasto Zelena, Trešnja Crvena */
    .status-poslano {{
      background: #c9933b; /* Oker Gold */
      color: #111518;
    }}
    .status-odobreno {{
      background: #2d5a27; /* Maslinasto zelena */
      color: #f4efe4;
    }}
    .status-odbijeno {{
      background: #800e13; /* Trešnja crvena */
      color: #f4efe4;
    }}

    .active-status-badge {{
      position: relative;
      z-index: 30;
    }}

    .status-fan-container:hover .active-status-badge {{
      transform: scale(1.04);
      box-shadow: 3px 3px 0px var(--text-primary);
    }}

    .status-fan-deck {{
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
    }}

    .status-card-flyout {{
      position: absolute;
      top: 0;
      left: 0;
      opacity: 0;
      pointer-events: none;
      transform: translate(0, 0) rotate(0deg) scale(0.9);
      transition: transform 0.35s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.2s ease, box-shadow 0.2s;
      z-index: 15;
    }}

    /* Fluid Upward Card Fan Spread on Hover */
    .status-fan-container:hover .status-fan-deck {{
      pointer-events: auto;
    }}

    /* Slot 1: flies UPWARD rotated -6deg */
    .status-fan-container:hover .status-card-flyout.card-slot-1 {{
      opacity: 1;
      pointer-events: auto;
      transform: translate(4px, -114%) rotate(-6deg);
      z-index: 25;
    }}

    /* Slot 2: flies further UPWARD rotated +9deg */
    .status-fan-container:hover .status-card-flyout.card-slot-2 {{
      opacity: 1;
      pointer-events: auto;
      transform: translate(12px, -226%) rotate(9deg);
      z-index: 24;
    }}

    /* Hovering individual fanned card raises and straightens it */
    .status-fan-deck .status-card-flyout.card-slot-1:hover {{
      transform: translate(4px, -118%) rotate(-2deg) scale(1.08) !important;
      box-shadow: 4px 4px 0px var(--text-primary) !important;
      z-index: 35 !important;
    }}

    .status-fan-deck .status-card-flyout.card-slot-2:hover {{
      transform: translate(12px, -232%) rotate(3deg) scale(1.08) !important;
      box-shadow: 4px 4px 0px var(--text-primary) !important;
      z-index: 35 !important;
    }}

    .card-title-link {{
      text-decoration: none;
      color: inherit;
      display: block;
      position: relative;
      z-index: 10;
    }}

    .card-title-link:hover .card-title {{
      color: var(--accent-green);
      text-decoration: underline;
    }}

    .card-title {{
      font-family: var(--font-hero);
      font-size: 1.22rem;
      font-weight: 800;
      color: var(--text-primary);
      line-height: 1.22;
      margin-bottom: 0.55rem;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      transition: color 0.15s;
    }}

    .card-tagline {{
      font-size: 0.85rem;
      color: var(--text-secondary);
      line-height: 1.42;
      margin-bottom: 1.25rem;
      font-weight: 500;
      flex: 1;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      position: relative;
      z-index: 10;
    }}

    /* Price Box with Hover Tooltip */
    .card-pricing-box {{
      position: relative;
      background: var(--bg-card-subtle);
      border: 2px solid var(--text-primary);
      border-radius: var(--radius-sm);
      padding: 0.85rem 1.1rem;
      margin-bottom: 1.25rem;
      box-shadow: 3px 3px 0px var(--text-primary);
      display: flex;
      justify-content: space-between;
      align-items: center;
      cursor: help;
      z-index: 12;
    }}

    .pricing-amount-wrapper {{
      position: relative;
      display: inline-block;
    }}

    .pricing-amount {{
      font-family: var(--font-mono);
      font-size: 1.35rem;
      font-weight: 800;
      color: var(--text-primary);
      letter-spacing: -0.01em;
    }}

    .pricing-hint-icon {{
      color: var(--text-muted);
      display: flex;
      align-items: center;
      transition: color 0.15s;
    }}

    .card-pricing-box:hover .pricing-hint-icon {{
      color: var(--accent-green);
    }}

    .pricing-tooltip {{
      position: absolute;
      bottom: calc(100% + 10px);
      left: 0;
      background: #111518;
      color: #f4efe4;
      border: 1.5px solid #111518;
      padding: 0.55rem 0.85rem;
      border-radius: 4px;
      font-family: var(--font-mono);
      font-size: 0.72rem;
      font-weight: 700;
      white-space: nowrap;
      box-shadow: 4px 4px 0px rgba(17, 21, 24, 0.35);
      opacity: 0;
      pointer-events: none;
      transform: translateY(6px);
      transition: all 0.18s var(--transition-smooth);
      z-index: 40;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }}

    .pricing-tooltip::after {{
      content: '';
      position: absolute;
      top: 100%;
      left: 24px;
      border-width: 5px;
      border-style: solid;
      border-color: #111518 transparent transparent transparent;
    }}

    .card-pricing-box:hover .pricing-tooltip {{
      opacity: 1;
      transform: translateY(0);
    }}

    .tooltip-label {{
      font-size: 0.65rem;
      color: #a7bbb3;
      letter-spacing: 0.05em;
    }}

    .tooltip-val {{
      color: #34d399;
      font-weight: 800;
    }}

    /* Action Buttons (Kept crisp and above dither) */
    .card-actions-grid {{
      display: grid;
      grid-template-columns: 1fr auto 42px 42px;
      gap: 0.5rem;
      position: relative;
      z-index: 18;
    }}

    .btn-card-action {{
      border-radius: var(--radius-sm);
      font-family: var(--font-mono);
      font-size: 0.75rem;
      font-weight: 800;
      letter-spacing: 0.03em;
      padding: 0.62rem 0.65rem;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.4rem;
      cursor: pointer;
      text-decoration: none;
      transition: all 0.15s var(--transition-smooth);
      border: 2px solid var(--text-primary);
      box-shadow: 3px 3px 0px var(--text-primary);
      white-space: nowrap;
    }}

    .btn-card-action:hover {{
      transform: translate(-1.5px, -1.5px);
      box-shadow: 4.5px 4.5px 0px var(--text-primary);
    }}

    .btn-card-action:active {{
      transform: translate(2px, 2px);
      box-shadow: 1px 1px 0px var(--text-primary);
    }}

    .btn-primary {{
      background: var(--accent-green);
      color: #f4efe4;
    }}

    .btn-primary:hover {{
      background: var(--accent-green-bright);
    }}

    .btn-subtle {{
      background: var(--bg-card-subtle);
      color: var(--text-primary);
    }}

    .btn-subtle:hover {{
      background: #ffffff;
    }}

    .btn-icon {{
      background: #ffffff;
      color: var(--text-primary);
      padding: 0;
    }}

    .btn-icon:hover {{
      background: var(--accent-green-bg);
      color: var(--accent-green);
    }}

    /* QR Code Modal */
    .dashboard-modal-backdrop {{
      position: fixed;
      inset: 0;
      background: rgba(17, 21, 24, 0.85);
      backdrop-filter: blur(8px);
      z-index: 1000;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 2rem;
      opacity: 0;
      transition: opacity 0.25s var(--transition-smooth);
    }}

    .dashboard-modal-backdrop.active {{
      display: flex;
      opacity: 1;
    }}

    .qr-modal-frame {{
      max-width: 440px;
      text-align: center;
      padding: 2.25rem;
      background: var(--bg-card);
      border: 3px solid var(--text-primary);
      border-radius: 6px;
      box-shadow: var(--shadow-bold-modal);
      animation: modalPop 0.25s var(--transition-smooth);
    }}

    @keyframes modalPop {{
      0% {{ transform: scale(0.96) translateY(15px); opacity: 0; }}
      100% {{ transform: scale(1) translateY(0); opacity: 1; }}
    }}

    .qr-modal-title {{
      font-family: var(--font-hero);
      font-size: 1.4rem;
      font-weight: 900;
      margin-bottom: 0.5rem;
    }}

    .qr-modal-sub {{
      font-size: 0.86rem;
      color: var(--text-secondary);
      margin-bottom: 1.5rem;
      font-weight: 500;
    }}

    .qr-code-box {{
      background: #ffffff;
      padding: 1.25rem;
      border: 2px solid var(--text-primary);
      border-radius: var(--radius-sm);
      display: inline-block;
      margin-bottom: 1.5rem;
      box-shadow: 4px 4px 0px var(--text-primary);
    }}

    .qr-code-box img {{
      display: block;
      width: 200px;
      height: 200px;
    }}

    .qr-url-box {{
      font-family: var(--font-mono);
      font-size: 0.8rem;
      font-weight: 700;
      background: var(--bg-card-subtle);
      border: 2px solid var(--text-primary);
      padding: 0.65rem 0.85rem;
      border-radius: var(--radius-sm);
      color: var(--accent-green);
      word-break: break-all;
      margin-bottom: 1.35rem;
    }}

    .toast-pill {{
      position: fixed;
      bottom: 2.5rem;
      right: 2.5rem;
      background: var(--accent-green);
      color: #f4efe4;
      border: 2px solid var(--text-primary);
      font-family: var(--font-mono);
      font-weight: 800;
      font-size: 0.85rem;
      padding: 0.85rem 1.35rem;
      border-radius: var(--radius-sm);
      box-shadow: 5px 5px 0px var(--text-primary);
      z-index: 2000;
      display: flex;
      align-items: center;
      gap: 0.65rem;
      transform: translateY(120px);
      opacity: 0;
      transition: all 0.3s var(--transition-smooth);
      pointer-events: none;
    }}

    .toast-pill.active {{
      transform: translateY(0);
      opacity: 1;
    }}

    @media (max-width: 768px) {{
      header.deck-header {{
        padding: 0 1.25rem;
      }}
      .dashboard-wrapper {{
        padding: 1.5rem 1.15rem 4rem 1.15rem;
      }}
      .decks-grid-view {{
        grid-template-columns: 1fr;
      }}
      .card-actions-grid {{
        grid-template-columns: 1fr 1fr 42px 42px;
      }}
      .dashboard-modal-backdrop {{
        padding: 0.5rem;
      }}
    }}
  </style>
</head>
<body>

  <!-- Paper noise texture -->
  <div class="paper-noise-overlay"></div>

  <!-- Ambient CanvasUI particles -->
  <canvas id="canvasUiParticles"></canvas>

  <!-- Meridian 16 Top Navigation Header -->
  <header class="deck-header">
    <a href="https://varazdin.studio" class="brand-mark">
      <span>STUDIO VARAŽDIN</span>
      <span class="tag">WEB PONUDE // 2026</span>
    </a>

    <div class="deck-controls-top">
      <button class="btn-action btn-sound-toggle" id="btnSound" onclick="toggleSound()" title="Zvučni efekti">
        <span id="soundIconOff" style="display:none;">🔇</span>
        <span id="soundIconOn" style="display:inline-block;">🔊</span>
        <span id="soundLabel">Sound: ON</span>
      </button>

      <button class="btn-action btn-fullscreen" onclick="document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen()" title="Puni zaslon">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/></svg>
        <span>Fullscreen</span>
      </button>
    </div>
  </header>

  <div class="dashboard-wrapper">
    
    <!-- Bold Quote Title (Meridian 16 style) -->
    <h1 class="quote-title">
      KATALOG WEB PONUDA <span class="outline-text">& PITCH DECKOVA</span>
    </h1>

    <!-- Meridian 16 Bold Search Box -->
    <section class="meridian-search-card">
      <div class="search-input-box">
        <svg class="search-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        <input type="text" id="searchInput" class="search-input" placeholder="Pretraži web ponude (npr. Meridian 16, Čakovec, Varaždin, Samobor, Poslano...)" oninput="handleSearch(this.value)">
        <span class="search-kbd-hint">/</span>
      </div>
      <div class="search-meta-row">
        <span>Instantno filtriranje po nazivu klijenta, projektu ili statusu</span>
        <span class="search-count-badge" id="resultsCount">{total_decks} / {total_decks} PONUDA</span>
      </div>
    </section>

    <!-- PURE HIGH-IMPACT GRID VIEW -->
    <main class="decks-grid-view" id="decksGridView">
      {"".join(grid_cards_html)}
    </main>

  </div>

  <!-- Dynamic QR Code Modal -->
  <div class="dashboard-modal-backdrop" id="qrModal" onclick="handleBackdropClick(event, 'qrModal')">
    <div class="qr-modal-frame">
      <h3 class="qr-modal-title" id="qrModalTitle">Skeniraj za mobitel</h3>
      <p class="qr-modal-sub">Otvorite kameru pametnog telefona i skenirajte QR kod za instantno otvaranje pitch decka.</p>
      
      <div class="qr-code-box">
        <img id="qrCodeImage" src="" alt="QR Kod">
      </div>

      <div class="qr-url-box" id="qrModalUrlText">https://varazdin.studio/</div>

      <div style="display: flex; gap: 0.6rem; justify-content: center;">
        <button type="button" class="btn-card-action btn-primary" id="btnCopyFromQr" onclick="copyFromQrModal()">KOPIRAJ LINK</button>
        <button type="button" class="btn-card-action btn-secondary" onclick="closeQrModal()">ZATVORI</button>
      </div>
    </div>
  </div>

  <!-- Toast Notification Pill -->
  <div class="toast-pill" id="dashboardToast">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>
    <span id="toastMessage">Poveznica kopirana u međuspremnik!</span>
  </div>

  <!-- DASHBOARD JAVASCRIPT: STATUS CARD-FAN & FULL-CARD CANVASUI ENGINE -->
  <script>
    /* Web Audio Haptic Engine */
    let audioCtx = null;
    let soundMuted = false;

    function initAudio() {{
      if (!audioCtx) {{
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) audioCtx = new AudioContext();
      }}
    }}

    function playHapticClick(freq1 = 900, freq2 = 350) {{
      if (soundMuted) return;
      initAudio();
      if (!audioCtx || audioCtx.state === 'suspended') return;

      try {{
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        const now = audioCtx.currentTime;

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq1, now);
        osc.frequency.exponentialRampToValueAtTime(freq2, now + 0.04);

        gain.gain.setValueAtTime(0.09, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

        osc.connect(gain);
        gain.connect(audioCtx.destination);

        osc.start(now);
        osc.stop(now + 0.045);
      }} catch (e) {{}}
    }}

    function toggleSound() {{
      initAudio();
      if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
      soundMuted = !soundMuted;
      
      const iconOff = document.getElementById('soundIconOff');
      const iconOn = document.getElementById('soundIconOn');
      const label = document.getElementById('soundLabel');

      if (soundMuted) {{
        if (iconOff) iconOff.style.display = 'inline-block';
        if (iconOn) iconOn.style.display = 'none';
        if (label) label.textContent = 'Sound: OFF';
      }} else {{
        if (iconOff) iconOff.style.display = 'none';
        if (iconOn) iconOn.style.display = 'inline-block';
        if (label) label.textContent = 'Sound: ON';
        playHapticClick(1000, 400);
      }}
    }}

    /* Status State & Interactive Card-Fan Management */
    const STATUS_MAP = {{
      'poslano': {{ label: 'POSLANO', className: 'status-poslano' }},
      'odobreno': {{ label: 'ODOBRENO', className: 'status-odobreno' }},
      'odbijeno': {{ label: 'ODBIJENO', className: 'status-odbijeno' }}
    }};

    const STATUS_KEYS = ['poslano', 'odobreno', 'odbijeno'];

    function getDeckStatus(slug) {{
      return localStorage.getItem('pitch_status_' + slug) || 'poslano';
    }}

    function setStatus(slug, newStatus, event) {{
      if (event) {{
        event.stopPropagation();
        event.preventDefault();
      }}

      if (!STATUS_MAP[newStatus]) return;

      localStorage.setItem('pitch_status_' + slug, newStatus);
      updateStatusUI(slug, newStatus);
      playHapticClick(1150, 480);
      showToast('Status ažuriran: ' + STATUS_MAP[newStatus].label);
    }}

    function cycleStatus(slug, event) {{
      if (event) {{
        event.stopPropagation();
        event.preventDefault();
      }}
      const current = getDeckStatus(slug);
      const currentIndex = STATUS_KEYS.indexOf(current);
      const nextIndex = (currentIndex + 1) % STATUS_KEYS.length;
      const nextStatus = STATUS_KEYS[nextIndex];
      setStatus(slug, nextStatus);
    }}

    function updateStatusUI(slug, currentStatus) {{
      const container = document.querySelector(`.status-fan-container[data-slug="${{slug}}"]`);
      if (!container) return;

      const card = container.closest('.deck-card');
      if (card) {{
        card.setAttribute('data-status', currentStatus);
      }}

      const activeBtn = container.querySelector('.active-status-badge');
      const labelEl = activeBtn.querySelector('.status-label');
      
      // Reset classes on active badge
      STATUS_KEYS.forEach(k => activeBtn.classList.remove('status-' + k));
      activeBtn.classList.add(STATUS_MAP[currentStatus].className);
      labelEl.textContent = STATUS_MAP[currentStatus].label;

      // Update remaining options for card-fan flyout
      const otherStatuses = STATUS_KEYS.filter(k => k !== currentStatus);
      const flyoutBtns = container.querySelectorAll('.status-card-flyout');

      flyoutBtns.forEach(btn => {{
        const val = btn.getAttribute('data-status-val');
        btn.classList.remove('card-slot-1', 'card-slot-2');
        if (val === currentStatus) {{
          btn.style.display = 'none';
        }} else if (val === otherStatuses[0]) {{
          btn.style.display = 'inline-flex';
          btn.classList.add('card-slot-1');
        }} else if (val === otherStatuses[1]) {{
          btn.style.display = 'inline-flex';
          btn.classList.add('card-slot-2');
        }}
      }});
    }}

    function initAllStatuses() {{
      const containers = document.querySelectorAll('.status-fan-container');
      containers.forEach(cont => {{
        const slug = cont.getAttribute('data-slug');
        if (slug) {{
          const current = getDeckStatus(slug);
          updateStatusUI(slug, current);
        }}
      }});
    }}

    /* Search Filtering */
    let currentQuery = '';

    function handleSearch(val) {{
      currentQuery = val.trim().toLowerCase();
      applySearch();
    }}

    function applySearch() {{
      const gridContainer = document.getElementById('decksGridView');
      const cards = Array.from(gridContainer.querySelectorAll('.deck-card'));

      let visibleCount = 0;

      cards.forEach(card => {{
        const client = card.getAttribute('data-client') || '';
        const title = card.getAttribute('data-title') || '';
        const slug = card.getAttribute('data-slug') || '';
        const status = card.getAttribute('data-status') || '';

        const matches = !currentQuery || 
                        client.includes(currentQuery) || 
                        title.includes(currentQuery) || 
                        slug.includes(currentQuery) || 
                        status.includes(currentQuery);

        if (matches) {{
          card.style.display = 'flex';
          visibleCount++;
        }} else {{
          card.style.display = 'none';
        }}
      }});

      const badge = document.getElementById('resultsCount');
      if (badge) {{
        badge.textContent = `${{visibleCount}} / ${{cards.length}} PONUDA`;
      }}
    }}

    /* Clipboard Copy & Toast */
    function copyDeckUrl(url, btnElement) {{
      playHapticClick(1200, 450);
      navigator.clipboard.writeText(url).then(() => {{
        showToast('Poveznica kopirana u međuspremnik!');
        if (btnElement) {{
          const original = btnElement.innerHTML;
          btnElement.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#11421f" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>`;
          setTimeout(() => {{
            btnElement.innerHTML = original;
          }}, 1400);
        }}
      }}).catch(() => {{
        prompt('Kopirajte poveznicu ručno:', url);
      }});
    }}

    function showToast(msg) {{
      const toast = document.getElementById('dashboardToast');
      const textEl = document.getElementById('toastMessage');
      if (toast && textEl) {{
        textEl.textContent = msg;
        toast.classList.add('active');
        setTimeout(() => {{
          toast.classList.remove('active');
        }}, 2400);
      }}
    }}

    /* QR Code Modal Functions */
    let currentModalUrl = '';

    function openQrModal(slug, title, url) {{
      playHapticClick(850, 300);
      currentModalUrl = url;
      const modal = document.getElementById('qrModal');
      const titleEl = document.getElementById('qrModalTitle');
      const urlTextEl = document.getElementById('qrModalUrlText');
      const imgEl = document.getElementById('qrCodeImage');

      titleEl.textContent = title;
      urlTextEl.textContent = url;
      imgEl.src = `https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${{encodeURIComponent(url)}}&margin=10`;

      modal.classList.add('active');
      document.body.style.overflow = 'hidden';
    }}

    function closeQrModal() {{
      playHapticClick(650, 250);
      const modal = document.getElementById('qrModal');
      modal.classList.remove('active');
      document.body.style.overflow = '';
    }}

    function handleBackdropClick(e, modalId) {{
      if (e.target.id === modalId) {{
        closeQrModal();
      }}
    }}

    function copyFromQrModal() {{
      if (currentModalUrl) {{
        copyDeckUrl(currentModalUrl);
        closeQrModal();
      }}
    }}

    /* Keyboard Shortcuts */
    document.addEventListener('keydown', (e) => {{
      if (e.key === 'Escape') {{
        closeQrModal();
      }}
      if (e.key === '/' && document.activeElement !== document.getElementById('searchInput')) {{
        e.preventDefault();
        const input = document.getElementById('searchInput');
        input.focus();
        input.select();
      }}
    }});

    /* Ambient CanvasUI Particles */
    (function initCanvasUiParticles() {{
      const canvas = document.getElementById('canvasUiParticles');
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      let width = canvas.width = window.innerWidth;
      let height = canvas.height = window.innerHeight;

      window.addEventListener('resize', () => {{
        width = canvas.width = window.innerWidth;
        height = canvas.height = window.innerHeight;
      }});

      const particles = [];
      const count = 35;

      for (let i = 0; i < count; i++) {{
        particles.push({{
          x: Math.random() * width,
          y: Math.random() * height,
          vx: (Math.random() - 0.5) * 0.35,
          vy: (Math.random() - 0.5) * 0.35,
          size: Math.random() * 1.8 + 0.8,
          alpha: Math.random() * 0.3 + 0.12,
          color: Math.random() > 0.4 ? '17, 66, 31' : '201, 147, 59'
        }});
      }}

      let mouseX = width / 2;
      let mouseY = height / 2;
      window.addEventListener('mousemove', (e) => {{
        mouseX = e.clientX;
        mouseY = e.clientY;
      }}, {{ passive: true }});

      function draw() {{
        ctx.clearRect(0, 0, width, height);

        for (let p of particles) {{
          const dx = p.x - mouseX;
          const dy = p.y - mouseY;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 120 && dist > 0) {{
            const force = (1 - dist / 120) * 0.5;
            p.vx += (dx / dist) * force;
            p.vy += (dy / dist) * force;
          }}

          p.x += p.vx;
          p.y += p.vy;

          p.vx *= 0.98;
          p.vy *= 0.98;
          p.y -= 0.12;

          if (p.x < 0) p.x = width;
          if (p.x > width) p.x = 0;
          if (p.y < 0) p.y = height;
          if (p.y > height) p.y = 0;

          ctx.globalAlpha = p.alpha;
          ctx.fillStyle = `rgb(${{p.color}})`;
          ctx.beginPath();
          ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
          ctx.fill();
        }}
        requestAnimationFrame(draw);
      }}
      draw();
    }})();

    /* Full-Card CanvasUI 4x4 Bayer Dither Engine (excluding action buttons) */
    (function initFullCardCanvasUiBayerDither() {{
      const bayerMatrix4x4 = [
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
      ];

      const cards = document.querySelectorAll('.video-card-crazy');
      cards.forEach((card) => {{
        let canvas = card.querySelector('.card-dither-canvas');
        if (!canvas) {{
          canvas = document.createElement('canvas');
          canvas.className = 'card-dither-canvas';
          card.insertBefore(canvas, card.firstChild);
        }}

        let isHovered = false;
        let mouseX = -999;
        let mouseY = -999;
        const targetImg = card.querySelector('.card-thumb');
        const thumbContainer = card.querySelector('.video-thumb-crazy');
        const actionsGrid = card.querySelector('.card-actions-grid');

        card.addEventListener('mouseenter', () => {{
          isHovered = true;
          canvas.style.opacity = '1';
          canvas.width = card.clientWidth;
          canvas.height = card.clientHeight;
        }});

        card.addEventListener('mouseleave', () => {{
          isHovered = false;
          canvas.style.opacity = '0';
        }});

        card.addEventListener('mousemove', (e) => {{
          const rect = card.getBoundingClientRect();
          mouseX = e.clientX - rect.left;
          mouseY = e.clientY - rect.top;
          renderDither();
        }}, {{ passive: true }});

        function renderDither() {{
          if (!isHovered) return;
          const w = canvas.width;
          const h = canvas.height;
          if (w === 0 || h === 0) return;
          const ctx = canvas.getContext('2d');

          const scale = 0.25; // 4x4 dither resolution
          const sw = Math.floor(w * scale);
          const sh = Math.floor(h * scale);
          if (sw <= 0 || sh <= 0) return;

          const offCanvas = document.createElement('canvas');
          offCanvas.width = sw;
          offCanvas.height = sh;
          const offCtx = offCanvas.getContext('2d');

          // Draw base paper fill
          offCtx.fillStyle = '#fbf7ee';
          offCtx.fillRect(0, 0, sw, sh);

          // Draw thumbnail onto offscreen canvas
          const thumbH = thumbContainer ? thumbContainer.clientHeight : Math.floor(h * 0.45);
          const sThumbH = Math.floor(thumbH * scale);

          if (targetImg && targetImg.complete && targetImg.naturalWidth > 0) {{
            try {{
              offCtx.drawImage(targetImg, 0, 0, sw, sThumbH);
            }} catch (e) {{}}
          }}

          // Calculate button exclusion area
          let btnTop = h;
          if (actionsGrid) {{
            const cardRect = card.getBoundingClientRect();
            const btnRect = actionsGrid.getBoundingClientRect();
            btnTop = btnRect.top - cardRect.top;
          }}
          const sBtnTop = Math.floor(btnTop * scale);

          try {{
            const imgData = offCtx.getImageData(0, 0, sw, sh);
            const data = imgData.data;

            ctx.clearRect(0, 0, w, h);
            const lensRadius = 180;

            for (let y = 0; y < sh; y++) {{
              // Exclude buttons completely so they remain 100% crisp and readable
              if (y >= sBtnTop) continue;

              for (let x = 0; x < sw; x++) {{
                const screenX = x / scale;
                const screenY = y / scale;
                const dist = Math.sqrt((screenX - mouseX) ** 2 + (screenY - mouseY) ** 2);

                if (dist < lensRadius) {{
                  const idx = (y * sw + x) * 4;
                  const r = data[idx];
                  const g = data[idx + 1];
                  const b = data[idx + 2];
                  const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

                  const feather = Math.cos((dist / lensRadius) * (Math.PI / 2));
                  const bayerVal = (bayerMatrix4x4[(y % 4) * 4 + (x % 4)] + 0.5) / 16;
                  const levels = 4;
                  const quantized = Math.floor(lum * levels + (lum > bayerVal ? 0.5 : 0)) / levels;
                  
                  const finalVal = Math.floor(quantized * 255);
                  
                  if (y < sThumbH) {{
                    // Photo halftone tone
                    ctx.fillStyle = `rgba(${{finalVal}}, ${{Math.floor(finalVal * 0.95)}}, ${{Math.floor(finalVal * 0.85)}}, ${{feather * 0.85}})`;
                  }} else {{
                    // Card paper halftone dither field
                    const inkVal = Math.floor((1 - quantized) * 120);
                    ctx.fillStyle = `rgba(17, 21, 24, ${{feather * (bayerVal > 0.4 ? 0.22 : 0.04)}})`;
                  }}
                  ctx.fillRect(screenX, screenY, 1 / scale, 1 / scale);
                }}
              }}
            }}
          }} catch (err) {{}}
        }}
      }});
    }})();

    // Initialize all pitch deck statuses on startup
    document.addEventListener('DOMContentLoaded', initAllStatuses);
    initAllStatuses();
  </script>
</body>
</html>
"""
    return html

def build_thumbnails(decks, target_dir):
    """Copies thumbnail images into the target assets/thumbnails directory."""
    thumb_dir = target_dir / "assets" / "thumbnails"
    os.makedirs(thumb_dir, exist_ok=True)

    for d in decks:
        hero_abs = d.get("hero_abs")
        dest_file = thumb_dir / f"thumb_{d['slug']}.jpg"
        if hero_abs and os.path.exists(hero_abs):
            try:
                shutil.copy2(hero_abs, dest_file)
            except Exception as e:
                print(f"⚠️ Could not copy thumb for {d['slug']}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Compile Web Pitches Dashboard")
    parser.add_argument("--deploy", action="store_true", help="Deploy dashboard to varazdin.studio/website/ponude")
    parser.add_argument("--open", action="store_true", help="Open the generated dashboard in browser")
    args = parser.parse_args()

    start_time = time.time()
    decks = scan_decks()
    html_content = generate_dashboard_html(decks)

    # 1. Output to local Ponude/dashboard/
    os.makedirs(OUTPUT_LOCAL_DIR, exist_ok=True)
    local_index = OUTPUT_LOCAL_DIR / "index.html"
    with open(local_index, 'w', encoding='utf-8') as f:
        f.write(html_content)
    build_thumbnails(decks, OUTPUT_LOCAL_DIR)
    print(f"✅ Generated local Dashboard: {local_index}")

    # 2. Output to varazdin.studio website
    if args.deploy or VARAZDIN_STUDIO_ROOT.exists():
        os.makedirs(OUTPUT_WEB_DIR, exist_ok=True)
        web_index = OUTPUT_WEB_DIR / "index.html"
        with open(web_index, 'w', encoding='utf-8') as f:
            f.write(html_content)
        build_thumbnails(decks, OUTPUT_WEB_DIR)
        print(f"🚀 Deployed to varazdin.studio: {web_index} (https://varazdin.studio/ponude/)")

    elapsed = (time.time() - start_time) * 1000
    print(f"✨ Dashboard compiled in {elapsed:.1f}ms with {len(decks)} decks.")

    if args.open:
        os.system(f"open '{local_index}'")

if __name__ == "__main__":
    main()

