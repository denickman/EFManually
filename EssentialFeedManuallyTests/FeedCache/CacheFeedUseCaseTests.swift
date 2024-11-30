//
//  CacheFeedUseCaseTests.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 28.11.2024.
//

import XCTest
import EssentialFeedManually

/*
 CacheFeedUseCaseTests: Эти тесты проверяют сохранение данных в кэш. Они фокусируются на:
 
 Удалении старого кэша перед вставкой новых данных.
 Корректной обработке ошибок при удалении или вставке.
 Проверке поведения при успешном или неудачном завершении операции сохранения.
 Убедиться, что ошибки удаления или вставки не доставляются после деинициализации sut.
 
 В CacheFeedUseCaseTests основное сообщение — .deleteCachedFeed и .insert, которые используются при удалении старого кэша и добавлении новых данных.
 
 В CacheFeedUseCaseTests акцент на том, что сохранение данных не должно продолжаться после ошибки удаления.
 */

class CacheFeedUseCaseTests: XCTestCase {
    
    func test_init_doesNotMessageStoreUponCreation() {
        let (store, _) = makeSUT()
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_save_requestCacheDeletion() {
        // delete upon adding new one
        let (store, sut) = makeSUT()
        sut.save(uniqueImagesFeed().models, completion: { _ in })
        XCTAssertEqual(store.receivedMessages, [.delete])
    }
    
    func test_save_doesNotRequestCacheInsertionOnDeletionError() {
        // deletion is not successfull
        let (store, sut) = makeSUT()
        let error = anyNSError()
        
        sut.save(uniqueImagesFeed().models, completion: { _ in })
        store.completeDeletion(with: error)
    }
    
    func test_save_requestsNewCacheInsertionWithTimestampOnSuccessfulDeletion() {
        // add feed to cache without error
        let timestamp = Date()
        let (store, sut) = makeSUT(currentDate: { timestamp })
        let feed = uniqueImagesFeed()
        
        sut.save(feed.models) { _ in }
        store.completeDeletionSuccessfully()
        
        XCTAssertEqual(store.receivedMessages, [.delete, .insert(feed.local, timestamp)])
    }
    
    func test_save_failsOnDeletionError() {
        // deletion is not successfull
        let (store, sut) = makeSUT()
        let deletionError = anyNSError()
        
        expect(sut, toCompleteWithError: deletionError) {
            store.completeDeletion(with: deletionError)
        }
    }
    
    func test_save_failsOnInsertionError() {
        // what happens when insert new cache
        
        let (store, sut) = makeSUT()
        let error = anyNSError()
        
        expect(sut, toCompleteWithError: error) {
            store.completeDeletionSuccessfully()
            store.completeInsertion(with: error)
        }
    }
    
    func test_save_succeedsOnSuccessfulCacheInsertion() {
        // delete + insert
        
        let (store, sut) = makeSUT()
        
        expect(sut, toCompleteWithError: nil) {
            store.completeDeletionSuccessfully()
            store.completeInsertionSuccessfully()
        }
    }
    
    func test_save_doesNotDeliverDeletionErrorAfterSUTIntanceHasBeenDeallocated() {
        
        let store = FeedStoreSpy()
        let timestamp = Date()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: { timestamp })
        
        var expectedError: NSError?
        
        sut?.save(uniqueImagesFeed().models) { result in
            if case .failure(let error) = result {
                expectedError = error as NSError
            }
        }
        
        sut = nil
        
        store.completeDeletion(with: anyNSError())
        
        XCTAssertNil(expectedError)
    }
    
    func test_save_doesNotDeliverInsertionErrorAfterSUTIntanceHasBeenDeallocated() {
        
        let store = FeedStoreSpy()
        let timestamp = Date()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: { timestamp })
        
        var expectedError: NSError?
        
        sut?.save(uniqueImagesFeed().models) { result in
            if case .failure(let error) = result {
                expectedError = error as NSError
            }
        }
        
        store.completeDeletionSuccessfully()
        
        sut = nil
        
        store.completeInsertion(with: anyNSError())
        
        XCTAssertNil(expectedError)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        currentDate: @escaping () -> Date = Date.init,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (FeedStoreSpy, LocalFeedLoader) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, currentDate: currentDate)
        trackForMemoryLeaks(store)
        trackForMemoryLeaks(sut)
        return (store, sut)
    }
    
    private func expect(
        _ sut: LocalFeedLoader,
        toCompleteWithError expectedError: NSError?,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for completion")
        
        var receivedError: Error?
        
        sut.save(uniqueImagesFeed().models) { result in
            if case let .failure(error) = result {
                receivedError = error
            }
            exp.fulfill()
        }
        
        action()
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(receivedError as NSError?, expectedError)
    }
}


