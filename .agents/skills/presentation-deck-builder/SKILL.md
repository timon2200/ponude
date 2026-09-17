---
name: presentation-deck-builder
description: Automatska izrada i modularno uređivanje 16:9 kinematografskih interaktivnih prezentacijskih mikrosajtova na temelju ponuda iz Ponude.app ili PDF ponuda, s cPanel Git deploymentom na varazdin.studio.
---

# Presentation Deck Builder (varazdin.studio)

Ovaj skill omogućuje orkestratoru i rojevima agenata brzo i pouzdano generiranje, modularno uređivanje, testiranje i objavu interaktivnih prezentacijskih mikrosajtova za klijente.

---

## 1. Kad se koristi ovaj skill
- Kad klijentu treba poslati interaktivni web-pitch deck umjesto običnog PDF-a.
- Kad treba napraviti brze izmjene na postojećem decku (uređivanje pojedinog slajda, cijene, videa ili tema).
- Kad postoji ponuda u aplikaciji `Ponude.app` ili PDF datoteka u `/Users/timonterzic/Documents/Ponude/`.
- Kad se prezentacija treba objaviti na `https://varazdin.studio/<client-slug>/`.

---

## 2. Agent-First Modularna Arhitektura

Prezentacije su organizirane u **čiste modularne komponente**, a ne u monolitne datoteke od 4.000 linija:

```
Ponude/
├── deck_engine/                     # Dijeljeni core engine (CSS, JS, teme, layout)
│   ├── core/css/                    # base.css, header.css, footer.css, components.css, mobile.css
│   ├── core/js/                     # audio.js, odometer.js, modal.js, particles.js, cloth.js, navigation.js
│   ├── core/templates/              # layout.html, default_slides/ (01_hero.html ... 06_auth.html)
│   └── themes/                      # eco-utility.json, editorial-canvas.json, dark-luxury.json
│
├── <Klijent>_Prezentacija/          # Modularni workspace projekta
│   ├── deck.json                    # Deklarativni metapodaci, cijene, e-mail, popis slajdova
│   ├── slides/                      # Pojedinačni HTML predlošci (30-50 linija svaki)
│   │   ├── 01_hero.html
│   │   ├── 02_concept.html
│   │   ├── 03_formats.html
│   │   ├── 04_production.html
│   │   ├── 05_offer.html
│   │   └── 06_auth.html
│   ├── custom.css                   # Opcionalni stilski overrides
│   ├── custom.js                    # Opcionalne WebGL cloth teksture
│   ├── index.html                   # Kompajlirani standalone zero-dependency bundle (2.5ms)
│   └── assets/ / slike/             # Fotografije, video thumbovi i PDF-ovi
```

---

## 3. Brze Naredbe za Agente

### A. Uređivanje postojećeg decka:
1. Otvori i uredi samo specifični slajd, npr. `Meridian16_Prezentacija/slides/02_concept.html` ili `deck.json`.
2. Kompajliraj i postavi na web u **2 milisekunde**:
```bash
python3 /Users/timonterzic/Documents/Ponude/scripts/build_deck.py Meridian16_Prezentacija --deploy
```

Za rad uživo uz automatsko rekompajliranje pri svakom spremanju:
```bash
python3 /Users/timonterzic/Documents/Ponude/scripts/build_deck.py Meridian16_Prezentacija --watch --deploy
```

### B. Izrada novog pitch decka iz PDF-a ili Ponude.app:
```bash
# Primjer s PDF ponudom i eco-utility temom:
python3 /Users/timonterzic/Documents/Ponude/scripts/orchestrate_presentation.py \
  "/Users/timonterzic/Documents/Ponude/Ponuda_Grad_Varazdin_Studio_Varazdin.pdf" \
  --slug "komunalni-projekt" \
  --theme "eco-utility"

# Primjer s Dark Luxury temom:
python3 /Users/timonterzic/Documents/Ponude/scripts/orchestrate_presentation.py \
  "/Users/timonterzic/Documents/Ponude/KB_Ponuda_Paket_16.pdf" \
  --slug "kb-pogon" \
  --theme "dark-luxury"
```

Dostupne teme:
- `eco-utility` (Zelena, bijela ciklorama, komunalni i eko projekti)
- `editorial-canvas` (Topli papir, logistika, industrija, Meridian 16 stil)
- `dark-luxury` (Tamnozelena/zlatna, filmska raskoš, kulturni i premium projekti)

---

## 4. QA Audit i Validacija

Prije svakog git pusha provjeri usklađenost:
```bash
python3 /Users/timonterzic/Documents/Ponude/scripts/validate_deck.py "/Users/timonterzic/Documents/Ponude/Meridian16_Prezentacija/index.html"
```

Provjere uključuju:
- 6 slajdova s 16:9 omjerom pozornice
- Centrirani liquid morphing pill glider i rolling odometer
- Web Audio API haptiku i CanvasUI ambijentalne čestice
- Mobilno responzivno vertikalno skrolanje
- Usklađenost s `naracija/SKILL.md` (0 AI klišeja, točne činjenice i dijakritici)

---

## 5. Objava na varazdin.studio

Nakon što je kompajlirana prezentacija (`--deploy` flag je automatski postavlja u `varazdin.studio/website/<slug>/`):
```bash
cd "/Users/timonterzic/Documents/Studio Varazdin/varazdin.studio"
git add website/<client-slug>/
git commit -m "feat: dodana prezentacija za klijenta <client-slug>"
git push origin main
```
cPanel deployment automatski postavlja stranicu na `https://varazdin.studio/<client-slug>/`.

---

## 6. Resursi i specijalizirani mehanizmi
- **[CanvasUI 3D WebGL Cloth Blueprint](file:///Users/timonterzic/Documents/Ponude/.agents/skills/presentation-deck-builder/resources/CANVAS_UI_CLOTH_ENGINE.md):** Kompletna arhitektura, shaderski kod, parametri i primjeri za viseće kartice i zastave na jarbolu.
