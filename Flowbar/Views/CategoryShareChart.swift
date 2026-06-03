import SwiftUI

/// Tüm kategorilerin toplam içindeki payını gösteren tek satırlık, %100'e
/// normalize edilmiş yığılmış (stacked) çubuk. Bir segmentin üzerine gelince
/// çubuğun üstünde kategori adı + süre + yüzde tooltip'i belirir.
struct CategoryShareChart: View {
    let categories: [CategoryTotal]

    @State private var hovered: CategoryTotal?

    private var total: Int { categories.reduce(0) { $0 + $1.totalSeconds } }

    /// Sadece süresi olan kategoriler (boşlar çubukta yer kaplamasın).
    private var segments: [CategoryTotal] {
        categories.filter { $0.totalSeconds > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Hover tooltip'i için ayrılmış sabit yükseklikli alan
            // (görünüp kaybolurken çubuk zıplamasın diye).
            tooltip
                .frame(height: 16)

            if total == 0 || segments.isEmpty {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 10)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(segments) { item in
                            let fraction = CGFloat(item.totalSeconds) / CGFloat(total)
                            Rectangle()
                                .fill(Color(hex: item.colorHex) ?? .gray)
                                .opacity(hovered == nil || hovered == item ? 1 : 0.4)
                                .frame(width: max(geo.size.width * fraction, 2))
                                .onHover { inside in
                                    hovered = inside ? item : (hovered == item ? nil : hovered)
                                }
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())

                legend
            }
        }
        .animation(.snappy(duration: 0.14), value: hovered)
    }

    /// Çubuğun altındaki her zaman görünür lejant: nokta + kategori adı + süre.
    /// Hover'la senkron — üzerine gelinen kategori vurgulanır.
    private var legend: some View {
        FlowLayout(spacing: 10) {
            ForEach(segments) { item in
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: item.colorHex) ?? .gray)
                        .frame(width: 7, height: 7)
                    Text(item.name)
                        .foregroundStyle(hovered == nil || hovered == item ? .primary : .secondary)
                    Text(Duration.short(seconds: item.totalSeconds))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
                .opacity(hovered == nil || hovered == item ? 1 : 0.5)
                .onHover { inside in
                    hovered = inside ? item : (hovered == item ? nil : hovered)
                }
            }
        }
    }

    @ViewBuilder
    private var tooltip: some View {
        if let hovered, total > 0 {
            let percent = Int((Double(hovered.totalSeconds) / Double(total) * 100).rounded())
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: hovered.colorHex) ?? .gray)
                    .frame(width: 7, height: 7)
                Text(hovered.name)
                    .fontWeight(.semibold)
                Text("·").foregroundStyle(.secondary)
                Text(Duration.short(seconds: hovered.totalSeconds))
                    .monospacedDigit()
                Text("·").foregroundStyle(.secondary)
                Text("\(percent)%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .transition(.opacity)
        } else {
            Text("Hover a segment to see its category")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
