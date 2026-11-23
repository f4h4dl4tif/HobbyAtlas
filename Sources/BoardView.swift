import SwiftUI

/// Custom kanban board: rename, add, reorder and delete columns; drag cards between them.
struct BoardView: View {
    @Binding var project: Project
    @State private var editingCard: CardRef?
    @State private var dropTarget: UUID?

    struct CardRef: Identifiable { let column: UUID; let card: UUID; var id: UUID { card } }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach($project.columns) { $column in
                    ColumnView(column: $column,
                               accent: project.hobby.color,
                               isLast: column.id == project.columns.last?.id,
                               isDropTarget: dropTarget == column.id,
                               onOpen: { editingCard = CardRef(column: column.id, card: $0) },
                               onDelete: { delete(column.id) },
                               onMove: { move(column.id, by: $0) })
                        .dropDestination(for: String.self) { items, _ in
                            guard let s = items.first, let id = UUID(uuidString: s) else { return false }
                            moveCard(id, to: column.id)
                            return true
                        } isTargeted: { dropTarget = $0 ? column.id : (dropTarget == column.id ? nil : dropTarget) }
                }
                Button {
                    project.columns.append(BoardColumn(title: "New Column"))
                } label: {
                    Label("Add Column", systemImage: "plus")
                        .frame(width: 200, height: 44)
                        .glassOr(RoundedRectangle(cornerRadius: 10), fill: .quaternary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .sheet(item: $editingCard) { ref in
            if let binding = cardBinding(ref) {
                CardEditor(card: binding, accent: project.hobby.color, onDelete: {
                    deleteCard(ref)
                })
            }
        }
    }

    private func cardBinding(_ ref: CardRef) -> Binding<BoardCard>? {
        guard let ci = project.columns.firstIndex(where: { $0.id == ref.column }),
              project.columns[ci].cards.contains(where: { $0.id == ref.card }) else { return nil }
        return Binding(
            get: { project.columns.first { $0.id == ref.column }?.cards.first { $0.id == ref.card } ?? BoardCard(title: "") },
            set: { new in
                guard let c = project.columns.firstIndex(where: { $0.id == ref.column }),
                      let k = project.columns[c].cards.firstIndex(where: { $0.id == ref.card }) else { return }
                project.columns[c].cards[k] = new
            })
    }

    private func deleteCard(_ ref: CardRef) {
        guard let c = project.columns.firstIndex(where: { $0.id == ref.column }) else { return }
        project.columns[c].cards.removeAll { $0.id == ref.card }
    }

    private func moveCard(_ id: UUID, to column: UUID) {
        guard let from = project.columns.firstIndex(where: { $0.cards.contains { $0.id == id } }),
              let to = project.columns.firstIndex(where: { $0.id == column }), from != to,
              let k = project.columns[from].cards.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) {
            let card = project.columns[from].cards.remove(at: k)
            project.columns[to].cards.append(card)
        }
    }

    private func delete(_ column: UUID) {
        project.columns.removeAll { $0.id == column }
    }

    private func move(_ column: UUID, by offset: Int) {
        guard let i = project.columns.firstIndex(where: { $0.id == column }) else { return }
        let j = i + offset
        guard project.columns.indices.contains(j) else { return }
        withAnimation(.snappy) { project.columns.swapAt(i, j) }
    }
}

struct ColumnView: View {
    @Binding var column: BoardColumn
    let accent: Color
    let isLast: Bool
    let isDropTarget: Bool
    let onOpen: (UUID) -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void
    @State private var newCard = ""
    @State private var confirmDelete = false
    @FocusState private var addFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if isLast { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                TextField("Column", text: $column.title).textFieldStyle(.plain).font(.headline)
                Text("\(column.cards.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(.quaternary, in: Capsule())
                Menu {
                    Button("Move Left") { onMove(-1) }
                    Button("Move Right") { onMove(1) }
                    Divider()
                    Button("Delete Column…", role: .destructive) {
                        if column.cards.isEmpty { onDelete() } else { confirmDelete = true }
                    }
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }

            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(column.cards) { card in
                        CardTile(card: card)
                            .onTapGesture { onOpen(card.id) }
                            .draggable(card.id.uuidString) {
                                CardTile(card: card).frame(width: 240).opacity(0.9)
                            }
                    }
                }
            }
            .scrollIndicators(.never)

