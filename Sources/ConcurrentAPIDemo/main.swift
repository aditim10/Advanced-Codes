import Foundation
import ConcurrentAPI

let client = APIClient(
    configuration: APIConfiguration(
        baseURL: URL(string: "https://jsonplaceholder.typicode.com")!
    )
)

// DispatchSemaphore lets us block the main thread until all async work is done.
// This is the correct pattern for a CLI executable — not RunLoop or Thread.sleep.
let semaphore = DispatchSemaphore(value: 0)

Task {
    await runSingleRequest(client: client)
    await runConcurrentBatch(client: client)
    await runMixedBatch(client: client)
    semaphore.signal()
}

semaphore.wait()
