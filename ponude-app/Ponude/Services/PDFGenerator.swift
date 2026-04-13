import AppKit
import WebKit

/// Generates PDF documents from quotes using WebKit HTML rendering.
/// Uses an offscreen window to ensure WKWebView can render properly,
/// and a navigation delegate to wait for full content load before export.
///
/// Each company gets a distinct PDF design:
///   • Lotus RC — Cinematic dark navy, bold sans-serif
///   • Studio Varaždin — Black/gold ornamental, premium serif
///   • Lovements — Soft blush, rose-gold, wedding elegance
final class PDFGenerator: NSObject {
    
    /// Static set to keep PDFGenerator instances alive during async rendering.
    /// Without this, the generator (created as a local var) gets deallocated
    /// before WKWebView finishes its async HTML load + PDF export.
    private static var activeGenerators: Set<PDFGenerator> = []
    
    /// Retained references to keep WKWebView alive during async rendering
    private var webView: WKWebView?
    private var offscreenWindow: NSWindow?
    private var outputURL: URL?
    private var navigationDelegate: PDFNavigationDelegate?
    
    /// Export a quote as a PDF, presenting a save dialog to the user.
    func exportQuote(
        businessProfile: BusinessProfile,
        client: Client?,
        ponudaBroj: Int,
        datum: Date,
        mjesto: String,
        stavke: [StavkaEditItem],
        ukupno: Decimal,
        napomena: String,
        rokValjanosti: Int
    ) {
        let html = generateHTML(
            businessProfile: businessProfile,
            client: client,
            ponudaBroj: ponudaBroj,
            datum: datum,
            mjesto: mjesto,
            stavke: stavke,
            ukupno: ukupno,
            napomena: napomena,
            rokValjanosti: rokValjanosti
        )
        
        // Create save panel
        let panel = NSSavePanel()
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd_HHmmss"
            return f.string(from: Date())
        }()
        panel.nameFieldStringValue = "\(ponudaBroj)-Ponuda_\(dateStr).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.title = "Spremi ponudu kao PDF"
        
