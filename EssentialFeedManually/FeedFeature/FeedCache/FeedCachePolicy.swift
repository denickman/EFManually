//
//  FeedCachePolicy.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 28.11.2024.
//

import Foundation

final class FeedCachePolicy {
    
    private init() {}
    
    private static let calendar: Calendar = .init(identifier: .gregorian)
    private static var maxCacheAgeDays: Int { 7 }
    
    static func validate(_ timestamp: Date, against date: Date) -> Bool {
        guard let maxCacheAge = calendar.date(byAdding: .day, value: maxCacheAgeDays, to: timestamp) else {
            return false
        }
        
        return date < maxCacheAge
    }

}
