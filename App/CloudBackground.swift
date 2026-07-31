import SwiftUI

/// The hand-drawn crayon sky, behind every screen so the whole app lives in
/// one drawing. This replaced the procedural clouds: the real artwork carries
/// the texture and warmth that vector shapes never could.
struct CloudBackground: View {
    var body: some View {
        GeometryReader { geo in
            Image("sky-bg")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .background(Theme.skyTop.ignoresSafeArea())
    }
}