        // Retain self so we survive the async WKWebView rendering cycle
        PDFGenerator.activeGenerators.insert(self)
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                PDFGenerator.activeGenerators.remove(self)
                return
            }
            DispatchQueue.main.async {
                self.renderHTMLtoPDF(html: html, outputURL: url)
            }
        }
    }
    
    // MARK: - HTML to PDF Rendering
    
    private func renderHTMLtoPDF(html: String, outputURL: URL) {
        self.outputURL = outputURL
        
        // Create an offscreen window so WKWebView has a proper view hierarchy
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 595, height: 842),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        // Position off-screen so it's invisible
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        self.offscreenWindow = window
        
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
        window.contentView = wv
        self.webView = wv
        
        // Set up navigation delegate to know when loading finishes
        let navDelegate = PDFNavigationDelegate(
            onFinished: { [weak self] in
                self?.performPDFExport()
            },
            onFailed: { [weak self] error in
                print("[PDF] WebView navigation failed: \(error.localizedDescription)")
                self?.cleanup()
            }
        )
        self.navigationDelegate = navDelegate
        wv.navigationDelegate = navDelegate
        
        print("[PDF] Loading HTML into WebView...")
        wv.loadHTMLString(html, baseURL: nil)
    }
    
    private func performPDFExport() {
        guard let webView = self.webView, let url = self.outputURL else {
            print("[PDF] Missing webView or outputURL")
            cleanup()
            return
        }
        
        print("[PDF] WebView loaded, creating PDF...")
        
        let config = WKPDFConfiguration()
        // A4 in points: 595.28 × 841.89
        config.rect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        
        webView.createPDF(configuration: config) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: url)
                        NSWorkspace.shared.open(url)
                        print("[PDF] ✅ Successfully exported to \(url.path)")
                    } catch {
                        print("[PDF] ❌ Failed to write: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    print("[PDF] ❌ Render error: \(error.localizedDescription)")
                }
                self?.cleanup()
            }
        }
    }
    
    private func cleanup() {
        print("[PDF] Cleaning up...")
        offscreenWindow?.close()
        offscreenWindow = nil
        webView = nil
        navigationDelegate = nil
        outputURL = nil
        // Release the self-retention
        PDFGenerator.activeGenerators.remove(self)
    }
    
    // MARK: - HTML Generation (dispatches to per-company template)
    
    private func generateHTML(
        businessProfile: BusinessProfile,
        client: Client?,
        ponudaBroj: Int,
        datum: Date,
        mjesto: String,
        stavke: [StavkaEditItem],
        ukupno: Decimal,
        napomena: String,
        rokValjanosti: Int
    ) -> String {
        let style = QuoteTemplateStyle.style(for: businessProfile)
        let logoBase64 = loadLogoBase64(for: style, businessProfile: businessProfile)
        
        switch style {
        case .lotusRC:
            return generateLotusHTML(
                businessProfile: businessProfile, client: client,
                ponudaBroj: ponudaBroj, datum: datum, mjesto: mjesto,
                stavke: stavke, ukupno: ukupno, napomena: napomena,
                rokValjanosti: rokValjanosti, logoBase64: logoBase64
            )
        case .studioVarazdin:
            return generateStudioHTML(
                businessProfile: businessProfile, client: client,
                ponudaBroj: ponudaBroj, datum: datum, mjesto: mjesto,
                stavke: stavke, ukupno: ukupno, napomena: napomena,
                rokValjanosti: rokValjanosti, logoBase64: logoBase64
            )
        case .lovements:
            return generateLovementsHTML(
                businessProfile: businessProfile, client: client,
                ponudaBroj: ponudaBroj, datum: datum, mjesto: mjesto,
                stavke: stavke, ukupno: ukupno, napomena: napomena,
                rokValjanosti: rokValjanosti, logoBase64: logoBase64
            )
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - LOTUS RC — Cinematic Bold
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func generateLotusHTML(
        businessProfile: BusinessProfile,
        client: Client?,
        ponudaBroj: Int,
        datum: Date,
        mjesto: String,
        stavke: [StavkaEditItem],
        ukupno: Decimal,
        napomena: String,
        rokValjanosti: Int,
        logoBase64: String?
    ) -> String {
        let tableRows = buildTableRows(stavke: stavke)
        let clientHTML = buildClientHTML(client: client)
        let notesHTML = buildNotesHTML(businessProfile: businessProfile, napomena: napomena, rokValjanosti: rokValjanosti)
        
        return """
        <!DOCTYPE html>
        <html lang="hr">
        <head>
            <meta charset="UTF-8">
            <style>
                @page { size: A4; margin: 0; }
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    font-family: -apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif;
                    font-size: 10px;
                    color: #1E293B;
                    width: 595px;
                    height: 842px;
                    position: relative;
                    background: #FFFFFF;
                }
                
                /* ── HEADER: Dark navy ── */
                .header {
                    background: #0B1929;
                    text-align: center;
                    padding: 14px 48px;
                }
                
                .header-logo {
                    max-width: 380px;
                    max-height: 50px;
                    display: block;
                    margin: 0 auto;
                    object-fit: contain;
                }
                
                .brand-name {
                    font-size: 28px;
                    font-weight: 900;
                    letter-spacing: 6px;
                    color: #FFFFFF;
                    text-transform: uppercase;
                }
                
                .brand-accent {
                    width: 60px;
                    height: 2px;
                    background: #3B82F6;
                    margin: 6px auto 0;
                }
                
                /* ── TITLE ── */
                .title-band {
                    text-align: center;
                    padding: 12px 48px 0;
                }
                
                .title-text {
                    font-size: 28px;
                    font-weight: 700;
                    letter-spacing: 8px;
                    color: #1E293B;
                    padding: 12px 0;
                }
                
                .title-line {
                    height: 2px;
                    background: #3B82F6;
                    margin: 0;
                }
                
                /* ── CONTENT ── */
                .content { padding: 20px 48px 0; }
                
                .parties {
                    display: flex;
                    gap: 30px;
                    margin-bottom: 14px;
                }
                
                .party {
                    flex: 1;
                    font-size: 9px;
                    line-height: 1.6;
                    color: #64748B;
                }
                .party strong { color: #1E293B; display: block; margin-bottom: 2px; }
                
                .metadata {
                    font-size: 9px;
                    line-height: 1.8;
                    color: #64748B;
                    margin-bottom: 12px;
                }
                .metadata .value { color: #1E293B; font-weight: 500; }
                
                /* ── TABLE ── */
                table { width: 100%; border-collapse: collapse; font-size: 9px; table-layout: fixed; }
                
                thead th {
                    text-align: left;
                    font-weight: 700;
                    font-size: 9px;
                    color: #1E293B;
                    padding: 8px 6px;
                    background: #F1F5F9;
                }
                thead th:first-child { padding-left: 0; }
                thead th:last-child { padding-right: 0; }
                thead th:nth-child(2),
                thead th:nth-child(3),
                thead th:nth-child(4) { text-align: right; }
                
                tbody td {
                    padding: 7px 6px;
                    vertical-align: top;
                    border-bottom: 0.3px solid #CBD5E1;
                    color: #1E293B;
                    font-size: 9px;
                }
                tbody td:first-child { padding-left: 0; }
                tbody td:last-child { padding-right: 0; }
                
                .text-right {
                    text-align: right;
                    font-family: 'SF Mono', 'Menlo', monospace;
                    font-size: 9px;
                    white-space: nowrap;
                }
                .font-bold { font-weight: 600; }
                .item-name { word-wrap: break-word; overflow-wrap: break-word; }
                .item-description-label { font-size: 7.5px; color: #94A3B8; margin-top: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; }
                .item-description { font-size: 8px; color: #94A3B8; margin-top: 2px; line-height: 1.5; word-wrap: break-word; overflow-wrap: break-word; }
                
                /* ── TOTALS ── */
                .totals { margin-top: 0; }
                .total-row {
                    display: flex;
                    justify-content: flex-end;
                    align-items: center;
                    padding: 8px 0;
                    border-bottom: 0.5px solid #CBD5E1;
                    font-size: 10px;
                }
                .total-row.main { font-weight: 800; font-size: 11px; }
                .total-row.main .total-value { color: #3B82F6; }
                .total-label { font-weight: 700; color: #1E293B; margin-right: 12px; }
                .total-value {
                    font-family: 'SF Mono', 'Menlo', monospace;
                    color: #1E293B;
                    min-width: 100px;
                    text-align: right;
                }
                
                /* ── NOTES ── */
                .notes { margin-top: 14px; font-size: 8.5px; color: #64748B; line-height: 1.6; }
                .notes p { margin-bottom: 4px; }
                
                /* ── FOOTER ── */
                .footer {
                    position: absolute;
                    bottom: 0; left: 0; right: 0;
                    background: #0B1929;
                    display: flex;
                    justify-content: space-between;
                    padding: 9px 48px;
                    font-size: 8.5px;
                    color: rgba(255,255,255,0.6);
                }
            </style>
        </head>
        <body>
            <div class="header">
                \(logoBase64 != nil ? "<img class=\"header-logo\" src=\"\(logoBase64!)\" alt=\"\(escapeHTML(businessProfile.shortName))\">" : "<div class=\"brand-name\">\(escapeHTML(businessProfile.shortName))</div><div class=\"brand-accent\"></div>")
            </div>
            
            <div class="title-band">
                <div class="title-text">PONUDA</div>
                <div class="title-line"></div>
            </div>
            
            <div class="content">
                <div class="parties">
                    <div class="party">
                        <strong>\(escapeHTML(businessProfile.name))</strong>
                        Vl. \(escapeHTML(businessProfile.ownerName))<br>
                        \(escapeHTML(businessProfile.fullAddress))<br>
                        \(!businessProfile.oib.isEmpty ? "OIB: \(escapeHTML(businessProfile.oib))<br>" : "")
                        \(!businessProfile.iban.isEmpty ? "IBAN: \(escapeHTML(businessProfile.iban))<br>" : "")
                        \(!businessProfile.phone.isEmpty ? "Tel.: \(escapeHTML(businessProfile.phone))<br>" : "")
                        \(!businessProfile.email.isEmpty ? "E-mail: \(escapeHTML(businessProfile.email))" : "")
                    </div>
                    <div class="party">
                        \(clientHTML)
                    </div>
                </div>
                
                <div class="metadata">
                    <span class="label">Broj:</span> <span class="value">\(ponudaBroj)</span><br>
                    \(!mjesto.isEmpty ? "<span class=\"label\">Mjesto:</span> <span class=\"value\">\(escapeHTML(mjesto))</span><br>" : "")
                    <span class="label">Datum:</span> <span class="value">\(datum.hrFormatted)</span>
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
                            <th>Vrsta robe odnosno usluga</th>
                            <th>Količina</th>
                            <th>Cijena</th>
                            <th>Vrijednost EUR</th>
                        </tr>
                    </thead>
                    <tbody>
                        \(tableRows)
                    </tbody>
                </table>
                
                <div class="totals">
                    <div class="total-row">
                        <span class="total-label">Ukupno:</span>
                        <span class="total-value">\(ukupno.hrFormatted) EUR</span>
                    </div>
                    <div class="total-row main">
                        <span class="total-label">Za plaćanje EUR:</span>
                        <span class="total-value">\(ukupno.hrFormatted)</span>
                    </div>
                </div>
                
                <div class="notes">
                    \(notesHTML)
                </div>
            </div>
            
            <div class="footer">
                <span>\(!businessProfile.website.isEmpty ? escapeHTML(businessProfile.website) : "")</span>
                <span>\(escapeHTML(businessProfile.taxStatus.rawValue))</span>
            </div>
        </body>
        </html>
        """
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - STUDIO VARAŽDIN — Dark Gold Premium
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func generateStudioHTML(
        businessProfile: BusinessProfile,
        client: Client?,
        ponudaBroj: Int,
        datum: Date,
        mjesto: String,
        stavke: [StavkaEditItem],
        ukupno: Decimal,
        napomena: String,
        rokValjanosti: Int,
        logoBase64: String?
    ) -> String {
        let tableRows = buildTableRows(stavke: stavke)
        let clientHTML = buildClientHTML(client: client)
        let notesHTML = buildNotesHTML(businessProfile: businessProfile, napomena: napomena, rokValjanosti: rokValjanosti)
        let brandParts = splitBrandName(businessProfile.shortName)
        let brandTopHTML = brandParts.top.map { "<div class=\"brand-top\">\($0.uppercased())</div>" } ?? ""
        let brandMainHTML = "<div class=\"brand-main\">\(brandParts.main.uppercased())</div>"
        
        return """
        <!DOCTYPE html>
        <html lang="hr">
        <head>
            <meta charset="UTF-8">
            <style>
                @page { size: A4; margin: 0; }
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    font-family: -apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif;
                    font-size: 10px;
                    color: #333;
                    width: 595px;
                    height: 842px;
                    position: relative;
                    background: #FAFAF8;
                }
                
                /* ── HEADER: Rich black with gold frame ── */
                .header {
                    background: #0D0D0D;
                    text-align: center;
                    padding: 14px 48px;
                    position: relative;
                }
                
                /* Ornamental inner border */
                .header::before {
                    content: '';
                    position: absolute;
                    top: 6px; left: 16px; right: 16px; bottom: 6px;
                    border: 0.5px solid rgba(197,165,90,0.35);
                }
                
                /* Corner brackets */
                .corner { position: absolute; width: 12px; height: 12px; }
                .corner::before, .corner::after {
                    content: '';
                    position: absolute;
                    background: rgba(197,165,90,0.5);
                }
                .corner-tl { top: 3px; left: 13px; }
                .corner-tl::before { width: 12px; height: 1px; top: 0; left: 0; }
                .corner-tl::after { width: 1px; height: 12px; top: 0; left: 0; }
                .corner-tr { top: 3px; right: 13px; }
                .corner-tr::before { width: 12px; height: 1px; top: 0; right: 0; }
                .corner-tr::after { width: 1px; height: 12px; top: 0; right: 0; }
                .corner-bl { bottom: 3px; left: 13px; }
                .corner-bl::before { width: 12px; height: 1px; bottom: 0; left: 0; }
                .corner-bl::after { width: 1px; height: 12px; bottom: 0; left: 0; }
                .corner-br { bottom: 3px; right: 13px; }
                .corner-br::before { width: 12px; height: 1px; bottom: 0; right: 0; }
                .corner-br::after { width: 1px; height: 12px; bottom: 0; right: 0; }
                
                .header-logo {
                    max-width: 380px;
                    max-height: 50px;
                    display: block;
                    margin: 0 auto;
                    object-fit: contain;
                    position: relative;
                    z-index: 1;
                }
                
                .brand-top {
                    font-size: 9px;
                    font-weight: 300;
                    letter-spacing: 6px;
                    color: rgba(197,165,90,0.65);
                    margin-bottom: 2px;
                }
                
                .brand-main {
                    font-size: 24px;
                    font-weight: 700;
                    letter-spacing: 4px;
                    color: #C5A55A;
                    font-family: Georgia, 'Times New Roman', serif;
                }
                
                /* ── TITLE: Gold dividers ── */
                .title-band {
                    text-align: center;
                    padding: 10px 48px 8px;
                }
                
                .title-line {
                    height: 1.5px;
                    background: #C5A55A;
                    margin: 0;
                }
                
                .title-text {
                    font-family: Georgia, 'Times New Roman', serif;
                    font-size: 32px;
                    font-weight: 400;
                    letter-spacing: 6px;
                    color: #C5A55A;
                    padding: 10px 0;
                }
                
                /* ── CONTENT ── */
                .content { padding: 20px 48px 0; }
                
                .parties {
                    display: flex;
                    gap: 30px;
                    margin-bottom: 14px;
                }
                
                .party {
                    flex: 1;
                    font-size: 9px;
                    line-height: 1.6;
                    color: #777;
                }
                .party strong { color: #333; display: block; margin-bottom: 2px; }
                
                .metadata {
                    font-size: 9px;
                    line-height: 1.8;
                    color: #777;
                    margin-bottom: 14px;
                }
                .metadata .value { color: #333; font-weight: 500; }
                
                /* ── TABLE ── */
                table { width: 100%; border-collapse: collapse; font-size: 9px; table-layout: fixed; }
                
                thead th {
                    text-align: left;
                    font-weight: 700;
                    font-size: 9px;
                    color: #333;
                    padding: 8px 6px;
                    border-top: 0.5px solid rgba(197,165,90,0.3);
                    border-bottom: 0.5px solid rgba(197,165,90,0.3);
                }
                thead th:first-child { padding-left: 0; }
                thead th:last-child { padding-right: 0; }
                thead th:nth-child(2),
                thead th:nth-child(3),
                thead th:nth-child(4) { text-align: right; }
                
                tbody td {
                    padding: 7px 6px;
                    vertical-align: top;
                    border-bottom: 0.3px solid rgba(197,165,90,0.2);
                    color: #333;
                    font-size: 9px;
                }
                tbody td:first-child { padding-left: 0; }
                tbody td:last-child { padding-right: 0; }
                
                .text-right {
                    text-align: right;
                    font-family: 'SF Mono', 'Menlo', monospace;
                    font-size: 9px;
                    white-space: nowrap;
                }
                .font-bold { font-weight: 600; }
                .item-name { word-wrap: break-word; overflow-wrap: break-word; }
                .item-description-label { font-size: 7.5px; color: #999; margin-top: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; }
                .item-description { font-size: 8px; color: #999; margin-top: 2px; line-height: 1.5; word-wrap: break-word; overflow-wrap: break-word; }
                
                /* ── TOTALS ── */
                .totals { margin-top: 0; }
                .total-row {
                    display: flex;
                    justify-content: flex-end;
                    align-items: center;
                    padding: 8px 0;
                    border-bottom: 0.5px solid rgba(197,165,90,0.3);
                    font-size: 10px;
                }
                .total-row.main { font-weight: 800; font-size: 11px; }
                .total-row.main .total-value { color: #C5A55A; }
                .total-label { font-weight: 700; color: #333; margin-right: 12px; }
                .total-value {
                    font-family: 'SF Mono', 'Menlo', monospace;
                    color: #333;
                    min-width: 100px;
                    text-align: right;
                }
                
                /* ── NOTES ── */
                .notes { margin-top: 14px; font-size: 8.5px; color: #777; line-height: 1.6; }
                .notes p { margin-bottom: 4px; }
                
                /* ── FOOTER ── */
                .footer {
                    position: absolute;
                    bottom: 0; left: 0; right: 0;
                    background: #0D0D0D;
                    display: flex;
                    justify-content: space-between;
                    padding: 9px 48px;
                    font-size: 8.5px;
                    color: rgba(197,165,90,0.6);
                }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="corner corner-tl"></div>
                <div class="corner corner-tr"></div>
                <div class="corner corner-bl"></div>
                <div class="corner corner-br"></div>
                \(logoBase64 != nil ? "<img class=\"header-logo\" src=\"\(logoBase64!)\" alt=\"\(escapeHTML(businessProfile.shortName))\">" : "\(brandTopHTML)\(brandMainHTML)")
            </div>
            
            <div class="title-band">
                <div class="title-line"></div>
                <div class="title-text">PONUDA</div>
                <div class="title-line"></div>
            </div>
            
            <div class="content">
                <div class="parties">
                    <div class="party">
                        <strong>\(escapeHTML(businessProfile.name))</strong>
                        Vl. \(escapeHTML(businessProfile.ownerName))<br>
                        \(escapeHTML(businessProfile.fullAddress))<br>
                        \(!businessProfile.oib.isEmpty ? "OIB: \(escapeHTML(businessProfile.oib))<br>" : "")
                        \(!businessProfile.iban.isEmpty ? "IBAN: \(escapeHTML(businessProfile.iban))<br>" : "")
                        \(!businessProfile.phone.isEmpty ? "Tel.: \(escapeHTML(businessProfile.phone))<br>" : "")
                        \(!businessProfile.email.isEmpty ? "E-mail: \(escapeHTML(businessProfile.email))" : "")
                    </div>
                    <div class="party">
                        \(clientHTML)
                    </div>
                </div>
                
                <div class="metadata">
                    <span class="label">Broj:</span> <span class="value">\(ponudaBroj)</span><br>
                    \(!mjesto.isEmpty ? "<span class=\"label\">Mjesto:</span> <span class=\"value\">\(escapeHTML(mjesto))</span><br>" : "")
                    <span class="label">Datum:</span> <span class="value">\(datum.hrFormatted)</span>
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
                            <th>Vrsta robe odnosno usluga</th>
                            <th>Količina</th>
                            <th>Cijena</th>
                            <th>Vrijednost EUR</th>
                        </tr>
                    </thead>
                    <tbody>
                        \(tableRows)
                    </tbody>
                </table>
                
                <div class="totals">
                    <div class="total-row">
                        <span class="total-label">Ukupno:</span>
                        <span class="total-value">\(ukupno.hrFormatted) EUR</span>
                    </div>
                    <div class="total-row main">
                        <span class="total-label">Za plaćanje EUR:</span>
                        <span class="total-value">\(ukupno.hrFormatted)</span>
                    </div>
                </div>
                
                <div class="notes">
                    \(notesHTML)
                </div>
            </div>
            
            <div class="footer">
                <span>\(!businessProfile.website.isEmpty ? escapeHTML(businessProfile.website) : "")</span>
                <span>\(escapeHTML(businessProfile.taxStatus.rawValue))</span>
            </div>
        </body>
        </html>
        """
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - LOVEMENTS — Wedding Elegance
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func generateLovementsHTML(
        businessProfile: BusinessProfile,
        client: Client?,
        ponudaBroj: Int,
        datum: Date,
        mjesto: String,
        stavke: [StavkaEditItem],
        ukupno: Decimal,
        napomena: String,
        rokValjanosti: Int,
        logoBase64: String?
    ) -> String {
        let tableRows = buildTableRows(stavke: stavke)
        let clientHTML = buildClientHTML(client: client)
        let notesHTML = buildNotesHTML(businessProfile: businessProfile, napomena: napomena, rokValjanosti: rokValjanosti)
        
        return """
        <!DOCTYPE html>
        <html lang="hr">
        <head>
            <meta charset="UTF-8">
            <style>
                @page { size: A4; margin: 0; }
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    font-family: -apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif;
                    font-size: 10px;
                    color: #5D4647;
                    width: 595px;
                    height: 842px;
                    position: relative;
                    background: #FFFAFA;
                }
                
                /* ── HEADER: Soft blush with ornaments ── */
                .header {
                    background: #FFF5F5;
                    text-align: center;
                    padding: 18px 48px;
                }
                
                .header-ornament {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 10px;
                    margin: 4px 0;
                }
                
                .ornament-line {
                    width: 45px;
                    height: 0.5px;
                    background: rgba(212,160,160,0.5);
                }
                
                .ornament-heart {
                    font-size: 7px;
                    color: rgba(212,160,160,0.6);
                }
                
                .brand-name {
                    font-family: Georgia, 'Times New Roman', serif;
                    font-size: 26px;
                    font-weight: 300;
                    letter-spacing: 4px;
                    color: #B07878;
                    padding: 4px 0;
                }
                
                /* ── TITLE: Delicate rose ── */
                .title-band {
                    text-align: center;
                    padding: 6px 68px 0;
                }
                
                .title-divider {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 12px;
                }
                
                .title-divider-line {
                    flex: 1;
                    height: 0.5px;
                    background: rgba(212,160,160,0.4);
                }
                
                .title-divider-dot {
                    width: 4px;
                    height: 4px;
                    border-radius: 50%;
                    background: rgba(212,160,160,0.5);
                }
                
                .title-text {
                    font-family: Georgia, 'Times New Roman', serif;
                    font-size: 28px;
                    font-weight: 300;
                    letter-spacing: 8px;
                    color: #B07878;
                    padding: 10px 0;
                }
                
                /* ── CONTENT ── */
                .content { padding: 18px 48px 0; }
                
                .parties {
                    display: flex;
                    gap: 30px;
                    margin-bottom: 12px;
                }
                
                .party {
                    flex: 1;
                    font-size: 9px;
                    line-height: 1.6;
                    color: #B08E8E;
                }
                .party strong { color: #5D4647; display: block; margin-bottom: 2px; }
                
                .metadata {
                    font-size: 9px;
                    line-height: 1.8;
                    color: #B08E8E;
                    margin-bottom: 12px;
                }
                .metadata .value { color: #5D4647; font-weight: 500; }
                
                /* ── TABLE ── */
                table { width: 100%; border-collapse: collapse; font-size: 9px; table-layout: fixed; }
                
                thead th {
                    text-align: left;
                    font-weight: 700;
                    font-size: 9px;
                    color: #5D4647;
                    padding: 7px 6px;
                    background: #FFF5F5;
                    border-top: 0.5px solid #F0D4D4;
                    border-bottom: 0.5px solid #F0D4D4;
                }
                thead th:first-child { padding-left: 0; }
                thead th:last-child { padding-right: 0; }
                thead th:nth-child(2),
                thead th:nth-child(3),
                thead th:nth-child(4) { text-align: right; }
                
                tbody td {
                    padding: 7px 6px;
                    vertical-align: top;
                    border-bottom: 0.3px solid #F0D4D4;
                    color: #5D4647;
                    font-size: 9px;
                }
                tbody td:first-child { padding-left: 0; }
                tbody td:last-child { padding-right: 0; }
                
                .text-right {
                    text-align: right;
                    font-family: 'SF Mono', 'Menlo', monospace;
                    font-size: 9px;
                    white-space: nowrap;
                }
                .font-bold { font-weight: 600; }
                .item-name { word-wrap: break-word; overflow-wrap: break-word; }
                .item-description-label { font-size: 7.5px; color: #C9A8A8; margin-top: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; }
                .item-description { font-size: 8px; color: #C9A8A8; margin-top: 2px; line-height: 1.5; word-wrap: break-word; overflow-wrap: break-word; }
                
                /* ── TOTALS ── */
                .totals { margin-top: 0; }
                .total-row {
                    display: flex;
                    justify-content: flex-end;
                    align-items: center;
                    padding: 8px 0;
                    border-bottom: 0.5px solid #F0D4D4;
                    font-size: 10px;
                }
                .total-row.main { font-weight: 800; font-size: 11px; }
                .total-row.main .total-value { color: #B07878; }
                .total-label { font-weight: 700; color: #5D4647; margin-right: 12px; }
                .total-value {
                    font-family: 'SF Mono', 'Menlo', monospace;
                    color: #5D4647;
                    min-width: 100px;
                    text-align: right;
                }
                
                /* ── NOTES ── */
                .notes {
                    margin-top: 12px;
                    font-size: 8.5px;
                    color: #B08E8E;
                    line-height: 1.6;
                    font-family: Georgia, 'Times New Roman', serif;
                }
                .notes p { margin-bottom: 4px; }
                
                /* ── FOOTER ── */
                .footer {
                    position: absolute;
                    bottom: 0; left: 0; right: 0;
                    background: #FFF5F5;
                    border-top: 0.5px solid rgba(212,160,160,0.3);
                    display: flex;
                    justify-content: space-between;
                    padding: 9px 48px;
                    font-size: 8.5px;
                    color: #B08E8E;
                    font-family: Georgia, 'Times New Roman', serif;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="header-ornament">
                    <div class="ornament-line"></div>
                    <div class="ornament-heart">♥</div>
                    <div class="ornament-line"></div>
                </div>
                <div class="brand-name">\(escapeHTML(businessProfile.shortName))</div>
                <div class="header-ornament">
                    <div class="ornament-line"></div>
                    <div class="ornament-heart">♥</div>
                    <div class="ornament-line"></div>
                </div>
            </div>
            
            <div class="title-band">
                <div class="title-divider">
                    <div class="title-divider-line"></div>
                    <div class="title-divider-dot"></div>
                    <div class="title-divider-line"></div>
                </div>
                <div class="title-text">PONUDA</div>
                <div class="title-divider">
                    <div class="title-divider-line"></div>
                    <div class="title-divider-dot"></div>
                    <div class="title-divider-line"></div>
                </div>
            </div>
            
            <div class="content">
                <div class="parties">
                    <div class="party">
                        <strong>\(escapeHTML(businessProfile.name))</strong>
                        Vl. \(escapeHTML(businessProfile.ownerName))<br>
                        \(escapeHTML(businessProfile.fullAddress))<br>
                        \(!businessProfile.oib.isEmpty ? "OIB: \(escapeHTML(businessProfile.oib))<br>" : "")
                        \(!businessProfile.iban.isEmpty ? "IBAN: \(escapeHTML(businessProfile.iban))<br>" : "")
                        \(!businessProfile.phone.isEmpty ? "Tel.: \(escapeHTML(businessProfile.phone))<br>" : "")
                        \(!businessProfile.email.isEmpty ? "E-mail: \(escapeHTML(businessProfile.email))" : "")
                    </div>
                    <div class="party">
                        \(clientHTML)
                    </div>
                </div>
                
                <div class="metadata">
                    <span class="label">Broj:</span> <span class="value">\(ponudaBroj)</span><br>
                    \(!mjesto.isEmpty ? "<span class=\"label\">Mjesto:</span> <span class=\"value\">\(escapeHTML(mjesto))</span><br>" : "")
                    <span class="label">Datum:</span> <span class="value">\(datum.hrFormatted)</span>
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
                            <th>Vrsta robe odnosno usluga</th>
                            <th>Količina</th>
                            <th>Cijena</th>
                            <th>Vrijednost EUR</th>
                        </tr>
                    </thead>
                    <tbody>
                        \(tableRows)
                    </tbody>
                </table>
                
                <div class="totals">
                    <div class="total-row">
                        <span class="total-label">Ukupno:</span>
                        <span class="total-value">\(ukupno.hrFormatted) EUR</span>
                    </div>
                    <div class="total-row main">
                        <span class="total-label">Za plaćanje EUR:</span>
                        <span class="total-value">\(ukupno.hrFormatted)</span>
                    </div>
                </div>
                
                <div class="notes">
                    \(notesHTML)
                </div>
            </div>
            
            <div class="footer">
                <span>\(!businessProfile.website.isEmpty ? escapeHTML(businessProfile.website) : "")</span>
                <span>\(escapeHTML(businessProfile.taxStatus.rawValue))</span>
            </div>
        </body>
        </html>
        """
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Shared HTML Builders
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func buildTableRows(stavke: [StavkaEditItem]) -> String {
        let visibleStavke = stavke.filter { !$0.naziv.isEmpty }
        var tableRows = ""
        for (index, stavka) in visibleStavke.enumerated() {
            let descriptionHTML: String
            if stavka.opis.isEmpty {
                descriptionHTML = ""
            } else {
                // Convert line breaks to <br> and render bullet lines (starting with - or •)
                let formattedDescription = escapeHTML(stavka.opis)
                    .replacingOccurrences(of: "\n", with: "<br>")
                descriptionHTML = """
                    <div class="item-description-label">Popis isporuka:</div>
                    <div class="item-description">\(formattedDescription)</div>
                """
            }
            tableRows += """
            <tr>
                <td class="item-name">
                    (\(index + 1)) \(escapeHTML(stavka.naziv))
                    \(descriptionHTML)
                </td>
                <td class="text-right">\(stavka.kolicina.isEmpty ? "1" : escapeHTML(stavka.kolicina))</td>
                <td class="text-right">\(stavka.cijenaDecimal.hrFormatted)</td>
                <td class="text-right font-bold">\(stavka.formattedVrijednost)</td>
            </tr>
            """
        }
        return tableRows
    }
    
    private func buildClientHTML(client: Client?) -> String {
        if let client = client {
            var lines = [
                "<strong>\(escapeHTML(client.name.uppercased()))</strong>"
            ]
            if !client.address.isEmpty {
                lines.append(escapeHTML(client.address))
            }
            let cityLine = [client.zipCode, client.city].filter { !$0.isEmpty }.joined(separator: " ")
            if !cityLine.isEmpty {
                lines.append(escapeHTML(cityLine))
            }
            if !client.oib.isEmpty {
                lines.append("OIB: \(escapeHTML(client.oib))")
            }
            return lines.joined(separator: "<br>")
        } else {
            return "<em style=\"color: #999;\">Klijent nije odabran</em>"
        }
    }
    
    private func buildNotesHTML(businessProfile: BusinessProfile, napomena: String, rokValjanosti: Int) -> String {
        var notesHTML = "<p>\(escapeHTML(businessProfile.vatExemptNote.isEmpty ? "oslobođen PDV-a" : businessProfile.vatExemptNote))</p>"
        if rokValjanosti > 0 {
            notesHTML += "<p>Rok valjanosti: \(rokValjanosti) dana</p>"
        }
        if !napomena.isEmpty {
            notesHTML += "<p>\(escapeHTML(napomena))</p>"
        }
        return notesHTML
    }
    
    // MARK: - Helpers
    
    /// Loads the appropriate logo image from the app bundle and returns a base64 data URI.
    /// Falls back to businessProfile.logoData if no bundled image matches.
    private func loadLogoBase64(for style: QuoteTemplateStyle, businessProfile: BusinessProfile) -> String? {
        let imageName: String
        switch style {
        case .lotusRC:
            imageName = "lotusrc"
        case .studioVarazdin:
            imageName = "varazdinstudio"
        case .lovements:
            // Lovements uses logoData from the profile if available
            if let data = businessProfile.logoData {
                return "data:image/png;base64,\(data.base64EncodedString())"
            }
            return nil
        }
        
        // Try loading from the app bundle Resources
        if let url = Bundle.main.url(forResource: imageName, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return "data:image/png;base64,\(data.base64EncodedString())"
        }
        
        // Fallback: try loading from businessProfile.logoData
        if let data = businessProfile.logoData {
            return "data:image/png;base64,\(data.base64EncodedString())"
        }
        
        print("[PDF] ⚠ Logo image '\(imageName).png' not found in bundle")
        return nil
    }
    
    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
    
    private func splitBrandName(_ name: String) -> (top: String?, main: String) {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let top = String(words.dropLast().joined(separator: " "))
            let main = String(words.last!)
            return (top, main)
        }
        return (nil, name)
    }
}

// MARK: - Navigation Delegate

/// Waits for WKWebView to finish loading HTML before triggering PDF export.
private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    let onFinished: () -> Void
    let onFailed: (Error) -> Void
    
    init(onFinished: @escaping () -> Void, onFailed: @escaping (Error) -> Void) {
        self.onFinished = onFinished
        self.onFailed = onFailed
        super.init()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give a brief moment for layout to settle after load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onFinished()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[PDF] WebView navigation failed: \(error.localizedDescription)")
        onFailed(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[PDF] WebView provisional navigation failed: \(error.localizedDescription)")
        onFailed(error)
    }
}
