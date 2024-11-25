//
//  FeedItemsMapper.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 25.11.2024.
//

import Foundation

final class FeedItemsMapper {
    
    private struct Root: Decodable {
        let items: [RemoteFeedItem]
    }
    
    private static var OK_200: Int { 200 }
    
    
    static func map(_ data: Data, response: HTTPURLResponse) throws -> [FeedImage] {
        guard response.statusCode == OK_200,
              let root = try? JSONDecoder().decode(Root.self, from: data) else {
            throw RemoteFeedLoader.Error.invalidData
        }
        
        return root.items.toModels()
    }
}

private extension Array where Element == RemoteFeedItem {
    func toModels() -> [FeedImage] {
        map {
            .init(id: $0.id, description: $0.description, location: $0.location, url: $0.image)
        }
    }
}
