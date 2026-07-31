import SwiftUI

/// Who is holding the phone. Chosen once in onboarding, switchable later.
/// The whole app diverges on this: caregivers take beats and send them home,
/// parents watch and ask. Nobody sees the other side's controls.
enum Role: String, Codable, CaseIterable {
    case parent
    case caregiver

    var title: String {
        switch self {
        case .parent: return "i'm a parent"
        case .caregiver: return "i look after little ones"
        }
    }

    var blurb: String {
        switch self {
        case .parent: return "watch baby's beats from anywhere, and ask for a check whenever you need one"
        case .caregiver: return "count a little heartbeat and send it straight home"
        }
    }

    var symbol: String {
        switch self {
        case .parent: return "figure.and.child.holdinghands"
        case .caregiver: return "hands.sparkles.fill"
        }
    }

    /// Name for the view itself, used when switching.
    var viewName: String {
        switch self {
        case .parent: return "parent view"
        case .caregiver: return "caregiver view"
        }
    }

    var other: Role { self == .parent ? .caregiver : .parent }
}

/// The grown-up using this phone.
struct Profile: Codable, Equatable {
    var role: Role
    /// What baby's people call them: "mom" for a parent, "miss rosie" for a caregiver.
    var name: String
    /// Where baby is looked after.
    var place: String
    var babyName: String

    static let parentDefault = Profile(role: .parent, name: "mom",
                                       place: "little clouds daycare", babyName: "baby")
    static let caregiverDefault = Profile(role: .caregiver, name: "miss rosie",
                                          place: "little clouds daycare", babyName: "baby")
}

/// A caregiver a parent has added, and can ask for a beat.
struct Provider: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var place: String

    init(id: UUID = UUID(), name: String, place: String) {
        self.id = id
        self.name = name
        self.place = place
    }

    /// "miss rosie at little clouds daycare"
    var label: String { "\(name) at \(place)" }
}

/// A parent asking for a heartbeat check. The caregiver side sees these
/// waiting; taking a beat answers every one of them.
struct BeatRequest: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// Who asked, e.g. "mom".
    let fromParent: String
    let babyName: String
    var answeredAt: Date?

    init(id: UUID = UUID(), date: Date = .now, fromParent: String,
         babyName: String, answeredAt: Date? = nil) {
        self.id = id
        self.date = date
        self.fromParent = fromParent
        self.babyName = babyName
        self.answeredAt = answeredAt
    }

    var isWaiting: Bool { answeredAt == nil }
}
