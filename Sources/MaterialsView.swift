import SwiftUI
import AppKit

struct MaterialsView: View {
    @EnvironmentObject var store: AppStore
    @Binding var project: Project
    @State private var filter: MaterialStatus?
    @State private var copied = false
    @State private var newName = ""
    @FocusState private var newFocused: Bool

    private var currency: String { store.library.currency }

    private var visibleIDs: [UUID] {
        project.materials.filter { filter == nil || $0.status == filter }.map(\.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            summary
            Divider()
            HStack(spacing: 0) {
                Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty").frame(width: 70, alignment: .trailing)
                Text("Unit").frame(width: 70, alignment: .leading).padding(.leading, 8)
                Text("Unit cost").frame(width: 90, alignment: .trailing)
                Text("Total").frame(width: 90, alignment: .trailing)
                Text("Status").frame(width: 110, alignment: .leading).padding(.leading, 12)
                Text("Supplier / link").frame(width: 160, alignment: .leading)
                Spacer().frame(width: 28)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 8)
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleIDs, id: \.self) { id in
                        if let b = binding(id) {
                            MaterialRow(material: b, currency: currency) {
                                project.materials.removeAll { $0.id == id }
                            }
                            Divider().padding(.leading, 20)
                        }
                    }
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(project.hobby.color)
                        TextField("Add material and press Return", text: $newName)
                            .textFieldStyle(.plain)
                            .focused($newFocused)
                            .onSubmit(add)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
        }
    }

    private var summary: some View {
        let have = project.materials.filter { $0.status == .have }.reduce(0) { $0 + $1.total }
        let ordered = project.materials.filter { $0.status == .ordered }.reduce(0) { $0 + $1.total }
        return HStack(spacing: 22) {
            metric("Budget", project.materialsTotal.money(currency), .primary)
            metric("Still to buy", project.materialsToBuy.money(currency), .red)
            metric("Ordered", ordered.money(currency), .orange)
            metric("In hand", have.money(currency), .green)
            Spacer()
            Picker("Show", selection: $filter) {
                Text("All").tag(MaterialStatus?.none)
                ForEach(MaterialStatus.allCases) { Text($0.title).tag(MaterialStatus?.some($0)) }
            }
            .pickerStyle(.segmented).fixedSize()
            Button { copyShoppingList() } label: {
                Label(copied ? "Copied" : "Copy Shopping List", systemImage: copied ? "checkmark" : "cart")
            }
            .disabled(!project.materials.contains { $0.status == .need })
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(color)
        }
    }

    private func binding(_ id: UUID) -> Binding<Material>? {
        guard project.materials.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { project.materials.first { $0.id == id } ?? Material(name: "") },
            set: { new in if let i = project.materials.firstIndex(where: { $0.id == id }) { project.materials[i] = new } })
    }

    private func add() {
        let t = newName.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        project.materials.append(Material(name: t, status: filter ?? .need))
        newName = ""
        newFocused = true
    }

    private func copyShoppingList() {
        let lines = project.materials.filter { $0.status == .need }.map { m -> String in
            var s = "☐ \(m.quantity.trimmed) \(m.unit) \(m.name)"
            if m.total > 0 { s += " — \(m.total.money(currency))" }
            if !m.supplier.isEmpty { s += " (\(m.supplier))" }
            return s
        }
        let text = "\(project.name) — shopping list\n" + lines.joined(separator: "\n")
            + "\nTotal: \(project.materialsToBuy.money(currency))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

struct MaterialRow: View {
    @Binding var material: Material
    let currency: String
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            TextField("Item", text: $material.name).textFieldStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", value: $material.quantity, format: .number).textFieldStyle(.plain)
                .multilineTextAlignment(.trailing).frame(width: 70)
            TextField("", text: $material.unit).textFieldStyle(.plain)
                .frame(width: 70).padding(.leading, 8).foregroundStyle(.secondary)
            TextField("", value: $material.unitCost, format: .currency(code: currency)).textFieldStyle(.plain)
                .multilineTextAlignment(.trailing).frame(width: 90)
            Text(material.total.money(currency)).monospacedDigit()
                .frame(width: 90, alignment: .trailing).foregroundStyle(.secondary)
            Menu {
                ForEach(MaterialStatus.allCases) { s in Button(s.title) { material.status = s } }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(material.status.color).frame(width: 8, height: 8)
                    Text(material.status.title)
                }
            }
            .menuStyle(.borderlessButton).fixedSize()
            .frame(width: 110, alignment: .leading).padding(.leading, 12)
            HStack(spacing: 4) {
                TextField("—", text: $material.supplier).textFieldStyle(.plain).foregroundStyle(.secondary)
                if let url = URL(string: material.supplier), url.scheme?.hasPrefix("http") == true {
                    Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                }
            }
            .frame(width: 160, alignment: .leading)
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .frame(width: 28).opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 9)
        .background(hovering ? Color.secondary.opacity(0.06) : .clear)
        .onHover { hovering = $0 }
    }
}
