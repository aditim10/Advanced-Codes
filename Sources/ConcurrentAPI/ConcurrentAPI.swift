// ConcurrentAPI
//
// A lightweight, generic networking layer built on Swift Concurrency.
//
// Typical setup:
//
//     import ConcurrentAPI
//
//     let client = APIClient(
//         configuration: APIConfiguration(
//             baseURL: URL(string: "https://api.example.com/v1")!
//         )
//     )
//
// Then define your endpoints:
//
//     struct GetUserRequest: APIRequest {
//         typealias Response = User
//         let id: Int
//         var path: String { "users/\(id)" }
//     }
//
// And call away:
//
//     let user = try await client.send(GetUserRequest(id: 1))
//
//     // or fetch many at once
//     let results = await client.sendConcurrently(ids.map { GetUserRequest(id: $0) })
