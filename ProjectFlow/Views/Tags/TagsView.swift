import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var newTagName = ""
    @State private var showingAddTag = false

    private var tagStats: [(tag: Tag, seconds: TimeInterval)] {
        MetricsService.tagStats(tags: tags)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tags")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    showingAddTag = true
                } label: {
                    Label("Nova Tag", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if tags.isEmpty {
                EmptyStateView(
                    icon: "tag.fill",
                    title: "Sem tags",
                    message: "Crie tags como #swiftui, #hardware, #firmware para categorizar atividades."
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(tagStats, id: \.tag.persistentModelID) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.tag.displayName)
                                    .font(.headline)
                                    .foregroundStyle(Color(hex: item.tag.colorHex))
                                Spacer()
                                Button(role: .destructive) {
                                    context.delete(item.tag)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            Text(AppFormatters.formatHours(item.seconds))
                                .font(.title2.bold().monospacedDigit())
                            Text("\(item.tag.timeEntries.count) registros")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(24)
        .navigationTitle("Tags")
        .alert("Nova Tag", isPresented: $showingAddTag) {
            TextField("#nome", text: $newTagName)
            Button("Cancelar", role: .cancel) { newTagName = "" }
            Button("Adicionar") { addTag() }
        } message: {
            Text("Digite o nome da tag (com ou sem #)")
        }
        .onAppear { seedDefaultTagsIfNeeded() }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let tag = Tag(name: name.hasPrefix("#") ? String(name.dropFirst()) : name)
        context.insert(tag)
        try? context.save()
        newTagName = ""
    }

    private func seedDefaultTagsIfNeeded() {
        guard tags.isEmpty else { return }
        let defaults = ["swiftui", "hardware", "firmware", "esp32", "macbook", "iboot", "asn2", "cliente"]
        for name in defaults {
            context.insert(Tag(name: name))
        }
        try? context.save()
    }
}
