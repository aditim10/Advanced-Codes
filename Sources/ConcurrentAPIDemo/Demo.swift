import Foundation
import ConcurrentAPI

// MARK: - Single request

func runSingleRequest(client: APIClient) async {
    print("\n--- Single request ---")

    do {
        let post = try await client.send(GetPost(id: 1))
        print("Post \(post.id): \(post.title)")
    } catch {
        print("Failed: \(error.localizedDescription)")
    }
}

// MARK: - Concurrent batch (same type)

func runConcurrentBatch(client: APIClient) async {
    print("\n--- Concurrent batch: 5 posts ---")

    let requests = (1...5).map { GetPost(id: $0) }
    let results = await client.sendConcurrently(requests)

    // Results arrive in completion order, not request order —
    // sort them so the output is readable
    let sorted = results.sorted { ($0.value?.id ?? 0) < ($1.value?.id ?? 0) }

    for result in sorted {
        switch result.outcome {
        case .success(let post):
            print("  [\(post.id)] \(post.title)")
        case .failure(let error):
            print("  [\(result.path)] failed — \(error.localizedDescription)")
        }
    }

    let successCount = results.filter(\.isSuccess).count
    print("  \(successCount)/\(results.count) succeeded")
}

// MARK: - Mixed batch (different response types)

func runMixedBatch(client: APIClient) async {
    print("\n--- Mixed batch: post + todo + user ---")

    // Three completely different response types fired concurrently in one shot
    let mixed: [any APIRequest] = [
        GetPost(id: 3),
        GetTodo(id: 7),
        GetUser(id: 2)
    ]

    let results = await client.sendConcurrentlyRaw(mixed)
    let decoder = JSONDecoder()

    for result in results {
        guard let data = result.data else {
            print("  [\(result.path)] failed — \(result.error!.localizedDescription)")
            continue
        }

        if result.path.contains("posts"),
           let post = try? decoder.decode(Post.self, from: data) {
            print("  Post: \"\(post.title)\"")
        } else if result.path.contains("todos"),
                  let todo = try? decoder.decode(Todo.self, from: data) {
            print("  Todo: \"\(todo.title)\" — completed: \(todo.completed)")
        } else if result.path.contains("users"),
                  let user = try? decoder.decode(User.self, from: data) {
            print("  User: \(user.name) <\(user.email)>")
        }
    }
}
