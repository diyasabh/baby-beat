import SwiftUI

/// The house icon set: hand-drawn marks that stand in for SF Symbols wherever
/// we have real art. They ship as template SVGs, so they take a tint exactly
/// like a symbol does and stay crisp at any size.
enum Brand: String {
    case heartbeat = "icon-heartbeat"
    case bell = "icon-bell"
    case sun = "icon-sun"
    case spark = "icon-spark"
}

/// One hand-drawn mark. Always use this rather than `Image(...)` directly, so
/// sizing and template rendering stay identical everywhere.
struct BrandIcon: View {
    var icon: Brand
    var size: CGFloat = 18

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// A card heading: hand-drawn mark in heart pink, title in ink. Replaces the
/// old `Label(_, systemImage:)` headings so every card reads the same.
struct BrandLabel: View {
    var title: String
    var icon: Brand
    var tint: Color = Theme.heart

    var body: some View {
        HStack(spacing: 9) {
            BrandIcon(icon: icon, size: 19)
                .foregroundStyle(tint)
            Text(title)
                .font(Theme.body(16))
                .foregroundStyle(Theme.ink)
        }
    }
}
