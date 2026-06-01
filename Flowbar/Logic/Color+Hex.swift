import SwiftUI

extension Color {
    /// "#RRGGBB" formatından Color üretir; geçersizse nil.
    init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    /// Color'ı "#RRGGBB" hex'e çevirir (NSColor üzerinden).
    func toHex() -> String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
