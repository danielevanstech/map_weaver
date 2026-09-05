import Foundation
import SwiftData

@Model
final class ProjectFolder {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \MapProject.folder)
    var projects: [MapProject]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.projects = []
    }
}
