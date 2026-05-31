import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue.gradient)
                        .symbolRenderingMode(.hierarchical)

                    Text(AppInfo.displayName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text(AppInfo.officialVersionLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(AppInfo.fullVersionLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 20) {
                    aboutBlock(
                        title: "Sobre",
                        text: "Hub pessoal para controle de tempo, produtividade, custos e evolução de projetos de software, hardware e pesquisa técnica."
                    )

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            infoRow(label: "Versão oficial", value: AppInfo.version)
                            infoRow(label: "Build", value: AppInfo.build)
                            infoRow(label: "Identificador", value: AppInfo.bundleIdentifier)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    }

                    aboutBlock(
                        title: "Recursos",
                        text: "Timer global, Pomodoro, relatórios financeiros, metas, tags, métricas avançadas e sincronização via pasta iCloud Drive."
                    )

                    Text(AppInfo.copyright)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .padding(32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sobre")
    }

    private func aboutBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

#Preview {
    AboutView()
}
