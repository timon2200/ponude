import SwiftUI

/// A pixel-perfect A4 paper simulation that renders the invoice in real-time,
/// with a distinct visual design per company template style.
/// Mirrors QuotePreviewView structure but uses "RAČUN" title and invoice-specific metadata.
struct InvoicePreviewView: View {
    let businessProfile: BusinessProfile
    let client: Client?
    let racunBroj: Int
    let datum: Date
    let mjesto: String
    let stavke: [StavkaEditItem]
    let ukupno: Decimal
    let napomena: String
    let rokPlacanja: Int
    let sourcePonudaBroj: Int
    
    // A4 at 72dpi: 595 × 842 points
    private let pageWidth: CGFloat = 595
    private let pageHeight: CGFloat = 842
    private let marginH: CGFloat = 48
    
    private var style: QuoteTemplateStyle { .style(for: businessProfile) }
    private var visibleStavke: [StavkaEditItem] { stavke.filter { !$0.naziv.isEmpty } }
    
    private var formattedBroj: String {
        let year = Calendar.current.component(.year, from: datum)
        return "\(racunBroj)/\(year)"
    }
    
    private var rokPlacanjaDate: Date {
        Calendar.current.date(byAdding: .day, value: rokPlacanja, to: datum) ?? datum
    }
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - 24
            let scale = min(availableWidth / pageWidth, 1.0)
            
            ScrollView(.vertical, showsIndicators: true) {
                pageContent
                    .frame(width: pageWidth)
                    .frame(minHeight: pageHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(
                        width: pageWidth * scale,
                        height: pageHeight * scale,
                        alignment: .topLeading
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.top)
        }
    }
    
    // MARK: - Page Content (dispatches to style)
    
