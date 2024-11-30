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

extension LocalFeedLoader: FeedLoader {
    public func load(completion: @escaping (FeedLoader.Result) -> Void) {
        store.retrieve { [weak self] result in
            
            guard let self else { return }
            
            switch result {
            case .success(.some(let cache)) where FeedCachePolicy.validate(cache.timestamp, against: self.currentDate()):
                completion(.success(cache.feed.toModels()))
                
            case .success:
                completion(.success([]))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

extension LocalFeedLoader {
    public typealias SaveResult = Result<Void, Error>
    
    public func save(_ feed: [FeedImage], completion: @escaping (SaveResult) -> Void) {
        store.delete { [weak self] deletionResult in
            guard let self else { return }
            
            switch deletionResult {
            case .success:
                self.cache(feed, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func cache(_ feed: [FeedImage], completion: @escaping (SaveResult) -> Void) {
        store.insert(feed.toLocal(), timestamp: currentDate()) {[weak self] insertionCompletion in
            guard self != nil else { return }
            completion(insertionCompletion)
        }
    }
}
    

extension LocalFeedLoader {
    func valiateCache() {
        store.retrieve { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.some(let cache)) where !FeedCachePolicy.validate(cache.timestamp, against: currentDate()):
                self.store.delete(completion: { _ in })
                
            case .failure:
                self.store.delete(completion: { _ in })
                
            case .success: break
            }
        }
    }
}
















   
extension Array where Element == LocalFeedImage {
    func toModels() -> [FeedImage] {
        map { FeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.url) }
    }
}

extension Array where Element == FeedImage {
    func toLocal() -> [LocalFeedImage] {
        map { LocalFeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.url) }
    }
}