            TextField("Add a card…", text: $newCard)
                .textFieldStyle(.plain)
                .focused($addFocused)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    let t = newCard.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    column.cards.append(BoardCard(title: t))
                    newCard = ""
                    addFocused = true
                }
        }
        .padding(12)
        .frame(width: 270)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassOr(RoundedRectangle(cornerRadius: 12), fill: isDropTarget ? accent.opacity(0.15) : Color.secondary.opacity(0.08),
                 tint: isDropTarget ? accent.opacity(0.25) : nil)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isDropTarget ? accent : .clear, lineWidth: 2))
        .confirmationDialog("Delete “\(column.title)” and its \(column.cards.count) cards?", isPresented: $confirmDelete) {
            Button("Delete Column", role: .destructive, action: onDelete)
        }
    }
}

struct CardTile: View {
    let card: BoardCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let c = card.label.color {
                Capsule().fill(c).frame(width: 34, height: 5)
            }
            Text(card.title).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            let done = card.checklist.filter(\.done).count
            if card.due != nil || !card.checklist.isEmpty || !card.notes.isEmpty {
                HStack(spacing: 10) {
                    if let due = card.due {
                        Label(due.formatted(.dateTime.month(.abbreviated).day()), systemImage: "clock")
                            .foregroundStyle(due < Date() ? .red : .secondary)
                    }
                    if !card.checklist.isEmpty {
                        Label("\(done)/\(card.checklist.count)", systemImage: "checklist")
                            .foregroundStyle(done == card.checklist.count ? .green : .secondary)
                    }
                    if !card.notes.isEmpty { Image(systemName: "text.alignleft").foregroundStyle(.secondary) }
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        .contentShape(Rectangle())
    }
}

struct CardEditor: View {
    @Binding var card: BoardCard
    let accent: Color
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Card title", text: $card.title).textFieldStyle(.plain).font(.title2.bold())

            HStack(spacing: 6) {
                Text("Label").foregroundStyle(.secondary)
                ForEach(CardLabel.allCases) { l in
                    Button { card.label = l } label: {
                        Circle()
                            .fill(l.color ?? Color.secondary.opacity(0.2))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(.primary, lineWidth: card.label == l ? 2 : 0))
                            .overlay { if l == .none { Image(systemName: "slash.circle").font(.caption2) } }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Toggle("Due", isOn: Binding(get: { card.due != nil }, set: { card.due = $0 ? (card.due ?? Date()) : nil }))
                if card.due != nil {
                    DatePicker("", selection: Binding(get: { card.due ?? Date() }, set: { card.due = $0 }), displayedComponents: .date)
                        .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes").font(.headline)
                TextEditor(text: $card.notes)
                    .frame(minHeight: 80)
                    .padding(4)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Checklist").font(.headline)
                    if !card.checklist.isEmpty {
                        ProgressView(value: Double(card.checklist.filter(\.done).count), total: Double(card.checklist.count))
                            .tint(accent)
                    }
                }
                ForEach($card.checklist) { $item in
                    HStack {
                        Toggle("", isOn: $item.done).labelsHidden().toggleStyle(.checkbox)
                        TextField("Item", text: $item.text).textFieldStyle(.plain).strikethrough(item.done)
                        Button { card.checklist.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                }
                TextField("Add item…", text: $newItem)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        let t = newItem.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        card.checklist.append(ChecklistItem(text: t)); newItem = ""
                    }
            }

            HStack {
                Button("Delete Card", role: .destructive) { onDelete(); dismiss() }
                Spacer()
                Text("Created \(card.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 480)
    }
}
