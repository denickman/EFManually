//
//  CodableFeedStoreTests.swift
//  EssentialFeedManuallyTests
//
//  Created by Denis Yaremenko on 26.11.2024.
//

import XCTest
import EssentialFeedManually

/// CodableFeedStoreTests - Test of CodableFeedStore directly

final class CodableFeedStoreTests: XCTestCase, FailableFeedStoreSpecs {
    
    override func setUp() {
        setupEmptyStoreState()
    }
    
    override func tearDown() {
        undoStoreSideEffects()
    }
    
    func test_retrieve_deliversEmptyOnEmptyCache() {
        // retrieve an empty cache (no side effects)
        let sut = makeSUT()
        expect(sut, toRetrieve: .success(.none))
    }
    
    func test_retrieve_hasNoSideEffectsOnEmptyCache() {
        // retrieve an empty cache twice (no side effects)
        let sut = makeSUT()
        expect(sut, toRetrieveTwice: .success(.none))
    }
    
    func test_retrieve_deliversFoundValuesOnNonEmptyCache() {
        // insert to empty cache a new image feed with timestamp and retrive only one time
        let sut = makeSUT()
        let feed = uniqueImagesFeed().local
        let timestamp = Date()
        
        insert((feed, timestamp), to: sut)
        
        expect(sut, toRetrieve: .success(CachedFeed(feed: feed, timestamp: timestamp)))
    }
    
    func test_retrieve_hasNoSideEffectsOnNonEmptyCache() {
        // insert to empty cache a new image feed with timestamp but retrieve twicely
        
        let sut = makeSUT()
        
        let feed = uniqueImagesFeed().local
        let timestamp = Date()
        
        insert((feed, timestamp), to: sut)
        expect(sut, toRetrieveTwice: .success(CachedFeed(feed: feed, timestamp: timestamp)))
    }
    
    func test_retrieve_deliversFailureOnRetrievalError() {
        // test if data is invalid "invalid data"
        let storeURL = testSpecificStoreURL()
        let sut = makeSUT(url: storeURL)
        
        try! "invalid data".write(to: storeURL, atomically: false, encoding: .utf8)
        expect(sut, toRetrieve: .failure(anyNSError()))
    }
    
    func test_retrieve_hasNoSideEffectsOnFailure() {
        // test if data is invalid "invalid data" but retrieve twicely
        let storeURL = testSpecificStoreURL()
        let sut = makeSUT(url: storeURL)
        try! "invalid data".write(to: storeURL, atomically: false, encoding: .utf8)
        expect(sut, toRetrieveTwice: .failure(anyNSError()))
    }
    
    func test_insert_deliversNoErrorOnEmptyCache() {
        // insert data successfully without error
        let sut = makeSUT()
        let insertionError = insert((uniqueImagesFeed().local, Date()), to: sut)
        XCTAssertNil(insertionError, "Expected to insert cache succwssfully")
    }
    
    func test_insert_deliversNoErrorOnNonEmptyCache() {
        // add cache then override it with a new cahce
        let sut = makeSUT()
        insert((uniqueImagesFeed().local, Date()), to: sut)
        
        let insertionError = insert((uniqueImagesFeed().local, Date()), to: sut)
        
        XCTAssertNil(insertionError, "Expected to override cache successfully")
    }
    
    func test_insert_overridesPreviouslyInsertedCacheValues() {
        // add one feed, then add another feed
        let sut = makeSUT()
        
        insert((uniqueImagesFeed().local, Date()), to: sut)
        
        let latestFeed = uniqueImagesFeed().local
        let latestDate = Date()
        
        insert((latestFeed, latestDate), to: sut)
        
        expect(sut, toRetrieve: .success(CachedFeed(feed: latestFeed, timestamp: latestDate)))
    }
    
    func test_insert_deliversErrorOnInsertionError() {
        // try to save feed to invalid url
        
        let invalidStoreURL = URL(string: "invalid://store-url")!
        let sut = makeSUT(url: invalidStoreURL)
        let feed = uniqueImagesFeed().local
        let timestamp = Date()
        
        let insertionError = insert((feed, timestamp), to: sut)
        XCTAssertNotNil(insertionError, "Expected cache insertion to fail with an error")
    }
    
    func test_insert_hasNoSideEffectsOnInsertionError() {
        // no side effect when add new feed into wrong url
        
        let invalidStoreURL = URL(string: "invalid://store-url")!
        let sut = makeSUT(url: invalidStoreURL)
        let feed = uniqueImagesFeed().local
        let timestamp = Date()
        
        insert((feed, timestamp), to: sut)
        expect(sut, toRetrieve: .success(.none))
    }
    
    func test_delete_hasNoSideEffectsOnEmptyCache() {
        // delete from cache with no error completion
        let sut = makeSUT()
        deleteCache(from: sut)
        expect(sut, toRetrieve: .success(.none))
    }
    
