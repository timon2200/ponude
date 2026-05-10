import SwiftUI
import SwiftData

/// Dashboard showing a list of invoices with stats cards and search/filter.
struct InvoiceDashboardView: View {
    let selectedProfile: BusinessProfile?
    let onNewInvoice: () -> Void
    let onEditInvoice: (Racun) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Query(sort: \Racun.datum, order: .reverse) private var allRacuni: [Racun]
    
    @State private var searchText = ""
    @State private var statusFilter: RacunStatus? = nil
    @State private var deleteTarget: Racun? = nil
    @State private var showDeleteAlert = false
    
    private var filteredRacuni: [Racun] {
        var result = allRacuni
        
        // Filter by selected business profile
        if let profile = selectedProfile {
            result = result.filter { $0.businessProfile?.id == profile.id }
        }
        
        // Filter by status
        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { racun in
                racun.client?.name.localizedCaseInsensitiveContains(searchText) == true ||
                "\(racun.broj)".contains(searchText) ||
                racun.mjesto.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    // MARK: - Stats
    
    private var profileRacuni: [Racun] {
        guard let profile = selectedProfile else { return allRacuni }
        return allRacuni.filter { $0.businessProfile?.id == profile.id }
    }
    
    private var totalCount: Int { profileRacuni.count }
    private var draftCount: Int { profileRacuni.filter { $0.status == .nacrt }.count }
    private var issuedCount: Int { profileRacuni.filter { $0.status == .izdano }.count }
    private var paidCount: Int { profileRacuni.filter { $0.status == .placeno }.count }
    private var totalValue: Decimal { profileRacuni.reduce(Decimal.zero) { $0 + $1.ukupno } }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            statsCards
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            if filteredRacuni.isEmpty {
                emptyState
            } else {
                invoiceList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .alert("Obriši račun?", isPresented: $showDeleteAlert) {
            Button("Obriši", role: .destructive) {
                if let target = deleteTarget {
                    modelContext.delete(target)
                    try? modelContext.save()
                }
            }
            Button("Odustani", role: .cancel) { }
        } message: {
            if let target = deleteTarget {
                Text("Jeste li sigurni da želite obrisati račun #\(target.broj)?")
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Računi")
                    .font(.system(size: 28, weight: .bold))
                if let profile = selectedProfile {
                    Text(profile.shortName)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Pretraži...", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                
                Button(action: onNewInvoice) {
                    Label("Novi račun", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(brandAccent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Stats Cards
    
    private var statsCards: some View {
        HStack(spacing: 14) {
            StatCard(title: "Ukupno fakturirano", value: "\(totalValue.hrFormatted) €", icon: "eurosign.circle.fill", color: brandAccent, isActive: false, onTap: nil)
            StatCard(title: "Ukupno računa", value: "\(totalCount)", icon: "doc.text.fill", color: .blue, isActive: statusFilter == nil) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = nil }
            }
            StatCard(title: "U izradi", value: "\(draftCount)", icon: "doc.badge.ellipsis", color: DesignTokens.statusDraft, isActive: statusFilter == .nacrt) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = statusFilter == .nacrt ? nil : .nacrt }
            }
            StatCard(title: "Izdano", value: "\(issuedCount)", icon: "paperplane.fill", color: DesignTokens.statusIssued, isActive: statusFilter == .izdano) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = statusFilter == .izdano ? nil : .izdano }
            }
            StatCard(title: "Plaćeno", value: "\(paidCount)", icon: "checkmark.seal.fill", color: DesignTokens.statusPaid, isActive: statusFilter == .placeno) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = statusFilter == .placeno ? nil : .placeno }
            }
        }
    }
    
    // MARK: - Invoice List
    
    private var invoiceList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Table header
                HStack {
                    Text("#").frame(width: 70, alignment: .leading)
                    Text("Klijent").frame(minWidth: 200, alignment: .leading)
                    Text("Datum").frame(width: 100, alignment: .leading)
                    Text("Iznos").frame(width: 120, alignment: .trailing)
                    Text("Status").frame(width: 100, alignment: .center)
                    Spacer().frame(width: 40)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                
                ForEach(filteredRacuni) { racun in
                    InvoiceRow(racun: racun,
                               onEdit: { onEditInvoice(racun) },
                               onDelete: {
                        deleteTarget = racun
                        showDeleteAlert = true
                    })
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Nema računa")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Kreirajte novi račun klikom na gumb \"Novi račun\" ili iz prihvaćene ponude.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button(action: onNewInvoice) {
                Label("Kreiraj prvi račun", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(brandAccent)
            Spacer()
        }
    }
}

// MARK: - Invoice Row

struct InvoiceRow: View {
    let racun: Racun
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var isStatusHovered = false
    
    var body: some View {
        HStack {
            Text(racun.formattedBroj)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(racun.client?.name ?? "Bez klijenta")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let mjesto = racun.mjesto.isEmpty ? nil : racun.mjesto {
                        Text(mjesto)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if racun.hasSourcePonuda {
                        HStack(spacing: 2) {
                            Image(systemName: "link")
                                .font(.system(size: 8))
                            Text("P#\(racun.sourcePonudaBroj)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(DesignTokens.statusSent.opacity(0.7))
                    }
                }
            }
            .frame(minWidth: 200, alignment: .leading)
            
            Text(racun.datum.hrFormatted)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text("\(racun.formattedUkupno) €")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 120, alignment: .trailing)
            
            // Status badge — clickable dropdown
            Menu {
                ForEach(RacunStatus.allCases, id: \.self) { status in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            racun.status = status
                            racun.updatedAt = Date()
                            try? modelContext.save()
                        }
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                    .disabled(racun.status == status)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: racun.status.icon)
                        .font(.system(size: 10))
                    Text(racun.status.rawValue)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .opacity(isStatusHovered ? 1 : 0.4)
                }
                .foregroundStyle(Color(hex: racun.status.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: racun.status.color).opacity(isStatusHovered ? 0.18 : 0.1), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 100, alignment: .center)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isStatusHovered = hovering
                }
            }
            
            // Actions
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        
        Divider().padding(.leading, 16)
    }
}
