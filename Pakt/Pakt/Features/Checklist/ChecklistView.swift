import SwiftData
import SwiftUI

struct ChecklistView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @State private var editing: ChecklistItem?
    @State private var showingNew = false
    @State private var newCategory: ChecklistCategory = .week

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                progressHeader
                    .padding(PaktSpace.s4)
                List {
                    ForEach(categoryGroups, id: \.category) { group in
                        Section(header: sectionHeader(group)) {
                            ForEach(group.items, id: \.id) { item in
                                Row(item: item, onToggle: { toggle(item) }, onTap: { editing = item })
                                    .listRowBackground(Color.paktCard)
                            }
                            .onDelete { offsets in delete(group: group, at: offsets) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(paktIcon: "plus") }
            }
        }
        .sheet(item: $editing) { item in
            EditChecklistItemSheet(item: item).presentationDetents([.medium])
        }
        .sheet(isPresented: $showingNew) {
            EditChecklistItemSheet(move: move).presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        let total = liveItems.count
        let done = liveItems.filter { $0.isDone }.count
        let pending = total - done
        return PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack {
                    Text("Checklist").font(.pakt(.heading))
                    Spacer()
                    Text("\(done) / \(total)")
                        .font(.pakt(.small).monospacedDigit())
                        .foregroundStyle(Color.paktMutedForeground)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.paktMuted).frame(height: 6)
                        Capsule().fill(Color.paktPrimary)
                            .frame(width: geo.size.width * fraction(done: done, total: total), height: 6)
                            .animation(.easeOut(duration: 0.25), value: done)
                    }
                }
                .frame(height: 6)
                Text(pending == 0
                     ? "All caught up. Nice."
                     : "\(pending) task\(pending == 1 ? "" : "s") still to go.")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
    }

    private func fraction(done: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(done) / CGFloat(total)
    }

    // MARK: - Sections

    private struct CategoryGroup {
        let category: ChecklistCategory
        let items: [ChecklistItem]
    }

    private let categoryOrder: [ChecklistCategory] = [.d30, .w2, .week, .day, .after]

    private var liveItems: [ChecklistItem] {
        move.checklist ?? []
    }

    private var categoryGroups: [CategoryGroup] {
        categoryOrder.compactMap { category in
            let items = liveItems
                .filter { $0.category == category }
                .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
            guard !items.isEmpty else { return nil }
            return CategoryGroup(category: category, items: items)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ group: CategoryGroup) -> some View {
        let done = group.items.filter { $0.isDone }.count
        let total = group.items.count
        HStack {
            Text(categoryLabel(group.category))
            Spacer()
            Text("\(done)/\(total)")
                .font(.pakt(.small).monospacedDigit())
                .foregroundStyle(Color.paktMutedForeground)
        }
    }

    private func categoryLabel(_ c: ChecklistCategory) -> String {
        switch c {
        case .d30:   return "30 days out"
        case .w2:    return "2 weeks out"
        case .week:  return "This week"
        case .day:   return "Moving day"
        case .after: return "After the move"
        }
    }

    // MARK: - Mutations

    private func toggle(_ item: ChecklistItem) {
        item.doneAt = item.isDone ? nil : Date()
        item.updatedAt = Date()
        try? context.save()
    }

    private func delete(group: CategoryGroup, at offsets: IndexSet) {
        for index in offsets {
            context.delete(group.items[index])
        }
        try? context.save()
    }
}

// MARK: - Row

private struct Row: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isDone ? Color.paktMoving : Color.paktMutedForeground)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.pakt(.body))
                .foregroundStyle(item.isDone ? Color.paktMutedForeground : Color.paktForeground)
                .strikethrough(item.isDone, color: Color.paktMutedForeground)
                .lineLimit(2)

            Spacer()

            Image(paktIcon: "chevron-right")
                .foregroundStyle(Color.paktMutedForeground)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Add/edit sheet

struct EditChecklistItemSheet: View {
    let move: Move?
    let item: ChecklistItem?

    init(move: Move) {
        self.move = move
        self.item = nil
        _text = State(initialValue: "")
        _category = State(initialValue: .week)
    }

    init(item: ChecklistItem) {
        self.move = item.move
        self.item = item
        _text = State(initialValue: item.text)
        _category = State(initialValue: item.category)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var category: ChecklistCategory

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to happen?", text: $text, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("When") {
                    Picker("Category", selection: $category) {
                        Text("30 days out").tag(ChecklistCategory.d30)
                        Text("2 weeks out").tag(ChecklistCategory.w2)
                        Text("This week").tag(ChecklistCategory.week)
                        Text("Moving day").tag(ChecklistCategory.day)
                        Text("After the move").tag(ChecklistCategory.after)
                    }
                }
                if let item, item.isDone {
                    Section {
                        Button("Mark undone") {
                            item.doneAt = nil
                            item.updatedAt = Date()
                            try? context.save()
                            dismiss()
                        }
                    }
                }
                if item != nil {
                    Section {
                        Button(role: .destructive) {
                            if let item { context.delete(item) }
                            try? context.save()
                            dismiss()
                        } label: {
                            Label("Delete task", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paktBackground)
            .navigationTitle(item == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: submit)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let item {
            item.text = trimmed
            item.category = category
            item.updatedAt = Date()
        } else if let move {
            let existing = (move.checklist ?? []).filter { $0.category == category }.count
            let new = ChecklistItem(move: move, text: trimmed, category: category,
                                    sortOrder: (existing + 1) * 10)
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}
