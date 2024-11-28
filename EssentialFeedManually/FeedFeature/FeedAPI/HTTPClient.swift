//
//  HTTPClient.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 25.11.2024.
//

import Foundation

public protocol HTTPClient {
    typealias Result = Swift.Result<(Data, HTTPURLResponse), Error>
    func get(from url: URL, completion: @escaping (Result) -> Void)
}
