//
//  FeedStore.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 26.11.2024.
//

import Foundation

public typealias CachedFeed = (feed: [LocalFeedImage], timestamp: Date)

public protocol FeedStore {

    typealias RetrievalResult = Result<CachedFeed?, Error>
    typealias InsertionResult = Result<Void, Error>
    typealias DeletionResult = Result<Void, Error>
    
    func retrieve(completion: @escaping (RetrievalResult) -> Void)
    func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping (InsertionResult) -> Void)
    func delete(completion: @escaping (DeletionResult) -> Void)
}
