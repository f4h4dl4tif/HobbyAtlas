import SwiftUI

// MARK: - Hobbies

enum HobbyKind: String, Codable, CaseIterable, Identifiable {
    case gardening, modelBuilding, electronics, woodworking, collections, personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gardening: "Gardening"
        case .modelBuilding: "Model Building"
        case .electronics: "Electronics"
        case .woodworking: "Woodworking"
        case .collections: "Collections"
        case .personal: "Personal"
        }
    }

    var symbol: String {
        switch self {
        case .gardening: "leaf.fill"
        case .modelBuilding: "airplane"
        case .electronics: "cpu"
        case .woodworking: "hammer.fill"
        case .collections: "square.stack.3d.up.fill"
        case .personal: "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .gardening: Color(red: 0.30, green: 0.66, blue: 0.36)
        case .modelBuilding: Color(red: 0.30, green: 0.52, blue: 0.90)
        case .electronics: Color(red: 0.55, green: 0.38, blue: 0.92)
        case .woodworking: Color(red: 0.76, green: 0.50, blue: 0.26)
        case .collections: Color(red: 0.88, green: 0.36, blue: 0.48)
        case .personal: Color(red: 0.93, green: 0.65, blue: 0.20)
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case planning, active, paused, done
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .planning: .blue
        case .active: .green
        case .paused: .orange
        case .done: .gray
        }
    }
}

// MARK: - Board

enum CardLabel: String, Codable, CaseIterable, Identifiable {
    case none, red, orange, yellow, green, blue, purple
    var id: String { rawValue }
    var color: Color? {
        switch self {
        case .none: nil
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }
}

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var done = false
}

struct BoardCard: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var notes = ""
    var label: CardLabel = .none
    var due: Date?
    var checklist: [ChecklistItem] = []
    var createdAt = Date()
}

struct BoardColumn: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var cards: [BoardCard] = []
}

// MARK: - Materials

enum MaterialStatus: String, Codable, CaseIterable, Identifiable {
    case need, ordered, have
    var id: String { rawValue }
    var title: String {
        switch self {
        case .need: "Need"
        case .ordered: "Ordered"
        case .have: "Have"
        }
    }
    var color: Color {
        switch self {
        case .need: .red
        case .ordered: .orange
        case .have: .green
        }
    }
}

struct Material: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var quantity: Double = 1
    var unit = "pcs"
    var unitCost: Double = 0
    var status: MaterialStatus = .need
    var supplier = ""

    var total: Double { quantity * unitCost }
}

// MARK: - Photos

struct ProgressPhoto: Codable, Identifiable, Hashable {
    var id = UUID()
    var fileName: String
    var caption = ""
    var takenAt = Date()
}

// MARK: - Project

struct Project: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var hobby: HobbyKind
    var summary = ""
    var status: ProjectStatus = .planning
    var createdAt = Date()
    var targetDate: Date?
    var columns: [BoardColumn] = []
    var materials: [Material] = []
    var photos: [ProgressPhoto] = []
    var coverPhotoID: UUID?
    var notes = ""

    var allCards: [BoardCard] { columns.flatMap(\.cards) }

    /// Share of cards that sit in the last column ("Done").
    var progress: Double {
        let total = allCards.count
        guard total > 0, let last = columns.last else { return status == .done ? 1 : 0 }
        return Double(last.cards.count) / Double(total)
    }

    var materialsTotal: Double { materials.reduce(0) { $0 + $1.total } }
    var materialsToBuy: Double { materials.filter { $0.status == .need }.reduce(0) { $0 + $1.total } }

    var coverPhoto: ProgressPhoto? {
        if let id = coverPhotoID, let p = photos.first(where: { $0.id == id }) { return p }
        return photos.max(by: { $0.takenAt < $1.takenAt })
    }
}

struct Library: Codable {
    var version = 1
    var projects: [Project] = []
    var currency = "USD"
}

extension Double {
    func money(_ code: String) -> String {
        formatted(.currency(code: code))
    }

    var trimmed: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.2f", self)
    }
}
