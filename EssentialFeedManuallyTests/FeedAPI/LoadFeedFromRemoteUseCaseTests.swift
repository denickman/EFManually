//
//  LoadFeedFromRemoteUseCaseTests.swift
//  LoadFeedFromRemoteUseCaseTests
//
//  Created by Denis Yaremenko on 25.11.2024.
//

import XCTest
@testable import EssentialFeedManually

final class LoadFeedFromRemoteUseCaseTests: XCTestCase {
    
    func test_init_doesNotReqeustDataFromURL() {
        // requested urls is empty
        let (client, sut) = makeSUT()
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestDataFromURL() {
        // at least 1 url exist
        
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(url: url)
        
        sut.load { _ in }
         
        XCTAssertEqual(client.requestedURLs, [url])
        XCTAssertFalse(client.requestedURLs.isEmpty)
    }
    
    func test_loadTwice_requestDataFromURLTwice() {
        // twice loading the same url
        
        let url = URL(string: "https://a-given-url.com")!
        
        let (client, sut) = makeSUT(url: url)
        
        sut.load { _ in }
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url, url])
    }
    
    func test_load_deliversErrorOnClientError() {
        // fails with connectivity issue
        
        let (client, sut) = makeSUT()
        
        expect(sut, toCompleteWithResult: failure(.connectivity)) {
            let error = NSError.init(domain: "error", code: 0)
            client.complete(with: error)
        }
    }
    
    func test_load_deliversErrorOnNon200HTTPResponse() {
        // check 199, 201, 300, 400, 500 statuses
        
        let statuses = [199, 201, 300, 400, 500]
        
        let (client, sut) = makeSUT()
        
        statuses.enumerated().forEach { index, statusCode in
            expect(sut, toCompleteWithResult: failure(.invalidData)) {
                let data = makeDataFromItems([])
                client.complete(withStatusCode: statusCode, data: data, at: index)
            }
        }
    }

    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() {
         // response 200 but invalid data
        let (client, sut) = makeSUT()
        expect(sut, toCompleteWithResult: failure(.invalidData)) {
            let invalidJson = Data("invalidJson".utf8)
            client.complete(withStatusCode: 200, data: invalidJson)
        }
    }
    
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyList() {
        // response 200 but emtpy json
        
        let (client, sut) = makeSUT()
        
        expect(sut, toCompleteWithResult: .success([])) {
            let emptyData = makeDataFromItems([])
            client.complete(withStatusCode: 200, data: emptyData)
        }
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() {
        // happy path
        let (client, sut) = makeSUT()
        
        let item1 = makeItem(id: UUID(), imageURL: URL(string: "https://a-url.com")!)
        let item2 = makeItem(id: UUID(), description: "description", location: "location", imageURL: URL(string: "https://another-url.com")!)
        
        let items = [item1.json, item2.json]
        
        let data = makeDataFromItems(items)
        
        expect(sut, toCompleteWithResult: .success([item1.model, item2.model])) {
            client.complete(withStatusCode: 200, data: data)
        }
    }
    
    func test_load_doesNotDeliverResultAfterSUTInstanceHasBeenDeallocated() {
        // sut is nil
        
        let client = HTTPClientSpy()
        let url = URL(string: "https://a-url.com")!
        var sut:RemoteFeedLoader? = RemoteFeedLoader(url: url, client: client)
        
        var receivedResults = [FeedLoader.Result]()
        
        sut?.load { result in
            receivedResults.append(result)
        }
        
        sut = nil
        
        client.complete(withStatusCode: 200, data: Data())
        
        XCTAssertTrue(receivedResults.isEmpty, "Received results array is not emtpy")
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        url: URL = URL(string: "https://any-url.com")!,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (client: HTTPClientSpy, sut: RemoteFeedLoader) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        trackForMemoryLeaks(client)
        trackForMemoryLeaks(sut)
        return (client, sut)
    }
    
    private func expect(
        _ sut: RemoteFeedLoader,
        toCompleteWithResult expected: RemoteFeedLoader.Result,
        action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line) {
            let exp = expectation(description: "Wait for load completion")
            
            sut.load { received in
                switch (expected, received) {
                case let (.success(expValue), .success(recValue)):
                    XCTAssertEqual(expValue, recValue, file: file, line: line)
                    
                case let (.failure(expFailure as RemoteFeedLoader.Error), .failure(recValue as RemoteFeedLoader.Error)):
                    XCTAssertEqual(expFailure, recValue, file: file, line: line)
                    
                default:
                    XCTFail("Expected result \(expected) got \(received) instead", file: file, line: line)
                }
                exp.fulfill()
            }
            
            action()
            wait(for: [exp], timeout: 1.0)
        }
    
    private func makeItem(
        id: UUID,
        description: String? = nil,
        location: String? = nil,
        imageURL: URL
    ) -> (model: FeedImage, json: [String: Any]) {
        
        let model = FeedImage.init(id: id, description: description, location: location, url: imageURL)
        
        let json = [
            "id" : id.uuidString,
            "description" : description,
            "location" : location,
            "image" : imageURL.absoluteString
        ].compactMapValues { $0 }
        
        return (model, json)
    }
    
    private func makeDataFromItems(_ items: [[String: Any]]) -> Data {
        let json = ["items" : items]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return data
    }
    
    private func failure(_ error: RemoteFeedLoader.Error) -> FeedLoader.Result {
        .failure(error)
    }
    
    // MARK: - Spy
    
    private class HTTPClientSpy: HTTPClient {
        
        var requestedURLs: [URL] {
            messages.map { $0.url }
        }
        
        private var messages = [(url: URL, completion: (HTTPClient.Result) -> Void)]()
        
        func complete(withStatusCode code: Int, data: Data, at index: Int = 0) {
            
            let response = HTTPURLResponse(
                url: requestedURLs[index],
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            
            messages[index].completion(.success((data, response)))
        }
        
        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
            messages.append((url, completion))
        }
    }
    
}
