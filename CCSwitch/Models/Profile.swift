import Foundation

struct Profile: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var configDir: URL
    var activeProviderId: UUID?
}