    func test_delete_deliversNoErrorOnEmptyCache() {
        // non emtpy cache but after delete no error occurs
        let sut = makeSUT()
        let deletionError = deleteCache(from: sut)
        XCTAssertNil(deletionError, "Expected empty cache deletion to success")
    }
    
    func test_delete_deliversNoErrorOnNonEmptyCache() {
        // insert to cache and then delete it without errors
        
        let sut = makeSUT()
        insert((uniqueImagesFeed().local, Date()), to: sut)
        
        let deletionCache = deleteCache(from: sut)
        XCTAssertNil(deletionCache, "Expectd non-empty cache deletion to succeed")
    }
    
    func test_delete_emptiesPreviouslyInsertedCache() {
        // add cache, delete cache, retrive success with none
        let sut = makeSUT()
        insert((uniqueImagesFeed().local, Date()), to: sut)
        
        deleteCache(from: sut)
        
        expect(sut, toRetrieve: .success(.none))
    }
    
    func test_delete_deliversErrorOnDeletionError() {
        // try to delete on cachesdirectory and get fail
        let noDeletePermissionsURL = cachesDirectory()
        let sut = makeSUT(url: noDeletePermissionsURL)
        
        let deletionError = deleteCache(from: sut)
        XCTAssertNotNil(deletionError, "Expected cache deletion to fail")
    }
    
    func test_delete_hasNoSideEffectsOnDeletionError() {
        // delete cache and retrieve success with none
        let noDeletePermissionURL = cachesDirectory()
        let sut = makeSUT(url: noDeletePermissionURL)
        
        deleteCache(from: sut)
        
        expect(sut, toRetrieve: .success(.none))
    }
    
    func test_storeSideEffects_runSerially() {
        
        let sut = makeSUT()
        var completedExpectations = [XCTestExpectation]()
        
        let ex1 = expectation(description: "Wait for insertion 1")
        sut.insert(uniqueImagesFeed().local, timestamp: Date()) { _ in
            completedExpectations.append(ex1)
            ex1.fulfill()
        }
        
        let ex2 = expectation(description: "Wait for deletion")
        sut.delete { _ in
            completedExpectations.append(ex2)
            ex2.fulfill()
        }
        
        let ex3 = expectation(description: "Wait for insertion 2")
        sut.insert(uniqueImagesFeed().local, timestamp: Date()) { _ in
            completedExpectations.append(ex3)
            ex3.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertEqual(completedExpectations, [ex1, ex2, ex3], "Expected side-effects to run serially but operations finished in the wrong order")
        
    }
    
    // MARK: - Helpers
    
    func makeSUT(url: URL? = nil, file: StaticString = #filePath, line: UInt = #line) -> FeedStore {
        let sut = CodableFeedStore(storeURL: url ?? testSpecificStoreURL())
        trackForMemoryLeaks(sut)
        return sut
    }
    
    private func testSpecificStoreURL() -> URL {
        return cachesDirectory().appendingPathComponent("\(type(of: self)).store")
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func setupEmptyStoreState() {
        deleteStoreArtifacts()
    }
    
    private func undoStoreSideEffects() {
        deleteStoreArtifacts()
    }
    
    private func deleteStoreArtifacts() {
        try? FileManager.default.removeItem(at: testSpecificStoreURL())
    }
    
}

// MARK: - Helpers

extension FeedStoreSpecs where Self: XCTestCase {
    
    func expect(
        _ sut: FeedStore,
        toRetrieveTwice expectedResult: FeedStore.RetrievalResult,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        expect(sut, toRetrieve: expectedResult, file: file, line: line)
        expect(sut, toRetrieve: expectedResult, file: file, line: line)
    }
    
    func expect(
        _ sut: FeedStore,
        toRetrieve expectedResult: FeedStore.RetrievalResult,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for cache retrieval")
        
        sut.retrieve { retrieveResult in
            switch (retrieveResult, expectedResult) {
            case (.success(.none), .success(.none)),
                (.failure, .failure):
                break
                
            case let (.success(.some(expected)), .success(.some(retrieved))):
                XCTAssertEqual(retrieved.feed, expected.feed, file: file, line: line)
                XCTAssertEqual(retrieved.timestamp, expected.timestamp, file: file, line: line)
                
            default:
                XCTFail("Expected to retrieve \(expectedResult), got \(retrieveResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    @discardableResult
    func insert(_ cache: (feed: [LocalFeedImage], timestamp: Date), to sut: FeedStore) -> Error? {
        let exp = expectation(description: "Wait for cache insertion")
        var insertionError: Error?
        
        sut.insert(cache.feed, timestamp: cache.timestamp) { result in
            switch result {
            case .failure(let error):
                insertionError = error
                
            default: ()
                
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        return insertionError
    }
    
    @discardableResult
    func deleteCache(from sut: FeedStore) -> Error? {
        let exp = expectation(description: "Wait for cache deletion")
        
        var deletionError: Error?
        
        sut.delete { result in
            switch result {
            case .failure(let error):
                deletionError = error
                
            default:
                ()
            }
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        return deletionError
    }
}
