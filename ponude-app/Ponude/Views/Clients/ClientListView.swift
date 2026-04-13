import SwiftUI
import SwiftData

/// Full client management view with list, search, edit, and delete.
struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Query(sort: \Client.name) private var clients: [Client]
    
    @State private var searchText = ""
    @State private var selectedClient: Client?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var deleteTarget: Client?
    @State private var editData = NewClientData()
    
    private var filteredClients: [Client] {
        if searchText.isEmpty { return clients }
        return clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.oib.contains(searchText) ||
            $0.city.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Klijenti")
                        .font(.system(size: 28, weight: .bold))
                    Text("\(clients.count) spremljenih klijenata")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
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
                    
                    Button {
                        editData = NewClientData()
                        selectedClient = nil
                        showEditSheet = true
                    } label: {
                        Label("Novi klijent", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(brandAccent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Divider()
            
            if filteredClients.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("Nema klijenata")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Klijenti se automatski spremaju pri kreiranju ponude, ili ih dodajte ručno.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Table header
                        HStack {
                            Text("Naziv").frame(minWidth: 200, alignment: .leading)
                            Text("OIB").frame(width: 120, alignment: .leading)
                            Text("Grad").frame(width: 120, alignment: .leading)
                            Text("Ponude").frame(width: 60, alignment: .trailing)
                            Spacer().frame(width: 80)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        Divider()
                        
                        ForEach(filteredClients) { client in
                            ClientManagementRow(
                                client: client,
                                onEdit: {
                                    selectedClient = client
                                    editData = NewClientData(
                                        name: client.name,
                                        oib: client.oib,
                                        mbs: client.mbs,
                                        address: client.address,
                                        city: client.city,
                                        zipCode: client.zipCode,
                                        contactPerson: client.contactPerson,
                                        email: client.email,
                                        phone: client.phone
                                    )
                                    showEditSheet = true
                                },
                                onDelete: {
                                    deleteTarget = client
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Obriši klijenta?", isPresented: $showDeleteAlert) {
            Button("Obriši", role: .destructive) {
                if let target = deleteTarget {
                    modelContext.delete(target)
                    try? modelContext.save()
                }
            }
            Button("Odustani", role: .cancel) { }
        } message: {
            if let target = deleteTarget {
                Text("Jeste li sigurni da želite obrisati klijenta \"\(target.name)\"?")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ManualClientForm(clientData: $editData) { newClient in
                if let existing = selectedClient {
                    // Update existing
                    existing.name = editData.name
                    existing.oib = editData.oib
                    existing.address = editData.address
                    existing.city = editData.city
                    existing.zipCode = editData.zipCode
                    existing.contactPerson = editData.contactPerson
                    existing.email = editData.email
                    existing.phone = editData.phone
                    try? modelContext.save()
                } else {
                    // Save new
                    modelContext.insert(newClient)
                    try? modelContext.save()
                }
            }
        }
    }
}

struct ClientManagementRow: View {
    let client: Client
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @Environment(\.brandAccent) private var brandAccent
    
    var body: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(brandAccent.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Text(String(client.name.prefix(1)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(brandAccent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if !client.contactPerson.isEmpty {
                        Text(client.contactPerson)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 200, alignment: .leading)
            
            Text(client.oib.isEmpty ? "-" : client.oib)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(client.city.isEmpty ? "-" : client.city)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text("\(client.ponude.count)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .opacity(isHovered ? 1 : 0)
            .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        
        Divider().padding(.leading, 58)
    }
}
