import Foundation

/// Built-in starter templates, one per hobby. The template marketplace (see ROADMAP.md) extends this.
struct HobbyTemplate: Identifiable {
    let id: String
    let hobby: HobbyKind
    let name: String
    let summary: String
    let columns: [(String, [String])]
    let materials: [(String, Double, String, Double)]

    func makeProject(named name: String, target: Date?) -> Project {
        var p = Project(name: name, hobby: hobby)
        p.summary = summary
        p.targetDate = target
        p.columns = columns.map { title, cards in
            BoardColumn(title: title, cards: cards.map { BoardCard(title: $0) })
        }
        p.materials = materials.map { Material(name: $0.0, quantity: $0.1, unit: $0.2, unitCost: $0.3) }
        return p
    }

    static func blank(_ hobby: HobbyKind) -> HobbyTemplate {
        HobbyTemplate(id: "blank-\(hobby.rawValue)", hobby: hobby, name: "Blank board",
                      summary: "", columns: [("To Do", []), ("In Progress", []), ("Done", [])], materials: [])
    }

    static func templates(for hobby: HobbyKind) -> [HobbyTemplate] {
        all.filter { $0.hobby == hobby } + [blank(hobby)]
    }

    static let all: [HobbyTemplate] = [
        HobbyTemplate(
            id: "garden-raised-bed", hobby: .gardening, name: "Raised vegetable bed",
            summary: "Plan, build and plant a raised bed for the season.",
            columns: [
                ("Plan", ["Pick a sunny spot", "Choose crops & spacing", "Test soil pH"]),
                ("Prep", ["Build the bed frame", "Fill with soil & compost"]),
                ("Growing", ["Sow seeds / transplant seedlings", "Set up watering schedule"]),
                ("Harvested", []),
            ],
            materials: [("Cedar boards 2x10", 4, "pcs", 18), ("Raised bed soil", 6, "bags", 9),
                        ("Compost", 2, "bags", 7), ("Seed packets", 5, "pcs", 3.5)]),
        HobbyTemplate(
            id: "model-scale-kit", hobby: .modelBuilding, name: "Scale model kit",
            summary: "Build, paint and weather a plastic scale kit.",
            columns: [
                ("Prep", ["Wash sprues", "Read instructions & plan subassemblies"]),
                ("Build", ["Cockpit / interior", "Main assembly", "Fill & sand seams"]),
                ("Paint", ["Prime", "Base coats", "Decals", "Weathering"]),
                ("Finished", []),
            ],
            materials: [("Plastic cement", 1, "bottle", 6), ("Primer", 1, "can", 12),
                        ("Acrylic paint set", 1, "set", 25), ("Sanding sticks", 1, "pack", 8)]),
        HobbyTemplate(
            id: "electronics-arduino", hobby: .electronics, name: "Microcontroller build",
            summary: "Prototype, code and box an Arduino / ESP32 project.",
            columns: [
                ("Design", ["Sketch the circuit", "List components"]),
                ("Prototype", ["Breadboard the circuit", "Write firmware", "Test & debug"]),
                ("Build", ["Solder to perfboard / PCB", "Design enclosure"]),
                ("Done", []),
            ],
            materials: [("ESP32 dev board", 1, "pcs", 9), ("Breadboard", 1, "pcs", 5),
                        ("Jumper wires", 1, "pack", 6), ("Resistor kit", 1, "kit", 10)]),
        HobbyTemplate(
            id: "wood-furniture", hobby: .woodworking, name: "Furniture piece",
            summary: "From cut list to finish for a small furniture build.",
            columns: [
                ("Design", ["Measure & draw plans", "Make a cut list"]),
                ("Milling", ["Rough cut", "Joint & plane"]),
                ("Joinery & Assembly", ["Cut joinery", "Dry fit", "Glue up"]),
                ("Finishing", ["Sand to 220", "Apply finish"]),
                ("Done", []),
            ],
            materials: [("Hardwood board feet", 20, "bf", 8), ("Wood glue", 1, "bottle", 9),
                        ("Sandpaper assortment", 1, "pack", 14), ("Finish (oil/poly)", 1, "can", 22)]),
        HobbyTemplate(
            id: "collection-catalog", hobby: .collections, name: "Catalog a collection",
            summary: "Track what you own, what you want and how it's displayed.",
            columns: [
                ("Wishlist", []),
                ("Hunting", []),
                ("Acquired", []),
                ("Displayed", []),
            ],
            materials: [("Display case", 1, "pcs", 40), ("Protective sleeves", 1, "pack", 8)]),
        HobbyTemplate(
            id: "personal-goal", hobby: .personal, name: "Personal goal",
            summary: "Break a personal project into milestones.",
            columns: [("Ideas", []), ("Next Up", []), ("Doing", []), ("Done", [])],
            materials: []),
    ]
}
