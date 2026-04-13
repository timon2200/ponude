import SwiftUI
import SwiftData

/// Dashboard showing a list of quotes with stats cards and search/filter.
struct DashboardView: View {
    let selectedProfile: BusinessProfile?
    let onNewQuote: () -> Void
    let onEditQuote: (Ponuda) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Query(sort: \Ponuda.datum, order: .reverse) private var allPonude: [Ponuda]
    
    @State private var searchText = ""
    @State private var statusFilter: PonudaStatus? = nil
    @State private var deleteTarget: Ponuda? = nil
    @State private var showDeleteAlert = false
    
    private var filteredPonude: [Ponuda] {
        var result = allPonude
        
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
            result = result.filter { ponuda in
                ponuda.client?.name.localizedCaseInsensitiveContains(searchText) == true ||
                "\(ponuda.broj)".contains(searchText) ||
                ponuda.mjesto.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    // MARK: - Stats (always based on profile-level data, not status filter)
    
    /// All ponude for the selected profile, independent of status/search filters.
    private var profilePonude: [Ponuda] {
        guard let profile = selectedProfile else { return allPonude }
        return allPonude.filter { $0.businessProfile?.id == profile.id }
    }
    
    private var totalCount: Int { profilePonude.count }
    private var draftCount: Int { profilePonude.filter { $0.status == .nacrt }.count }
    private var sentCount: Int { profilePonude.filter { $0.status == .poslano }.count }
    private var acceptedCount: Int { profilePonude.filter { $0.status == .prihvaceno }.count }
    private var totalValue: Decimal { profilePonude.reduce(Decimal.zero) { $0 + $1.ukupno } }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Stats cards
            statsCards
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            

            
            // Quote list
            if filteredPonude.isEmpty {
                emptyState
            } else {
                quoteList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .alert("Obriši ponudu?", isPresented: $showDeleteAlert) {
            Button("Obriši", role: .destructive) {
                if let target = deleteTarget {
                    modelContext.delete(target)
                    try? modelContext.save()
                }
            }
            Button("Odustani", role: .cancel) { }
        } message: {
            if let target = deleteTarget {
                Text("Jeste li sigurni da želite obrisati ponudu #\(target.broj)?")
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ponude")
                    .font(.system(size: 28, weight: .bold))
                if let profile = selectedProfile {
                    Text(profile.shortName)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Search field
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
                
                Button(action: onNewQuote) {
                    Label("Nova ponuda", systemImage: "plus")
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
            StatCard(title: "Ukupna vrijednost", value: "\(totalValue.hrFormatted) €", icon: "eurosign.circle.fill", color: brandAccent, isActive: false, onTap: nil)
            StatCard(title: "Ukupno ponuda", value: "\(totalCount)", icon: "doc.text.fill", color: .blue, isActive: statusFilter == nil) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = nil }
            }
            StatCard(title: "U izradi", value: "\(draftCount)", icon: "doc.badge.ellipsis", color: DesignTokens.statusDraft, isActive: statusFilter == .nacrt) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = statusFilter == .nacrt ? nil : .nacrt }
            }
            StatCard(title: "Poslano", value: "\(sentCount)", icon: "paperplane.fill", color: DesignTokens.statusSent, isActive: statusFilter == .poslano) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = statusFilter == .poslano ? nil : .poslano }
            }
            StatCard(title: "Prihvaćeno", value: "\(acceptedCount)", icon: "checkmark.seal.fill", color: DesignTokens.statusAccepted, isActive: statusFilter == .prihvaceno) {
                withAnimation(.easeInOut(duration: 0.2)) { statusFilter = statusFilter == .prihvaceno ? nil : .prihvaceno }
            }
        }
    }

    
    // MARK: - Quote List
    
    private var quoteList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Table header
                HStack {
                    Text("#").frame(width: 50, alignment: .leading)
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
                
                ForEach(filteredPonude) { ponuda in
                    QuoteRow(ponuda: ponuda,
                             onEdit: { onEditQuote(ponuda) },
                             onDelete: {
                        deleteTarget = ponuda
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
            Text("Nema ponuda")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Kreirajte novu ponudu klikom na gumb \"Nova ponuda\".")
                .font(.body)
                .foregroundStyle(.tertiary)
            Button(action: onNewQuote) {
                Label("Kreiraj prvu ponudu", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(brandAccent)
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    var onTap: (() -> Void)? = nil
    
    @State private var isHovered = false
    
    private var isClickable: Bool { onTap != nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isActive ? color : (isHovered && isClickable ? color.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.5)),
                    lineWidth: isActive ? 1.5 : 0.5
                )
        )
        .shadow(color: isActive ? color.opacity(0.15) : .black.opacity(0.06), radius: isActive ? 8 : 6, y: 2)
        .scaleEffect(isHovered && isClickable ? 1.02 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onHover { hovering in
            guard isClickable else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


struct QuoteRow: View {
    let ponuda: Ponuda
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var isStatusHovered = false
    
    var body: some View {
        HStack {
            Text("\(ponuda.broj)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ponuda.client?.name ?? "Bez klijenta")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if let mjesto = ponuda.mjesto.isEmpty ? nil : ponuda.mjesto {
                    Text(mjesto)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 200, alignment: .leading)
            
            Text(ponuda.datum.hrFormatted)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text("\(ponuda.formattedUkupno) €")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 120, alignment: .trailing)
            
            // Status badge — clickable dropdown to change status
            Menu {
                ForEach(PonudaStatus.allCases, id: \.self) { status in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            ponuda.status = status
                            ponuda.updatedAt = Date()
                            try? modelContext.save()
                        }
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                    .disabled(ponuda.status == status)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: ponuda.status.icon)
                        .font(.system(size: 10))
                    Text(ponuda.status.rawValue)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .opacity(isStatusHovered ? 1 : 0.4)
                }
                .foregroundStyle(Color(hex: ponuda.status.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: ponuda.status.color).opacity(isStatusHovered ? 0.18 : 0.1), in: Capsule())
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
