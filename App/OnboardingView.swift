import SwiftUI

/// First run: pick a side, then say who everybody is. The choice decides
/// which whole half of the app you get, so it is the very first question.
struct OnboardingView: View {
    @EnvironmentObject private var model: BeatModel

    private enum Step { case role, details }
    @State private var step: Step = .role
    @State private var picked: Role?

    // Prefilled with the sweet defaults so nobody has to type to get going.
    @State private var babyName = "baby"
    @State private var caregiverName = "miss rosie"
    @State private var place = "little clouds daycare"
    @State private var parentName = "mom"

    var body: some View {
        ZStack {
            CloudBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    hero
                    switch step {
                    case .role: rolePicker
                    case .details: details
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            // The real brand drawing, only here on the welcome screen. Every
            // other heart in the app is the live PulsingHeart.
            // The artwork carries its own sky, so it needs a white rim to read
            // as an icon resting on the page rather than a patch of it.
            Image("brand-heart")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Theme.cloud, lineWidth: 5)
                )
                .shadow(color: Theme.ink.opacity(0.22), radius: 18, y: 10)
            Text("baby beat")
                .font(Theme.title(32))
                .foregroundStyle(Theme.ink)
            Text(step == .role ? "who's holding the phone?" : subtitleForDetails)
                .font(Theme.body(16))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitleForDetails: String {
        picked == .parent ? "tell us about your little one" : "tell us who you are"
    }

    // MARK: Step one

    private var rolePicker: some View {
        VStack(spacing: 14) {
            ForEach(Role.allCases, id: \.self) { role in
                Button {
                    withAnimation(Theme.ease) {
                        picked = role
                        step = .details
                    }
                } label: {
                    roleCard(role)
                }
                .buttonStyle(SquishButtonStyle())
            }
            Text("you can switch views any time")
                .font(Theme.meta(12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 2)
        }
    }

    private func roleCard(_ role: Role) -> some View {
        CloudCard(padding: 22) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.heart.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: role.symbol)
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.heart)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(role.title)
                        .font(Theme.body(18))
                        .foregroundStyle(Theme.ink)
                    Text(role.blurb)
                        .font(Theme.meta(13))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Step two

    @ViewBuilder
    private var details: some View {
        let role = picked ?? .parent
        VStack(spacing: 16) {
            CloudCard(padding: 22) {
                VStack(alignment: .leading, spacing: 16) {
                    if role == .parent {
                        SoftField(label: "your little one's name", text: $babyName)
                        Divider().opacity(0.3)
                        Text("who looks after them?")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                        SoftField(label: "caregiver", text: $caregiverName)
                        SoftField(label: "where", text: $place)
                    } else {
                        SoftField(label: "your name", text: $caregiverName)
                        SoftField(label: "where you look after little ones", text: $place)
                        Divider().opacity(0.3)
                        SoftField(label: "the little one in your care", text: $babyName)
                    }
                }
            }

            CloudCard(padding: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: role == .parent ? "eye.fill" : "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.heart)
                        .frame(width: 20)
                    Text(role == .parent
                         ? "as a parent you'll watch beats come in and can ask for a check any time. taking a beat is the caregiver's job."
                         : "as a caregiver you'll count beats on this phone and send them home. you'll see when a parent asks for one.")
                        .font(Theme.meta(13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HeartButton(title: "start", brand: .spark) {
                finish(role: role)
            }

            Button("go back") {
                withAnimation(Theme.ease) { step = .role }
            }
            .font(Theme.meta(14))
            .foregroundStyle(Theme.inkSoft)
            .buttonStyle(SquishButtonStyle())
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private func finish(role: Role) {
        let baby = babyName.trimmed(or: "baby")
        let where_ = place.trimmed(or: "little clouds daycare")
        let carer = caregiverName.trimmed(or: "miss rosie")

        switch role {
        case .parent:
            let profile = Profile(role: .parent, name: parentName.trimmed(or: "mom"),
                                  place: where_, babyName: baby)
            model.finishOnboarding(with: profile,
                                   providers: [Provider(name: carer, place: where_)])
        case .caregiver:
            let profile = Profile(role: .caregiver, name: carer,
                                  place: where_, babyName: baby)
            model.finishOnboarding(with: profile, providers: [])
        }
    }
}

private extension String {
    /// Trimmed, or the fallback when someone clears the field entirely.
    func trimmed(or fallback: String) -> String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }
}
