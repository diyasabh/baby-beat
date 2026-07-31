import SwiftUI

/// Decides which app you are in. Onboarding until a side is picked, then the
/// dashboard for that role. Only the caregiver side can open the camera.
struct RootView: View {
    @EnvironmentObject private var model: BeatModel
    @State private var showsProfile = false

    var body: some View {
        Group {
            switch model.profile?.role {
            case .none:
                OnboardingView()
                    .transition(.opacity)
            case .parent:
                ParentDashboard(showsProfile: $showsProfile)
                    .transition(.opacity)
            case .caregiver:
                CaregiverDashboard(showsProfile: $showsProfile)
                    .transition(.opacity)
            }
        }
        .animation(Theme.ease, value: model.profile?.role)
        .sheet(isPresented: $showsProfile) {
            ProfileSheet()
                .environmentObject(model)
        }
        .fullScreenCover(isPresented: $model.wantsMeasure) {
            if model.profile?.role == .caregiver {
                MeasureView()
            }
        }
    }
}

/// Who you are, who your people are, and the door between the two views.
struct ProfileSheet: View {
    @EnvironmentObject private var model: BeatModel
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var newPlace = ""
    @State private var addingProvider = false

    private var profile: Profile? { model.profile }

    var body: some View {
        ZStack {
            CloudBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    handle
                    if let profile {
                        youCard(profile)
                        if profile.role == .parent { peopleCard }
                        switchCard(profile)
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
    }

    private var handle: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Theme.ink.opacity(0.15))
                .frame(width: 40, height: 5)
            Text("your account")
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func youCard(_ profile: Profile) -> some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("you", systemImage: profile.role.symbol)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
                PersonRow(name: profile.name, detail: profile.role.viewName) {
                    EmptyView()
                }
                Divider().opacity(0.3)
                PersonRow(name: profile.babyName, detail: profile.place,
                          symbol: "teddybear.fill", tint: BeatMood.sleepy.color) {
                    EmptyView()
                }
            }
        }
    }

    private var peopleCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("caregivers you can ask", systemImage: "person.2.fill")
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
                ForEach(model.providers) { provider in
                    PersonRow(name: provider.name, detail: provider.place) {
                        Button {
                            withAnimation(Theme.ease) { model.removeProvider(provider) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .buttonStyle(SquishButtonStyle())
                    }
                }
                if addingProvider {
                    VStack(spacing: 12) {
                        SoftField(label: "their name", text: $newName)
                        SoftField(label: "where", text: $newPlace)
                        HStack(spacing: 10) {
                            SoftButton(title: "add", systemImage: "checkmark") {
                                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                                let place = newPlace.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                withAnimation(Theme.ease) {
                                    model.addProvider(name: name,
                                                      place: place.isEmpty ? (profile?.place ?? "daycare") : place)
                                    newName = ""
                                    newPlace = ""
                                    addingProvider = false
                                }
                            }
                            SoftButton(title: "cancel", systemImage: "xmark", tint: Theme.ink) {
                                withAnimation(Theme.ease) { addingProvider = false }
                            }
                        }
                    }
                } else {
                    SoftButton(title: "add a caregiver", systemImage: "person.badge.plus") {
                        withAnimation(Theme.ease) { addingProvider = true }
                    }
                }
            }
        }
    }

    private func switchCard(_ profile: Profile) -> some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("switch views", systemImage: "arrow.left.arrow.right")
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
                Text(profile.role == .parent
                     ? "hop over to the caregiver view to count a beat and send it home."
                     : "hop over to the parent view to watch beats arrive and ask for a check.")
                    .font(Theme.meta(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HeartButton(title: "go to the \(profile.role.other.viewName)",
                            systemImage: "arrow.left.arrow.right") {
                    model.switchRole()
                    dismiss()
                }
            }
        }
    }
}
