#!/usr/bin/env python3
"""
generate_quote_pdfs.py — Generates official Studio Varaždin PDF quotes for Meridian 16
matching the exact HTML/CSS template in Ponude.app / PDFGenerator.swift.
"""

import os
import subprocess
import tempfile
from pathlib import Path

CHROME_BIN = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUTPUT_DIR = Path("/Users/timonterzic/Documents/Ponude/Meridian16_Prezentacija")
PONUDE_DIR = Path("/Users/timonterzic/Documents/Ponude")

def get_studio_quote_html(
    title="QUOTE",
    number="15",
    date="31.08.2026.",
    place="Varaždin",
    items=None,
    total="17.000,00",
    notes_html="",
    producer="Timon Terzić",
    email="timon.terzic@gmail.com"
):
    if items is None:
        items = []

    rows_html = ""
    for it in items:
        rows_html += f"""
        <tr>
            <td>
                <div class="item-name">{it['name']}</div>
                <div class="item-description-label">SCOPE:</div>
                <div class="item-description">{it['desc']}</div>
            </td>
            <td class="text-right font-bold">{it['qty']}</td>
            <td class="text-right">{it['price']}</td>
            <td class="text-right font-bold">{it['amount']}</td>
        </tr>
        """

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <style>
        @page {{ size: A4; margin: 0; }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        
        body {{
            font-family: -apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif;
            font-size: 10px;
            color: #333;
            width: 595px;
            min-height: 842px;
            position: relative;
            background: #FAFAF8;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }}
        
        /* ── HEADER: Rich black with gold frame ── */
        .header {{
            background: #0D0D0D;
            text-align: center;
            padding: 14px 48px;
            position: relative;
        }}
        
        .header::before {{
            content: '';
            position: absolute;
            top: 6px; left: 16px; right: 16px; bottom: 6px;
            border: 0.5px solid rgba(197,165,90,0.35);
        }}
        
        .corner {{ position: absolute; width: 12px; height: 12px; }}
        .corner::before, .corner::after {{
            content: '';
            position: absolute;
            background: rgba(197,165,90,0.5);
        }}
        .corner-tl {{ top: 3px; left: 13px; }}
        .corner-tl::before {{ width: 12px; height: 1px; top: 0; left: 0; }}
        .corner-tl::after {{ width: 1px; height: 12px; top: 0; left: 0; }}
        .corner-tr {{ top: 3px; right: 13px; }}
        .corner-tr::before {{ width: 12px; height: 1px; top: 0; right: 0; }}
        .corner-tr::after {{ width: 1px; height: 12px; top: 0; right: 0; }}
        .corner-bl {{ bottom: 3px; left: 13px; }}
        .corner-bl::before {{ width: 12px; height: 1px; bottom: 0; left: 0; }}
        .corner-bl::after {{ width: 1px; height: 12px; bottom: 0; left: 0; }}
        .corner-br {{ bottom: 3px; right: 13px; }}
        .corner-br::before {{ width: 12px; height: 1px; bottom: 0; right: 0; }}
        .corner-br::after {{ width: 1px; height: 12px; bottom: 0; right: 0; }}
        
        .brand-top {{
            font-size: 9px;
            font-weight: 300;
            letter-spacing: 6px;
            color: rgba(197,165,90,0.65);
            margin-bottom: 2px;
        }}
        
        .brand-main {{
            font-size: 24px;
            font-weight: 700;
            letter-spacing: 4px;
            color: #C5A55A;
            font-family: Georgia, 'Times New Roman', serif;
        }}
        
        /* ── TITLE: Gold dividers ── */
        .title-band {{
            text-align: center;
            padding: 10px 48px 8px;
        }}
        
        .title-line {{
            height: 1.5px;
            background: #C5A55A;
            margin: 0;
        }}
        
        .title-text {{
            font-family: Georgia, 'Times New Roman', serif;
            font-size: 32px;
            font-weight: 400;
            letter-spacing: 6px;
            color: #C5A55A;
            padding: 10px 0;
        }}
        
        /* ── CONTENT ── */
        .content {{ padding: 18px 48px 0; }}
        
        .parties {{
            display: flex;
            gap: 30px;
            margin-bottom: 12px;
        }}
        
        .party {{
            flex: 1;
            font-size: 9px;
            line-height: 1.6;
            color: #777;
        }}
        .party strong {{ color: #333; display: block; margin-bottom: 2px; }}
        
        .metadata {{
            font-size: 9px;
            line-height: 1.8;
            color: #777;
            margin-bottom: 12px;
        }}
        .metadata .value {{ color: #333; font-weight: 500; }}
        
        /* ── TABLE ── */
        table {{ width: 100%; border-collapse: collapse; font-size: 9px; table-layout: fixed; }}
        
        thead th {{
            text-align: left;
            font-weight: 700;
            font-size: 9px;
            color: #333;
            padding: 7px 6px;
            border-top: 0.5px solid rgba(197,165,90,0.3);
            border-bottom: 0.5px solid rgba(197,165,90,0.3);
        }}
        thead th:first-child {{ padding-left: 0; }}
        thead th:last-child {{ padding-right: 0; }}
        thead th:nth-child(2),
        thead th:nth-child(3),
        thead th:nth-child(4) {{ text-align: right; }}
        
        tbody td {{
            padding: 6.5px 6px;
            vertical-align: top;
            border-bottom: 0.3px solid rgba(197,165,90,0.2);
            color: #333;
            font-size: 8.8px;
        }}
        tbody td:first-child {{ padding-left: 0; }}
        tbody td:last-child {{ padding-right: 0; }}
        
        .text-right {{
            text-align: right;
            font-family: 'SF Mono', 'Menlo', monospace;
            font-size: 8.8px;
            white-space: nowrap;
        }}
        .font-bold {{ font-weight: 600; }}
        .item-name {{ word-wrap: break-word; overflow-wrap: break-word; font-weight: 600; color: #111; }}
        .item-description-label {{ font-size: 7.2px; color: #999; margin-top: 3px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; }}
        .item-description {{ font-size: 8px; color: #666; margin-top: 1px; line-height: 1.45; word-wrap: break-word; overflow-wrap: break-word; }}
        
        /* ── TOTALS ── */
        .totals {{ margin-top: 0; }}
        .total-row {{
            display: flex;
            justify-content: flex-end;
            align-items: center;
            padding: 6px 0;
            border-bottom: 0.5px solid rgba(197,165,90,0.3);
            font-size: 9.5px;
        }}
        .total-row.main {{ font-weight: 800; font-size: 11px; }}
        .total-row.main .total-value {{ color: #C5A55A; }}
        .total-label {{ font-weight: 700; color: #333; margin-right: 12px; }}
        .total-value {{
            font-family: 'SF Mono', 'Menlo', monospace;
            color: #333;
            min-width: 100px;
            text-align: right;
        }}
        
        /* ── NOTES ── */
        .notes {{ margin-top: 12px; font-size: 8.2px; color: #666; line-height: 1.55; }}
        .notes p {{ margin-bottom: 3px; }}
        
        /* ── FOOTER ── */
        .footer {{
            position: absolute;
            bottom: 0; left: 0; right: 0;
            background: #0D0D0D;
            display: flex;
            justify-content: space-between;
            padding: 8px 48px;
            font-size: 8px;
            color: rgba(197,165,90,0.6);
        }}
    </style>
</head>
<body>
    <div class="header">
        <div class="corner corner-tl"></div>
        <div class="corner corner-tr"></div>
        <div class="corner corner-bl"></div>
        <div class="corner corner-br"></div>
        <div class="brand-top">STUDIO</div>
        <div class="brand-main">VARAŽDIN</div>
    </div>
    
    <div class="title-band">
        <div class="title-line"></div>
        <div class="title-text">{title}</div>
        <div class="title-line"></div>
    </div>
    
    <div class="content">
        <div class="parties">
            <div class="party">
                <strong>STUDIO VARAŽDIN, obrt za usluge</strong>
                Vl. Jasenka Martinčević<br>
                Lead Producer: {producer}<br>
                S. Vraza 10, 42000 Varaždin<br>
                OIB: 63287352089<br>
                IBAN: HR9223600001103240533<br>
                E-mail: {email}
            </div>
            <div class="party">
                <strong>MERIDIAN 16 BUSINESS PARK D.O.O.</strong>
                Ulica Matije Slatinskog 11<br>
                10410 Velika Gorica<br>
                OIB: 30404467903
            </div>
        </div>
        
        <div class="metadata">
            <span class="label">No.:</span> <span class="value">{number}</span><br>
            <span class="label">Place:</span> <span class="value">{place}</span><br>
            <span class="label">Date:</span> <span class="value">{date}</span>
        </div>
        
        <table>
            <colgroup>
                <col style="width: 55%">
                <col style="width: 12%">
                <col style="width: 15%">
                <col style="width: 18%">
            </colgroup>
            <thead>
                <tr>
                    <th>Description</th>
                    <th>Qty</th>
                    <th>Price</th>
                    <th>Amount EUR</th>
                </tr>
            </thead>
            <tbody>
                {rows_html}
            </tbody>
        </table>
        
        <div class="totals">
            <div class="total-row">
                <span class="total-label">Total:</span>
                <span class="total-value">{total} EUR</span>
            </div>
            <div class="total-row main">
                <span class="total-label">Total due (EUR):</span>
                <span class="total-value">{total}</span>
            </div>
        </div>
        
        <div class="notes">
            {notes_html}
        </div>
    </div>
    
    <div class="footer">
        <span>varazdin.studio</span>
        <span>Flat-rate business (VAT exempt)</span>
    </div>
</body>
</html>"""

def render_html_to_pdf(html_content, output_pdf_path):
    with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False, encoding='utf-8') as f:
        f.write(html_content)
        temp_html = f.name

    try:
        cmd = [
            CHROME_BIN,
            "--headless=new",
            "--disable-gpu",
            "--no-pdf-header-footer",
            f"--print-to-pdf={output_pdf_path}",
            temp_html
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(f"✅ Generated PDF -> {output_pdf_path}")
    finally:
        if os.path.exists(temp_html):
            os.remove(temp_html)

def build_option_a():
    items = [
        {
            "name": "(1) Pre-production",
            "desc": "Concept, script, moodboard, location scout and coordination with the client.",
            "qty": "1,00",
            "price": "1.300,00",
            "amount": "1.300,00"
        },
        {
            "name": "(2) Staged filming",
            "desc": "Extended scope: more angles and setups, cinema gear, up to 10 FPV flights, timelapse and drone-lapse series at peak traffic.",
            "qty": "1,00",
            "price": "7.900,00",
            "amount": "7.900,00"
        },
        {
            "name": "(3) Leadership Interview",
            "desc": "Two cameras and gimbal, designed lighting. Version up to 2:30 + short cuts for social media.",
            "qty": "1,00",
            "price": "1.200,00",
            "amount": "1.200,00"
        },
        {
            "name": "(4) Editing & post-production",
            "desc": "Hero film up to 2:30 (16:9, 4K) + 4 verticals. Colour grade, sound, licensed music.",
            "qty": "1,00",
            "price": "2.600,00",
            "amount": "2.600,00"
        },
        {
            "name": "(5) Source footage & rights transfer",
            "desc": "All footage and full usage rights transfer to the client.",
            "qty": "1,00",
            "price": "0,00",
            "amount": "0,00"
        }
    ]

    notes = """
    <p>VAT not charged: flat-rate business, Article 90(2) of the Croatian VAT Act.</p>
    <p>Valid for 30 days</p>
    <p>Concept: “Where economy meets ecology”. Filming schedule in Autumn 2026 as agreed. Delivery within 14 days of the shoot; 2 revision rounds included. VAT not charged.</p>
    """

    html = get_studio_quote_html(
        title="QUOTE",
        number="14",
        date="31.08.2026.",
        place="Varaždin",
        items=items,
        total="13.000,00",
        notes_html=notes
    )

    out_deck = OUTPUT_DIR / "Quote_No9_OptionA_13000.pdf"
    out_root = PONUDE_DIR / "Meridian16_Quote14_EN_PREMIUM_13000.pdf"
    render_html_to_pdf(html, out_deck)
    render_html_to_pdf(html, out_root)

def build_option_b():
    items = [
        {
            "name": "(1) Pre-production",
            "desc": "Concept, script, dedicated storyboard team, location scout, FPV route test, client photo archive integration, and pre-written narration for Ivana and Richard.",
            "qty": "1,00",
            "price": "1.900,00",
            "amount": "1.900,00"
        },
        {
            "name": "(2) Staged filming",
            "desc": "Full scope of the concept: large-format cinema camera, all planned setups and angles. Full FPV package with spotter and route tests, long stationary and aerial timelapses/dronelapses at dawn and peak traffic, capturing sweeping shadows and green corridors.",
            "qty": "1,00",
            "price": "10.400,00",
            "amount": "10.400,00"
        },
        {
            "name": "(3) Leadership Interview (Ivana & Richard)",
            "desc": "Two cameras, gimbal, designed lighting, teleprompter. Version up to 2:30 + short cuts for social media.",
            "qty": "1,00",
            "price": "1.500,00",
            "amount": "1.500,00"
        },
        {
            "name": "(4) Editing & post-production",
            "desc": "Hero film up to 2:30 with pre-written narration (16:9, 4K), 60-second teaser trailer + 4 verticals. Master cinema colour grade, custom sound design, and bespoke music composition.",
            "qty": "1,00",
            "price": "3.200,00",
            "amount": "3.200,00"
        },
        {
            "name": "(5) Source footage & rights transfer",
            "desc": "All footage and full usage rights transfer to the client.",
            "qty": "1,00",
            "price": "0,00",
            "amount": "0,00"
        }
    ]

    notes = """
    <p>VAT not charged: flat-rate business, Article 90(2) of the Croatian VAT Act.</p>
    <p>Valid for 30 days</p>
    <p>Concept: “Where economy meets ecology”. Filming schedule in Autumn 2026 as agreed. Delivery within 14 days of the shoot; 3 revision rounds included. VAT not charged.</p>
    """

    html = get_studio_quote_html(
        title="QUOTE",
        number="15",
        date="31.08.2026.",
        place="Varaždin",
        items=items,
        total="17.000,00",
        notes_html=notes
    )

    out_deck = OUTPUT_DIR / "Quote_No15_OptionB_17000.pdf"
    out_root = PONUDE_DIR / "Meridian16_Quote15_EN_SIGNATURE_17000.pdf"
    render_html_to_pdf(html, out_deck)
    render_html_to_pdf(html, out_root)

if __name__ == '__main__':
    build_option_a()
    build_option_b()
