#!/Users/timonterzic/Documents/Ponude/venv/bin/python
"""
validate_deck.py — QA Auditor for presentation microsites.
Validates structure, 16:9 stage, interactions, diacritics, and zero-AI-cliché copywriting.
"""

import sys
import os
import re

BANNED_AI_PHRASES = [
    "zaronite u", "uronite u", "otkrijte čaroliju", "pravi dragulj",
    "biser sjevera", "kamen temeljac", "bogata povijest", "kulturna baština",
    "jedinstveno iskustvo", "nezaboravan doživljaj", "spoj tradicije i suvremenosti",
    "u srcu grada", "oaza mira", "čeka da bude otkriven", "priča koja traje",
    "ostavlja bez daha", "ne ostavlja ravnodušnim", "svjedoči o vremenu",
    "ključno je napomenuti", "u današnje vrijeme", "dobrodošli u svijet"
]

REQUIRED_CHECKS = [
    {"name": "Header", "patterns": ["deck-header"]},
    {"name": "Brand Mark", "patterns": ["brand-mark"]},
    {"name": "Deck Stage", "patterns": ["deck-stage"]},
    {"name": "Slide Wrapper", "patterns": ["slide-wrapper"]},
    {"name": "Headings", "patterns": ["quote-title"]},
    {"name": "Footer", "patterns": ["deck-footer"]},
    {"name": "Odometer Counter", "patterns": ["odometer", "digit-wheel", "odometer-box", "slideCounter", "slide-counter", "slideCurNum", "counter-cur"]},
    {"name": "Centered Pagination Track", "patterns": ["footer-center", "slide-dots-track"]},
    {"name": "Pagination Glider / Pills", "patterns": ["nav-pill", "slide-dot", "slide-dot-glider"]},
    {"name": "Navigation Arrows", "patterns": ["btn-nav-arrow", "btn-deck-nav", "btnNext"]},
    {"name": "CanvasUI Particles", "patterns": ["canvasUiParticles", "initParticleCanvas"]},
    {"name": "Video Modal", "patterns": ["modal-backdrop", "video-modal-backdrop", "openVideoModal"]}
]

def validate_presentation(file_path):
    print(f"==================================================")
    print(f"AUDITING PRESENTATION DECK: {file_path}")
    print(f"==================================================")

    if not os.path.exists(file_path):
        print(f"❌ ERROR: File does not exist: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        html = f.read()

    errors = []
    warnings = []

    # 1. Check Slide Count (Must have 5 to 8 slides)
    slides = re.findall(r'<section class=["\']slide[^"\']*["\']', html)
    slide_count = len(slides)
    if slide_count < 5 or slide_count > 8:
        warnings.append(f"Expected 6 slides, found {slide_count}.")
    else:
        print(f"✓ Slide structure verified: {slide_count} slides present.")

    # 2. Check Required Structural Components with Aliases
    for check in REQUIRED_CHECKS:
        name = check["name"]
        found = any(p in html for p in check["patterns"])
        if not found:
            errors.append(f"Missing required component: {name} (looked for: {', '.join(check['patterns'])})")
        else:
            print(f"✓ Component verified: {name}")

    # 3. Check Audio & Interaction Engine
    if "AudioContext" not in html and "webkitAudioContext" not in html:
        errors.append("Missing Web Audio API synthesis for zero-dependency haptics.")
    else:
        print("✓ Audio haptics engine present (Web Audio API).")

    if "triggerCanvasUiWind" not in html:
        warnings.append("Missing CanvasUI wind trigger on slide change.")
    else:
        print("✓ CanvasUI particle & wind physics present.")

    # 4. Check Mobile & Print Breakpoints
    if "@media (max-width: 768px)" not in html and "@media(max-width:768px)" not in html:
        errors.append("Missing mobile responsive fallback stylesheet (@media max-width: 768px).")
    else:
        print("✓ Mobile responsive fallback stylesheet present.")

    if "@media print" not in html and "@media print" not in html:
        errors.append("Missing print stylesheet for 16:9 PDF export (@media print).")
    else:
        print("✓ High-res 16:9 print stylesheet present.")

    # 5. Copywriting Audit: Check for Banned AI Clichés
    lower_html = html.lower()
    found_banned = []
    for phrase in BANNED_AI_PHRASES:
        if phrase in lower_html:
            found_banned.append(phrase)

    if found_banned:
        errors.append(f"AI Cliché detected ({len(found_banned)} matches): {', '.join(found_banned)}")
    else:
        print("✓ Naracija audit passed: Zero AI clichés detected.")

    # 6. Check Diacritics
    has_croatian_chars = any(c in html for c in ['č', 'ć', 'ž', 'š', 'đ', 'Č', 'Ć', 'Ž', 'Š', 'Đ'])
    if not has_croatian_chars:
        warnings.append("No Croatian diacritics found (ensure proper localized spelling).")
    else:
        print("✓ Croatian diacritics verified (č, ć, ž, š, đ).")

    print("\n--------------------------------------------------")
    if errors:
        print(f"❌ AUDIT FAILED with {len(errors)} error(s):")
        for e in errors:
            print(f"  - {e}")
        return False
    
    if warnings:
        print(f"⚠️ AUDIT PASSED with {len(warnings)} warning(s):")
        for w in warnings:
            print(f"  - {w}")
    else:
        print("🎉 AUDIT PASSED: 100% Compliant with AGENTS.md Presentation Standard!")

    return True

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else "/Users/timonterzic/Documents/Ponude/Komunalni_Prezentacija/index.html"
    success = validate_presentation(target)
    sys.exit(0 if success else 1)
