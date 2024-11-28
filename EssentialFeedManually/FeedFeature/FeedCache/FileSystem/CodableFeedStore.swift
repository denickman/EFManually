//
//  CodableFeedStore.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 26.11.2024.
//

import Foundation

public final class CodableFeedStore: FeedStore {
    
    private struct CodableCache: Codable {
        let feed: [CodableImageFeed]
        let timestamp: Date
        
        var local: [LocalFeedImage] { feed.map {$0.local }}
    }
    
    private struct CodableImageFeed: Codable {
        let id: UUID
        let description: String?
        let location: String?
        let url: URL
        
        init(feed: LocalFeedImage) {
            id = feed.id
            description = feed.description
            location = feed.location
            url = feed.url
        }
        
        var local: LocalFeedImage {
            .init(id: id, description: description, location: location, url: url)
        }
    }
    
    private let url: URL
    
    private let queue = DispatchQueue(
        label: "\(CodableFeedStore.self)Queue",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    public init(url: URL) {
        self.url = url
    }

    // MARK: - FeedStore
    
    public func retrieve(completion: @escaping (RetrievalResult) -> Void) {
        let storeURL = self.url
        
        queue.async {
            guard let data = try? Data(contentsOf: storeURL) else {
                return completion(.success(.none))
            }
            
            do {
                let decoder = JSONDecoder()
                let cache = try decoder.decode(CodableCache.self, from: data)
                completion(.success(CachedFeed(feed: cache.local, timestamp: cache.timestamp)))
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping (InsertionResult) -> Void) {
        let storeURL = self.url
        
        queue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let encoded = try encoder.encode(CodableCache.init(feed: feed.map(CodableImageFeed.init), timestamp: timestamp))
                try encoded.write(to: storeURL)
                completion(.success(()))
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    public func delete(completion: @escaping (DeletionResult) -> Void) {
        let storeURL = self.url
        
        queue.async(flags: .barrier) {
            guard FileManager.default.fileExists(atPath: storeURL.path) else {
                return completion(.success(()))
            }
            
            do {
                try FileManager.default.removeItem(at: storeURL)
                completion(.success(()))
            } catch let error {
                completion(.failure(error))
            }
        }
    }   
}
