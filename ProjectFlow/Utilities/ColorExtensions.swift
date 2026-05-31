import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0.478; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components else {
            return "#007AFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct ProjectColorPalette {
    static let colors: [(name: String, hex: String)] = [
        ("Azul", "#007AFF"),
        ("Verde", "#34C759"),
        ("Laranja", "#FF9500"),
        ("Vermelho", "#FF3B30"),
        ("Roxo", "#AF52DE"),
        ("Rosa", "#FF2D55"),
        ("Teal", "#5AC8FA"),
        ("Índigo", "#5856D6"),
        ("Amarelo", "#FFCC00"),
        ("Cinza", "#8E8E93")
    ]
}

struct ProjectIconPalette {
    static let icons: [String] = [
        "folder.fill", "hammer.fill", "wrench.and.screwdriver.fill",
        "cpu", "memorychip", "laptopcomputer", "desktopcomputer",
        "antenna.radiowaves.left.and.right", "bolt.fill", "gearshape.fill",
        "lightbulb.fill", "book.fill", "person.fill", "star.fill",
        "flag.fill", "cube.fill", "network", "terminal.fill"
    ]
}