    @ViewBuilder
    private var pageContent: some View {
        switch style {
        case .lotusRC:
            lotusPage
        case .studioVarazdin:
            studioPage
        case .lovements:
            lovementsPage
        case .domyMedia:
            domyPage
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - LOTUS RC — Cinematic Bold
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private var lotusPage: some View {
        let navy = Color(hex: "#0B1929")
        let accentBlue = Color(hex: "#3B82F6")
        let textDark = Color(hex: "#1E293B")
        let textLight = Color(hex: "#64748B")
        let ruleLine = Color(hex: "#CBD5E1")
        
        return VStack(spacing: 0) {
            // ── HEADER ──
            ZStack {
                navy
                VStack(spacing: 4) {
                    Text(businessProfile.shortName.uppercased())
                        .font(.system(size: 28, weight: .black))
                        .kerning(6)
                        .foregroundStyle(.white)
                    Rectangle()
                        .fill(accentBlue)
                        .frame(width: 60, height: 2)
                }
                .padding(.vertical, 16)
            }
            .frame(height: 72)
            
            // ── TITLE BAND ──
            VStack(spacing: 0) {
                Text("RAČUN")
                    .font(.system(size: 28, weight: .bold))
                    .kerning(8)
                    .foregroundStyle(textDark)
                    .padding(.vertical, 12)
                
                Rectangle()
                    .fill(accentBlue)
                    .frame(height: 2)
                    .padding(.horizontal, marginH)
            }
            
            // ── CONTENT ──
            VStack(spacing: 0) {
                partiesSection(text: textDark, light: textLight)
                    .padding(.top, 20)
                
                invoiceMetadataSection(text: textDark, light: textLight)
                    .padding(.top, 14)
                
                HStack(spacing: 0) {
                    tableHeaderRow(text: textDark)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, -marginH)
                .padding(.horizontal, marginH)
                .background(Color(hex: "#F1F5F9"))
                .padding(.top, 12)
                
                tableItemRows(text: textDark, light: textLight, rule: ruleLine)
                totalsSection(text: textDark, rule: ruleLine, accent: accentBlue)
                invoiceNotesSection(light: textLight)
                    .padding(.top, 14)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, marginH)
            
            Spacer(minLength: 0)
            
            // ── FOOTER ──
            ZStack {
                navy
                HStack {
                    if !businessProfile.website.isEmpty {
                        Text(businessProfile.website)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text(businessProfile.taxStatus.rawValue)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, marginH)
            }
            .frame(height: 30)
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - STUDIO VARAŽDIN — Dark Gold Premium
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private var studioPage: some View {
        let black = Color(hex: "#0D0D0D")
        let gold = Color(hex: "#C5A55A")
        let goldLight = Color(hex: "#D4C08A")
        let textDark = Color(hex: "#333333")
        let textLight = Color(hex: "#777777")
        let ruleLine = Color(hex: "#C5A55A").opacity(0.3)
        
        return VStack(spacing: 0) {
            // ── HEADER ──
            ZStack {
                black
                RoundedRectangle(cornerRadius: 1)
                    .stroke(gold.opacity(0.4), lineWidth: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                
                ZStack {
                    cornerBracket(gold: gold)
                        .position(x: 24, y: 12)
                    cornerBracket(gold: gold)
                        .rotationEffect(.degrees(90))
                        .position(x: pageWidth - 24, y: 12)
                    cornerBracket(gold: gold)
                        .rotationEffect(.degrees(-90))
                        .position(x: 24, y: 58)
                    cornerBracket(gold: gold)
                        .rotationEffect(.degrees(180))
                        .position(x: pageWidth - 24, y: 58)
                }
                
                VStack(spacing: 2) {
                    let parts = splitBrandName(businessProfile.shortName)
                    if let top = parts.top {
                        Text(top.uppercased())
                            .font(.system(size: 9, weight: .light))
                            .kerning(6)
                            .foregroundStyle(goldLight.opacity(0.7))
                    }
                    Text(parts.main.uppercased())
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .kerning(4)
                        .foregroundStyle(gold)
                }
                .padding(.vertical, 16)
            }
            .frame(height: 70)
            
            // ── TITLE ──
            VStack(spacing: 0) {
                Rectangle()
                    .fill(gold)
                    .frame(height: 1.5)
                    .padding(.horizontal, marginH)
                    .padding(.top, 8)
                
                Text("RAČUN")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .kerning(6)
                    .foregroundStyle(gold)
                    .padding(.vertical, 10)
                
                Rectangle()
                    .fill(gold)
                    .frame(height: 1.5)
                    .padding(.horizontal, marginH)
            }
            
            // ── CONTENT ──
            VStack(spacing: 0) {
                partiesSection(text: textDark, light: textLight)
                    .padding(.top, 20)
                
                invoiceMetadataSection(text: textDark, light: textLight)
                    .padding(.top, 14)
                
                Rectangle()
                    .fill(ruleLine)
                    .frame(height: 0.5)
                    .padding(.top, 14)
                
                tableHeaderRow(text: textDark)
                    .padding(.vertical, 8)
                
                Rectangle()
                    .fill(ruleLine)
                    .frame(height: 0.5)
                
                tableItemRows(text: textDark, light: textLight, rule: ruleLine)
                totalsSection(text: textDark, rule: ruleLine, accent: gold)
                invoiceNotesSection(light: textLight)
                    .padding(.top, 14)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, marginH)
            
            Spacer(minLength: 0)
            
            // ── FOOTER ──
            ZStack {
                black
                HStack {
                    if !businessProfile.website.isEmpty {
                        Text(businessProfile.website)
                            .font(.system(size: 8))
                            .foregroundStyle(gold.opacity(0.6))
                    }
                    Spacer()
                    Text(businessProfile.taxStatus.rawValue)
                        .font(.system(size: 8))
                        .foregroundStyle(gold.opacity(0.6))
                }
                .padding(.horizontal, marginH)
            }
            .frame(height: 30)
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - LOVEMENTS — Wedding Elegance
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private var lovementsPage: some View {
        let blush = Color(hex: "#FFF5F5")
        let roseGold = Color(hex: "#D4A0A0")
        let roseDark = Color(hex: "#B07878")
        let textWarm = Color(hex: "#5D4647")
        let textLight = Color(hex: "#B08E8E")
        let ruleLine = Color(hex: "#F0D4D4")
        
        return VStack(spacing: 0) {
            // ── HEADER ──
            ZStack {
                blush
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Rectangle().fill(roseGold.opacity(0.4)).frame(width: 40, height: 0.5)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(roseGold.opacity(0.5))
                        Rectangle().fill(roseGold.opacity(0.4)).frame(width: 40, height: 0.5)
                    }
                    
                    Text(businessProfile.shortName)
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .kerning(4)
                        .foregroundStyle(roseDark)
                    
                    HStack(spacing: 8) {
                        Rectangle().fill(roseGold.opacity(0.4)).frame(width: 40, height: 0.5)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(roseGold.opacity(0.5))
                        Rectangle().fill(roseGold.opacity(0.4)).frame(width: 40, height: 0.5)
                    }
                }
                .padding(.vertical, 14)
            }
            .frame(height: 75)
            
            // ── TITLE ──
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Rectangle().fill(roseGold.opacity(0.3)).frame(height: 0.5)
                    Circle().fill(roseGold.opacity(0.4)).frame(width: 4, height: 4)
                    Rectangle().fill(roseGold.opacity(0.3)).frame(height: 0.5)
                }
                .padding(.horizontal, marginH + 20)
                .padding(.top, 6)
                
                Text("RAČUN")
                    .font(.system(size: 28, weight: .thin, design: .serif))
                    .kerning(8)
                    .foregroundStyle(roseDark)
                    .padding(.vertical, 10)
                
                HStack(spacing: 12) {
                    Rectangle().fill(roseGold.opacity(0.3)).frame(height: 0.5)
                    Circle().fill(roseGold.opacity(0.4)).frame(width: 4, height: 4)
                    Rectangle().fill(roseGold.opacity(0.3)).frame(height: 0.5)
                }
                .padding(.horizontal, marginH + 20)
            }
            
            // ── CONTENT ──
            VStack(spacing: 0) {
                partiesSection(text: textWarm, light: textLight)
                    .padding(.top, 18)
                
                invoiceMetadataSection(text: textWarm, light: textLight)
                    .padding(.top, 12)
                
                Rectangle()
                    .fill(ruleLine)
                    .frame(height: 0.5)
                    .padding(.top, 12)
                
                tableHeaderRow(text: textWarm)
                    .padding(.vertical, 7)
                    .background(blush.opacity(0.5))
                
                Rectangle()
                    .fill(ruleLine)
                    .frame(height: 0.5)
                
                tableItemRows(text: textWarm, light: textLight, rule: ruleLine)
                totalsSection(text: textWarm, rule: ruleLine, accent: roseDark)
                invoiceNotesSection(light: textLight)
                    .padding(.top, 12)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, marginH)
            
            Spacer(minLength: 0)
            
            // ── FOOTER ──
            ZStack {
                blush
                VStack(spacing: 0) {
                    Rectangle().fill(roseGold.opacity(0.3)).frame(height: 0.5)
                    Spacer()
                }
                HStack {
                    if !businessProfile.website.isEmpty {
                        Text(businessProfile.website)
                            .font(.system(size: 8, design: .serif))
                            .foregroundStyle(textLight)
                    }
                    Spacer()
                    Text(businessProfile.taxStatus.rawValue)
                        .font(.system(size: 8, design: .serif))
                        .foregroundStyle(textLight)
                }
                .padding(.horizontal, marginH)
            }
            .frame(height: 30)
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - DOMY MEDIA — Cinematic Broadcast
    // Deep charcoal header, electric violet gradient accent, clean modern sans-serif
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private var domyPage: some View {
        let charcoal = Color(hex: "#1A1A2E")
        let violet = Color(hex: "#7B2FF7")
        let violetLight = Color(hex: "#9F5FFF")
        let textDark = Color(hex: "#1E1E2E")
        let textLight = Color(hex: "#6B7280")
        let ruleLine = Color(hex: "#E5E7EB")
        
        return VStack(spacing: 0) {
            // ── HEADER ──
            ZStack {
                charcoal
                
                VStack(spacing: 4) {
                    Text("MEDIA")
                        .font(.system(size: 8, weight: .regular))
                        .kerning(8)
                        .foregroundStyle(violet.opacity(0.5))
                    
                    Text(businessProfile.shortName.uppercased())
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(5)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 16)
                
                // Violet gradient accent bar
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [violet, violetLight, violet],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 3)
                    .padding(.horizontal, marginH)
                }
            }
            .frame(height: 72)
            
            // ── TITLE ──
            VStack(spacing: 0) {
                Text("RAČUN")
                    .font(.system(size: 26, weight: .bold))
                    .kerning(10)
                    .foregroundStyle(textDark)
                    .padding(.vertical, 12)
                
                Rectangle()
                    .fill(violet)
                    .frame(height: 2)
                    .padding(.horizontal, marginH)
            }
            
            // ── CONTENT ──
            VStack(spacing: 0) {
                partiesSection(text: textDark, light: textLight)
                    .padding(.top, 20)
                
                invoiceMetadataSection(text: textDark, light: textLight)
                    .padding(.top, 14)
                
                HStack(spacing: 0) {
                    tableHeaderRow(text: textDark)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, -marginH)
                .padding(.horizontal, marginH)
                .background(Color(hex: "#F3F0FF"))
                .padding(.top, 12)
                
                tableItemRows(text: textDark, light: textLight, rule: ruleLine)
                totalsSection(text: textDark, rule: ruleLine, accent: violet)
                invoiceNotesSection(light: textLight)
                    .padding(.top, 14)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, marginH)
            
            Spacer(minLength: 0)
            
            // ── FOOTER ──
            ZStack {
                charcoal
                HStack {
                    if !businessProfile.website.isEmpty {
                        Text(businessProfile.website)
                            .font(.system(size: 8))
                            .foregroundStyle(violet.opacity(0.7))
                    }
                    Spacer()
                    Text(businessProfile.taxStatus.rawValue)
                        .font(.system(size: 8))
                        .foregroundStyle(violet.opacity(0.7))
                }
                .padding(.horizontal, marginH)
            }
            .frame(height: 30)
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Shared Components
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func partiesSection(text: Color, light: Color) -> some View {
        HStack(alignment: .top, spacing: 30) {
            // Issuer (left)
            VStack(alignment: .leading, spacing: 3) {
                Text(businessProfile.name)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(text)
                
                Text("Vl. \(businessProfile.ownerName)")
                    .font(.system(size: 8))
                    .foregroundStyle(light)
                
                Text(businessProfile.fullAddress)
                    .font(.system(size: 8))
                    .foregroundStyle(light)
                
                if !businessProfile.oib.isEmpty {
                    Text("OIB: \(businessProfile.oib)")
                        .font(.system(size: 8))
                        .foregroundStyle(light)
                }
                
                if !businessProfile.iban.isEmpty {
                    Text("IBAN: \(businessProfile.iban)")
                        .font(.system(size: 8))
                        .foregroundStyle(light)
                }
                
                if !businessProfile.phone.isEmpty {
                    Text("Tel.: \(businessProfile.phone)")
                        .font(.system(size: 8))
                        .foregroundStyle(light)
                }
                
                if !businessProfile.email.isEmpty {
                    Text("E-mail: \(businessProfile.email)")
                        .font(.system(size: 8))
                        .foregroundStyle(light)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Client (right)
            VStack(alignment: .leading, spacing: 3) {
                if let client = client {
                    Text(client.name.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(text)
                    
                    if !client.address.isEmpty {
                        Text(client.address)
                            .font(.system(size: 8))
                            .foregroundStyle(light)
                    }
                    
                    let cityLine = [client.zipCode, client.city].filter { !$0.isEmpty }.joined(separator: " ")
                    if !cityLine.isEmpty {
                        Text(cityLine)
                            .font(.system(size: 8))
                            .foregroundStyle(light)
                    }
                    
                    if !client.oib.isEmpty {
                        Text("OIB: \(client.oib)")
                            .font(.system(size: 8))
                            .foregroundStyle(light)
                    }
                } else {
                    Text("ODABERI KLIJENTA")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(light.opacity(0.5))
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// Invoice-specific metadata section with payment deadline and ponuda reference
    private func invoiceMetadataSection(text: Color, light: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            metadataLine("Broj računa:", formattedBroj, text: text, light: light)
            if !mjesto.isEmpty {
                metadataLine("Mjesto:", mjesto, text: text, light: light)
            }
            metadataLine("Datum izdavanja:", datum.hrFormatted, text: text, light: light)
            metadataLine("Rok plaćanja:", rokPlacanjaDate.hrFormatted, text: text, light: light)
            
            if sourcePonudaBroj > 0 {
                metadataLine("Temeljem ponude br.:", "\(sourcePonudaBroj)", text: text, light: light)
            }
        }
    }
    
    private func metadataLine(_ label: String, _ value: String, text: Color, light: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(light)
            Text(value)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(text)
        }
    }
    
    private func tableHeaderRow(text: Color) -> some View {
        HStack(spacing: 0) {
            Text("Vrsta robe odnosno usluga")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Količina")
                .frame(width: 65, alignment: .trailing)
            Text("Cijena")
                .frame(width: 80, alignment: .trailing)
            Text("Vrijednost EUR")
                .frame(width: 95, alignment: .trailing)
        }
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(text)
    }
    
    private func tableItemRows(text: Color, light: Color, rule: Color) -> some View {
        VStack(spacing: 0) {
            if visibleStavke.isEmpty {
                HStack {
                    Text("Dodajte stavke u editoru...")
                        .font(.system(size: 8))
                        .foregroundStyle(light.opacity(0.5))
                        .italic()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(Array(visibleStavke.enumerated()), id: \.element.id) { index, stavka in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("(\(index + 1)) \(stavka.naziv)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(text)
                                
                                if !stavka.opis.isEmpty {
                                    Text("Popis isporuka:")
                                        .font(.system(size: 6.5, weight: .semibold))
                                        .foregroundStyle(light.opacity(0.7))
                                        .padding(.top, 2)
                                    Text(stavka.opis)
                                        .font(.system(size: 7.5))
                                        .foregroundStyle(light)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(1.5)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(stavka.kolicina.isEmpty ? "1" : stavka.kolicina)
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(text)
                                .frame(width: 65, alignment: .trailing)
                            
                            Text(stavka.cijenaDecimal.hrFormatted)
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(text)
                                .frame(width: 80, alignment: .trailing)
                            
                            Text(stavka.formattedVrijednost)
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(text)
                                .frame(width: 95, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        
                        Rectangle()
                            .fill(rule.opacity(0.5))
                            .frame(height: 0.3)
                    }
                }
            }
        }
    }
    
    private func totalsSection(text: Color, rule: Color, accent: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(rule)
                .frame(height: 0.5)
            
            HStack {
                Spacer()
                Text("Ukupno:")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(text)
                Text("\(ukupno.hrFormatted) EUR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(text)
                    .frame(width: 95, alignment: .trailing)
            }
            .padding(.vertical, 8)
            
            Rectangle()
                .fill(rule)
                .frame(height: 0.5)
            
            HStack {
                Spacer()
                Text("Za plaćanje EUR:")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(text)
                Text(ukupno.hrFormatted)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accent)
                    .frame(width: 95, alignment: .trailing)
            }
            .padding(.vertical, 8)
            
            Rectangle()
                .fill(rule)
                .frame(height: 0.5)
        }
    }
    
    /// Invoice-specific notes section with IBAN payment info
    private func invoiceNotesSection(light: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(businessProfile.vatExemptNote.isEmpty ? "oslobođen PDV-a" : businessProfile.vatExemptNote)
                .font(.system(size: 8))
                .foregroundStyle(light)
            
            if !businessProfile.iban.isEmpty {
                Text("Plaćanje na IBAN: \(businessProfile.iban)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(light)
            }
            
            if sourcePonudaBroj > 0 {
                Text("Temeljem ponude br. \(sourcePonudaBroj)")
                    .font(.system(size: 8))
                    .foregroundStyle(light)
            }
            
            if !napomena.isEmpty {
                Text(napomena)
                    .font(.system(size: 8))
                    .foregroundStyle(light)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func splitBrandName(_ name: String) -> (top: String?, main: String) {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let top = String(words.dropLast().joined(separator: " "))
            let main = String(words.last!)
            return (top, main)
        }
        return (nil, name)
    }
    
    private func cornerBracket(gold: Color) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 10))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 10, y: 0))
            }
            .stroke(gold.opacity(0.5), lineWidth: 1)
        }
        .frame(width: 10, height: 10)
    }
}

// MARK: - Debounced Invoice Preview Wrapper

/// Wraps `InvoicePreviewView` with a 300ms debounce so the heavy A4 preview
/// doesn't re-render on every keystroke — only after the user pauses typing.
struct DebouncedInvoicePreviewWrapper: View {
    let businessProfile: BusinessProfile
    let state: InvoiceBuilderState
    let invoiceNumber: Int
    
    @State private var snapshotClient: Client?
    @State private var snapshotBroj: Int = 0
    @State private var snapshotDatum: Date = Date()
    @State private var snapshotMjesto: String = ""
    @State private var snapshotStavke: [StavkaEditItem] = []
    @State private var snapshotUkupno: Decimal = 0
    @State private var snapshotNapomena: String = ""
    @State private var snapshotRok: Int = 15
    @State private var snapshotSourcePonuda: Int = 0
    @State private var debounceTask: Task<Void, Never>?
    @State private var hasInitialized = false
    
    var body: some View {
        InvoicePreviewView(
            businessProfile: businessProfile,
            client: snapshotClient,
            racunBroj: snapshotBroj,
            datum: snapshotDatum,
            mjesto: snapshotMjesto,
            stavke: snapshotStavke,
            ukupno: snapshotUkupno,
            napomena: snapshotNapomena,
            rokPlacanja: snapshotRok,
            sourcePonudaBroj: snapshotSourcePonuda
        )
        .onAppear {
            if !hasInitialized {
                takeSnapshot()
                hasInitialized = true
            }
        }
        .onChange(of: state.changeToken) {
            scheduleSnapshot()
        }
    }
    
    private func scheduleSnapshot() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            takeSnapshot()
        }
    }
    
    private func takeSnapshot() {
        snapshotClient = state.selectedClient
        snapshotBroj = invoiceNumber
        snapshotDatum = state.datum
        snapshotMjesto = state.mjesto
        snapshotStavke = state.stavke
        snapshotUkupno = state.ukupno
        snapshotNapomena = state.napomena
        snapshotRok = state.rokPlacanjaDays
        snapshotSourcePonuda = state.sourcePonudaBroj
    }
}
