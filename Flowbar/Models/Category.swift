import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var colorHex: String
    @Relationship(deleteRule: .nullify, inverse: \Project.category)
    var projects: [Project]

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.projects = []
    }
}

enum CategoryPalette {
    static let colors = [
        "#1D9BF0",
        "#27AE60",
        "#9B51E0",
        "#EB5757",
        "#F2994A",
        "#F2C94C",
        "#2D9CDB",
        "#6FCF97",
        "#BB6BD9",
        "#828282"
    ]

    static let defaultHex = colors[0]
}

enum CategoryManagement {
    static func delete(_ category: Category, in context: ModelContext) {
        for project in category.projects {
            project.category = nil
        }
        context.delete(category)
    }
}
