import Foundation
import ConcurrentAPI

// One struct per endpoint — that's the whole pattern.
// The compiler enforces that Response matches what the server actually returns.

struct GetPost: APIRequest {
    typealias Response = Post
    let id: Int
    var path: String { "posts/\(id)" }
}

struct GetTodo: APIRequest {
    typealias Response = Todo
    let id: Int
    var path: String { "todos/\(id)" }
}

struct GetUser: APIRequest {
    typealias Response = User
    let id: Int
    var path: String { "users/\(id)" }
}
