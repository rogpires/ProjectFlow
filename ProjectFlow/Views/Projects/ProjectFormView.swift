import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var project: Project?

    @State private var name = ""
    @State private var description = ""
    @State private var category: ProjectCategory = .software
    @State private var status: ProjectStatus = .planning
    @State private var colorHex = "#007AFF"
    @State private var iconName = "folder.fill"
    @State private var hourlyRate = 100.0
    @State private var estimatedROI = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Informações") {
                    TextField("Nome", text: $name)
                    TextField("Descrição", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Categoria", selection: $category) {
                        ForEach(ProjectCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section("Aparência") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(ProjectColorPalette.colors, id: \.hex) { item in
                            Circle()
                                .fill(Color(hex: item.hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if colorHex == item.hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = item.hex }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(ProjectIconPalette.icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .frame(width: 32, height: 32)
                                .background(iconName == icon ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .onTapGesture { iconName = icon }
                        }
                    }
                }

                Section("Financeiro") {
                    HStack {
                        Text("Valor hora")
                        Spacer()
                        TextField("100", value: $hourlyRate, format: .currency(code: "BRL"))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("ROI estimado")
                        Spacer()
                        TextField("0", value: $estimatedROI, format: .currency(code: "BRL"))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(project == nil ? "Novo Projeto" : "Editar Projeto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadProject() }
            .frame(minWidth: 480, minHeight: 520)
        }
    }

    private func loadProject() {
        guard let project else { return }
        name = project.name
        description = project.projectDescription
        category = project.category
        status = project.status
        colorHex = project.colorHex
        iconName = project.iconName
        hourlyRate = project.hourlyRate
        estimatedROI = project.estimatedROI
    }

    private func save() {
        if let project {
            project.name = name
            project.projectDescription = description
            project.category = category
            project.status = status
            project.colorHex = colorHex
            project.iconName = iconName
            project.hourlyRate = hourlyRate
            project.estimatedROI = estimatedROI
        } else {
            let newProject = Project(
                name: name,
                projectDescription: description,
                category: category,
                status: status,
                colorHex: colorHex,
                iconName: iconName,
                hourlyRate: hourlyRate,
                estimatedROI: estimatedROI
            )
            context.insert(newProject)
            appState.activityLogger.log(
                action: .projectCreated,
                details: name,
                project: newProject,
                context: context
            )
        }
        try? context.save()
        dismiss()
    }
}
