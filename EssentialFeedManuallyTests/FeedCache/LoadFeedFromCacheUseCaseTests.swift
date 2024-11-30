//
//  LoadFeedFromCacheUseCaseTests.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 30.11.2024.
//

import XCTest
import EssentialFeedManually

/*
 LoadFeedFromCacheUseCaseTests: Эти тесты проверяют функциональность загрузки кэша. Они ориентированы на следующие аспекты:
 
 Как LocalFeedLoader ведет себя при попытке загрузки данных из кэша.
 Корректность возврата данных при различных сценариях: ошибки, пустой кэш, данные из кэша.
 Проверка поведения при работе с истекшим или неистекшим кэшем.
 Проверка отсутствия побочных эффектов (например, данных не удаляются во время загрузки).
 
 
 В LoadFeedFromCacheUseCaseTests акцент на том, что загрузка не должна влиять на данные в хранилище (нет удаления кэша при загрузке).
 */

final class LoadFeedFromCacheUseCaseTests: XCTestCase {
    
    func test_init_doesNotMessageStoreUponCreation() {
        // just check receivedMessages count in spy
        let (store, _) = makeSUT()
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_load_requestCacheRetrieval() {
        // retrive the cache
        let (store, sut) = makeSUT()
        
        sut.load() { _ in }
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_failsOnRetrievalError() {
        // check .failure case in sut load method
        let (store, sut) = makeSUT()
        
        let error = anyNSError()
        
        expect(sut, toExpectedResults: .failure(error)) {
            store.completeRetrieval(with: error)
        }
    }
    
    func test_load_deliversNoImagesOnEmptyCache() {
        let (store, sut) = makeSUT()
        
        expect(sut, toExpectedResults: .success([])) {
            store.completeRetrievalWithEmptyCache()
        }
    }
    
    func test_load_deliversCachedImagesOnNonExpiredCache() {
          // validate the cache is less then 7 days old?
        
        let timestamp = Date()
        let (store, sut) = makeSUT(currentDate: { timestamp })
        let feed = uniqueImagesFeed()
        let nonExpiredTimestamp = timestamp.minusFeedCacheAge().adding(seconds: 1)
        
        expect(sut, toExpectedResults: .success(feed.models)) {
            store.completeRetrievalWithFeed(with: feed.local, timestamp: nonExpiredTimestamp)
        }   
    }
    
    func test_load_deliversNoImagesImagesOnCacheExpiration() {
        // expired existed cache
        
        let feed = uniqueImagesFeed()
        let timestamp = Date()
        let (store, sut) = makeSUT(currentDate: { timestamp })
        let nonExpiredTimestamp = timestamp.minusFeedCacheAge()
        
        expect(sut, toExpectedResults: .success([])) {
            store.completeRetrievalWithFeed(with: feed.local, timestamp: nonExpiredTimestamp)
        }
    }
    
    func test_load_deliversNoImagesImagesOnExpiredCache() {
        // expired cache - no images on more then 7 days old cache
        
        let feed = uniqueImagesFeed()
        let fixedCurrentDate = Date()
        let expiredTimestamp = fixedCurrentDate.minusFeedCacheAge().adding(seconds: -1)
        
        let (store, sut) = makeSUT(currentDate: { fixedCurrentDate })

        expect(sut, toExpectedResults: .success([])) {
            store.completeRetrievalWithFeed(with: feed.local, timestamp: expiredTimestamp)
        }
    }
    
    func test_load_hasNoSideEffectsOnRetrievalError() {
        // when load feed we do not delete a cache (no side effects but got error)

        let (store, sut) = makeSUT()
        
        sut.load { _ in }
        
        store.completeRetrieval(with: anyNSError())
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsOnEmptyCache() {
        // with no side effects
        // if cache is not invalid it should not be deleted
        let (store, sut) = makeSUT()
        
        sut.load { _ in }
        
        store.completeRetrievalWithEmptyCache()
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsOnNonExpiredCache() {
        // no side effects
        // do not delete cache if it less than 7 days old
        let (store, sut) = makeSUT()
        
        let feed = uniqueImagesFeed()
        let fixedCurrentDate = Date()
        let nonExpiredTimestamp = fixedCurrentDate.minusFeedCacheAge().adding(seconds: 1)
        
        sut.load { _ in }
        store.completeRetrievalWithFeed(with: feed.local, timestamp: nonExpiredTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsOnCacheExpiration() {
        // no side effects
        // when get items from cache it should delete cache if more than 7 days old
        let (store, sut) = makeSUT()
        
        let feed = uniqueImagesFeed()
        let fixedCurrentDate = Date()
        let expirationTimestamp = fixedCurrentDate.minusFeedCacheAge()
        
        sut.load { _ in }
        store.completeRetrievalWithFeed(with: feed.local, timestamp: expirationTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsOnExpiredCache() {
        // no side effects
        // when get items from cache it should delete cache if more than 7 days old
        let (store, sut) = makeSUT()
        
        let feed = uniqueImagesFeed()
        let fixedCurrentDate = Date()
        let expiredTimestamp = fixedCurrentDate.minusFeedCacheAge().adding(seconds: -1)
        
        sut.load { _ in }
        store.completeRetrievalWithFeed(with: feed.local, timestamp: expiredTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_doesNotDeliverResultAfterSUTInstanceHasBeenDeallocated() {
        // sut is nil
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: Date.init)
        var receivedResults = [FeedLoader.Result]()
        
        sut?.load { receivedResults.append($0) }
        sut = nil
        store.completeRetrievalWithEmptyCache()
        
        XCTAssertTrue(receivedResults.isEmpty)
    }
    
  
    // MARK: - Helpers
    
    
    private func makeSUT(
        currentDate: @escaping () -> Date = Date.init,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (store: FeedStoreSpy, sut: LocalFeedLoader) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, currentDate: currentDate)
        
        trackForMemoryLeaks(store)
        trackForMemoryLeaks(sut)
        
        return (store, sut)
    }
    
    private func expect(
        _ sut: LocalFeedLoader,
        toExpectedResults expected: FeedLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for it")
        
        sut.load { received in
            switch (expected, received) {
            case let (.success(expectedFeed), .success(receivedFeed)):
                XCTAssertEqual(expectedFeed, receivedFeed, file: file, line: line)
                
            case let (.failure(expectedFailure), .failure(receivedFailure)):
                XCTAssertEqual(expectedFailure as NSError, receivedFailure as NSError, file: file, line: line)
                
            default:
                XCTFail("Expected \(expected), received \(received) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        
        action()
        
        waitForExpectations(timeout: 1.0)
    }
    
}
