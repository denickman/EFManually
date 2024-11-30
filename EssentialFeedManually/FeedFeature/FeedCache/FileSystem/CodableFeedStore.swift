//
//  CodableFeedStore.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 26.11.2024.
//

import Foundation

public final class CodableFeedStore {
 
    private struct Cache: Codable {
        
        let feed: [CodableFeedImage]
        let timestamp: Date
        
        var local: [LocalFeedImage] {
            feed.map { $0.localFeedImage }
        }
    }

    private struct CodableFeedImage: Codable {
         let id: UUID
         let description: String?
         let location: String?
         let url: URL
        
        init(with local: LocalFeedImage) {
            id = local.id
            description = local.description
            location = local.location
            url = local.url
        }
        
        var localFeedImage: LocalFeedImage {
            .init(id: id, description: description, location: location, url: url)
        }
    }
    
    private let storeURL: URL
    
    private let queue = DispatchQueue.init(label: "\(CodableFeedStore.self)Queue", qos: .userInitiated, attributes: .concurrent)
    
    public init(storeURL: URL) {
        self.storeURL = storeURL
    }
}


extension CodableFeedStore: FeedStore {
    
    public func retrieve(completion: @escaping RetrievalCompletion) {
        let url = self.storeURL
        
        queue.async {
            guard let data = try? Data(contentsOf: url) else {
                return completion(.success(.none))
            }
            
            do {
                let decoder = JSONDecoder()
                let cache = try decoder.decode(Cache.self, from: data)
                completion(.success(CachedFeed(feed: cache.local, timestamp: cache.timestamp )))
            } catch let error {
                completion(.failure(error))
            }
        }
        
    }
    
    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        let url = self.storeURL
        queue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let cache = Cache.init(feed: feed.map(CodableFeedImage.init), timestamp: timestamp)
                let encode = try encoder.encode(cache)
                try encode.write(to: url)
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    public func delete(completion: @escaping DeletionCompletion) {
        let url = self.storeURL
        
        queue.async(flags: .barrier) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return completion(.success(()))
            }
            
            do {
                try FileManager.default.removeItem(at: url)
                completion(.success(()))
            } catch let error {
                completion(.failure(error))
                
            }
        }
        
    }
    
}
