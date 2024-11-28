//
//  LocalFeedLoader.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 28.11.2024.
//

import Foundation

public final class LocalFeedLoader {
    
    private let store: FeedStore
    private let currentDate: () -> Date
    
    public init(store: FeedStore, currentDate: @escaping () -> Date) {
        self.store = store
        self.currentDate = currentDate
    }
}

// MARK: - Save
extension LocalFeedLoader {
    
    public typealias SaveResult = Result<Void, Error>
    
    func save(_ feed: [FeedImage], completion: @escaping (SaveResult) -> Void) {
        // deletecache
        store.delete { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success:
                toCache(feed, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func toCache(_ feed: [FeedImage], completion: @escaping (SaveResult) -> Void) {
        store.insert(feed.toLocal(), timestamp: currentDate()) { [weak self] result in
            guard let self else { return }
            completion(result)
        }
    }
}

// MARK: - Load
extension LocalFeedLoader: FeedLoader {
    
    public func load(completion: @escaping (FeedLoader.Result) -> Void) {
        store.retrieve { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(.some(let cache)) where FeedCachePolicy.validate(cache.timestamp, against: self.currentDate()):
                completion(.success(cache.feed.toModels())) // LocalFeedImage into FeedImage

            case .success: // found but not valid
                completion(.success([]))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

extension Array where Element == FeedImage {
    func toLocal() -> [LocalFeedImage] {
        map { .init(id: $0.id, description: $0.description, location: $0.location, url: $0.url)}
    }
}

extension Array where Element == LocalFeedImage {
    func toModels() -> [FeedImage] {
        map { .init(id: $0.id, description: $0.description, location: $0.location, url: $0.url) }
    }
}



// MARK: - For tests

extension LocalFeedLoader {
    public func validateCache() {
        store.retrieve { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(.some(let cache)) where FeedCachePolicy.validate(cache.timestamp, against: currentDate()):
                self.store.delete { _ in }
                
            case .failure(let error):
                self.store.delete { _ in }
                
            case .success: // found but not valid
                break
            }
        }
    }
}
