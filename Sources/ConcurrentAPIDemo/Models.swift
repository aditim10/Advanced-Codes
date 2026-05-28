import Foundation

struct Post: Codable, Sendable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

struct Todo: Codable, Sendable {
    let id: Int
    let title: String
    let completed: Bool
}

struct User: Codable, Sendable {
    let id: Int
    let name: String
    let email: String
}
