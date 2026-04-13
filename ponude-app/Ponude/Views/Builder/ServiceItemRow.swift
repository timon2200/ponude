import SwiftUI

/// Individual service line item editor with name, description, quantity, price, and calculated total.
struct ServiceItemRow: View {
    @Bindable var item: StavkaEditItem
    let index: Int
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @FocusState private var focusedField: Field?
    @Environment(\.brandAccent) private var brandAccent
    
    enum Field {
        case naziv, opis, kolicina, cijena
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main row: index, name, and delete
            HStack(alignment: .top, spacing: 8) {
                // Index number
                Text("(\(index))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24)
                    .padding(.top, 3)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Service name
                    TextField("Naziv usluge...", text: $item.naziv)
                        .font(.system(size: 13, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .naziv)
                    
                    // Description toggle + field
                    if item.isDescriptionExpanded || !item.opis.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Popis isporuka:")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                            
                            TextField("Opišite što usluga uključuje...", text: $item.opis, axis: .vertical)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textFieldStyle(.plain)
                                .lineLimit(3...30)
                                .focused($focusedField, equals: .opis)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.primary.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                                )
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                item.isDescriptionExpanded = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8))
                                Text("Dodaj opis")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.3)
            }
            
            // Price row: quantity × price = total
            HStack(spacing: 8) {
                Spacer().frame(width: 24)
                
                // Quantity
                HStack(spacing: 4) {
                    Text("Kol:")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("1", text: $item.kolicina)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                        .focused($focusedField, equals: .kolicina)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("×")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                
                // Price
                HStack(spacing: 4) {
                    TextField("0,00", text: $item.cijena)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .focused($focusedField, equals: .cijena)
                        .multilineTextAlignment(.trailing)
                    Text("€")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Text("=")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                
                // Total
                Text("\(item.formattedVrijednost) €")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(brandAccent)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
