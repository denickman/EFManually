//
//  FeedLoader.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 25.11.2024.
//
 
/// <FeedLoader>

public protocol FeedLoader {
    typealias Result = Swift.Result<[FeedImage], Error>
    func load(completion: @escaping (Result) -> Void)
}
