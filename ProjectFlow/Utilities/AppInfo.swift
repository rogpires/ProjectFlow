import Foundation

enum AppInfo {
    static let displayName = "ProjectFlow"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var officialVersionLabel: String {
        "Versão \(version)"
    }

    static var fullVersionLabel: String {
        "Versão \(version) (build \(build))"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.rogeriocpires.ProjectFlow"
    }

    static var copyright: String {
        "© \(Calendar.current.component(.year, from: Date())) Rogerio Pires"
    }
}
