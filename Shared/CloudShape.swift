import SwiftUI

/// A thick puffy cloud built from overlapping circles on a rounded base.
/// The one cloud of the app: the sky, the widget corner, everywhere.
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Rounded base so the bottom reads full and heavy.
        p.addRoundedRect(in: CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.5),
                         cornerSize: CGSize(width: h * 0.25, height: h * 0.25))
        // Three fat puffs on top.
        p.addEllipse(in: CGRect(x: w * 0.08, y: h * 0.22, width: w * 0.38, height: w * 0.38))
        p.addEllipse(in: CGRect(x: w * 0.32, y: 0, width: w * 0.46, height: w * 0.46))
        p.addEllipse(in: CGRect(x: w * 0.60, y: h * 0.26, width: w * 0.34, height: w * 0.34))
        return p
    }
}
