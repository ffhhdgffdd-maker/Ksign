import Foundation
import CoreData
import AltSourceKit
import SwiftUI

/// Core Data objects and published UI state remain on the main actor.
/// Network tasks receive only immutable URL/index values.
@MainActor
final class SourcesViewModel: ObservableObject {
    static let shared = SourcesViewModel()
    typealias RepositoryDataHandler = Result<ASRepository, Error>
    @Published private(set) var isFinished = true
    @Published var sources: [AltSource: ASRepository] = [:]

    private struct Request: Sendable {
        let index: Int
        let url: URL
    }

    func fetchSources(_ fetchedSources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
        guard isFinished else { return }
        let objects = Array(fetchedSources)
        if !refresh, objects.allSatisfy({ sources[$0] != nil }) { return }
        let requests = objects.enumerated().compactMap { index, object -> Request? in
            guard !object.isDeleted, let url = object.sourceURL else { return nil }
            return Request(index: index, url: url)
        }
        isFinished = false
        defer { isFinished = true }

        // Retain usable results during refresh; a failed request must not erase the catalog.
        let activeIDs = Set(objects.map(\.objectID))
        sources = sources.filter { !$0.key.isDeleted && activeIDs.contains($0.key.objectID) }
        let limit = max(1, batchSize)
        for start in stride(from: 0, to: requests.count, by: limit) {
            if Task.isCancelled { break }
            let batch = Array(requests[start..<min(start + limit, requests.count)])
            let results = await withTaskGroup(of: (Int, ASRepository?).self) { group in
                for request in batch {
                    group.addTask {
                        var repository: ASRepository?
                        do {
                            var networkRequest = URLRequest(url: request.url)
                            networkRequest.timeoutInterval = 45
                            let (data, response) = try await URLSession.shared.data(for: networkRequest)
                            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                                return (request.index, nil)
                            }
                            repository = try JSONDecoder().decode(ASRepository.self, from: data)
                        } catch {
                            repository = nil
                        }
                        return (request.index, repository)
                    }
                }
                var result: [(Int, ASRepository)] = []
                for await (index, repository) in group {
                    if let repository { result.append((index, repository)) }
                }
                return result
            }
            guard !Task.isCancelled else { break }
            for (index, repository) in results {
                let object = objects[index]
                guard !object.isDeleted, object.managedObjectContext != nil else { continue }
                sources[object] = repository
            }
        }
    }
}
