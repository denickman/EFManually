//
//  URLSessionHTTPClient.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 25.11.2024.
//

import Foundation

public class URLSessionHTTPClient: HTTPClient {
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    private struct UnexpectedError: Error {}
    
    public func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
        
        session.dataTask(with: url) { data, response, error in
            
//            if let data = data, let response = response as? HTTPURLResponse {
//                completion(.success((data, response)))
//            } else if let error = error {
//                completion(.failure(error))
//            } else {
//                completion(.failure(UnexpectedError()))
//            }
   
            completion(Result(catching: {
                if let data = data, let response = response as? HTTPURLResponse {
                    return (data, response)
                } else if let error = error {
                    throw error
                } else {
                    throw UnexpectedError()
                }
            }))
        }
        .resume()
    }
    
    
}
