#!/Users/timonterzic/Documents/Ponude/venv/bin/python
"""
fetch_ponuda.py — Extracts structured offer data from either:
1. Live Ponude.app HTTP API (http://127.0.0.1:8765)
2. Local Ponude PDF files in /Users/timonterzic/Documents/Ponude/
"""

import os
import sys
import json
import re
import urllib.request
import urllib.error
import PyPDF2

TOKEN_PATH = os.path.expanduser('~/Library/Application Support/hr.lotusrc.ponude/api-token.txt')
API_URL = 'http://127.0.0.1:8765'

def get_api_token():
    if os.path.exists(TOKEN_PATH):
        with open(TOKEN_PATH, 'r', encoding='utf-8') as f:
            return f.read().strip()
    return None

def fetch_from_api(query=None, limit=20):
    token = get_api_token()
    if not token:
        return None
    try:
        url = f"{API_URL}/ponude?limit={limit}"
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
        with urllib.request.urlopen(req, timeout=2) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            return data
    except Exception as e:
        return None

def parse_pdf_ponuda(pdf_path):
    if not os.path.exists(pdf_path):
        return None
    
    reader = PyPDF2.PdfReader(pdf_path)
    full_text = ""
    for page in reader.pages:
        full_text += (page.extract_text() or "") + "\n"

    text = full_text.strip()
    
    # Extract Quote / Ponuda Number
    num_match = re.search(r'(?:Broj|No\.?):\s*([0-9]+)', text, re.IGNORECASE)
    broj = num_match.group(1) if num_match else "1"

    # Extract Date
    date_match = re.search(r'(?:Datum|Date):\s*([0-9]{2}\.[0-9]{2}\.[0-9]{4}\.?)', text, re.IGNORECASE)
    datum = date_match.group(1) if date_match else ""

    # Extract Client Info
    client_name = "Klijent"
    client_oib = ""
    client_address = ""

    if "MERIDIAN 16" in text.upper():
        client_name = "MERIDIAN 16 BUSINESS PARK D.O.O."
        client_oib = "30404467903"
        client_address = "Ulica Matije Slatinskog 11, 10410 Velika Gorica"
    elif "GRAD VARAŽDIN" in text.upper():
        client_name = "GRAD VARAŽDIN"
        client_oib = "13269011531"
        client_address = "Trg kralja Tomislava 1, 42000 Varaždin"
    elif "KB D.O.O." in text.upper() or "SRAČINEC" in text.upper():
        client_name = "KB D.O.O."
        client_oib = "57881852421"
        client_address = "Ulica Vilka Novaka 6, 42209 Sračinec"
    else:
        # Generic extract
        client_match = re.search(r'(?:OIB:\s*([0-9]{11}))', text)
        if client_match:
            client_oib = client_match.group(1)

    # Extract Total Amount
    total_match = re.search(r'(?:Za plaćanje|Total due|Ukupno|Total)[^\d]*([0-9\.\,]+)\s*(?:EUR|€)?', text, re.IGNORECASE)
    total_str = total_match.group(1) if total_match else "0,00"
    
    # Extract line items with precise split
    items = []
    # Split by (1), (2), (3), etc.
    item_splits = re.split(r'\(([0-9]+)\)\s*', text)
    if len(item_splits) > 1:
        # First element is preamble
        for i in range(1, len(item_splits), 2):
            idx = int(item_splits[i])
            chunk = item_splits[i+1]
            
            # Remove subsequent total/footer if in last chunk
            chunk = re.split(r'(?:Ukupno:|Total:|Oslobođeno|Informativna|VAT not charged)', chunk)[0].strip()
            
            lines = [l.strip() for l in chunk.split('\n') if l.strip()]
            title = lines[0] if lines else f"Stavka {idx}"
            
            # Find price numbers in chunk (e.g. 1.000,00)
            prices = re.findall(r'([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2})', chunk)
            price = prices[-1] if prices else "0,00"
            
            # Clean description
            desc_text = " ".join(lines[1:]) if len(lines) > 1 else ""
            desc_text = re.sub(r'(?:POPIS ISPORUKA:|SCOPE:)', '', desc_text).strip()
            desc_text = re.sub(r'[0-9\.\,]+\s*(?:EUR|€)?', '', desc_text).strip()

            items.append({
                "index": idx,
                "title": title,
                "description": desc_text,
                "price": price + " €"
            })

    return {
        "source": "pdf",
        "file_path": pdf_path,
        "broj": broj,
        "datum": datum,
        "client": {
            "name": client_name,
            "oib": client_oib,
            "address": client_address
        },
        "total": total_str + " EUR",
        "items": items,
        "raw_text": full_text
    }

def main():
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if os.path.exists(target):
            data = parse_pdf_ponuda(target)
            print(json.dumps(data, indent=2, ensure_ascii=False))
            return

    # Try live API
    api_data = fetch_from_api()
    if api_data:
        print(json.dumps({"source": "api", "data": api_data}, indent=2, ensure_ascii=False))
        return

    # Fallback to listing PDFs in Ponude folder
    ponude_dir = "/Users/timonterzic/Documents/Ponude"
    pdfs = [os.path.join(ponude_dir, f) for f in os.listdir(ponude_dir) if f.endswith('.pdf')]
    results = []
    for p in sorted(pdfs):
        parsed = parse_pdf_ponuda(p)
        if parsed and parsed.get('items'):
            results.append(parsed)

    print(json.dumps({"source": "local_pdfs", "count": len(results), "ponude": results}, indent=2, ensure_ascii=False))

if __name__ == '__main__':
    main()
