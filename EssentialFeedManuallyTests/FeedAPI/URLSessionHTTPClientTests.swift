//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedManually
//
//  Created by Denis Yaremenko on 25.11.2024.
//

import XCTest
import EssentialFeedManually

class URLSessionHTTPClientTests: XCTestCase {
    
    override func setUp() {
        URLProtocolStub.startInterceptingRequests()
    }
    
    override func tearDown() {
        URLProtocolStub.stopInterceptingRequests()
    }
    
    func test_getFromURL_performGETRequestWithURL() {
        // perform only get request with url
        
        let url = anyURL()
        let exp = expectation(description: "Wait for response")
        
        URLProtocolStub.observeRequest { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
        }
        
        makeSUT().get(from: url) { result in
            exp.fulfill()
        }
        
        wait(for: [exp])
    }

    func test_getFromURL_failsOnRequestError() {
        let requestedError = anyNSError()
        let receivedError = resultForError(data: nil, response: nil, error: requestedError) as? NSError
        
        XCTAssertEqual(requestedError.code, receivedError?.code)
        XCTAssertEqual(requestedError.domain, receivedError?.domain)
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() {
        XCTAssertNotNil(resultForError(data: nil, response: nil, error: nil))
        XCTAssertNotNil(resultForError(data: nil, response: makeNonHttpResponse(), error: nil))
        XCTAssertNotNil(resultForError(data: anyData(), response: nil, error: anyNSError()))
        XCTAssertNotNil(resultForError(data: nil, response: makeNonHttpResponse(), error: anyNSError()))
        XCTAssertNotNil(resultForError(data: nil, response: makeHttpResponse(), error: anyNSError()))
        XCTAssertNotNil(resultForError(data: anyData(), response: makeNonHttpResponse(), error: anyNSError()))
        XCTAssertNotNil(resultForError(data: anyData(), response: makeNonHttpResponse(), error: nil))
    }

    func test_getFromURL_failsOnAllNilValues() {
        // stub is all nil
        URLProtocolStub.stub(data: nil, response: nil, error: nil)
        let exp = expectation(description: "Wait for response")

        makeSUT().get(from: anyURL()) { result in
            switch result {
            case .failure: break
                
            default:
                XCTFail("Expected error but got \(result) instead")
            }
            exp.fulfill()
        }
        
        wait(for: [exp])
    }

    func test_getFromURL_succeedsOnHTTPURLResponseWithData() {
        // data - yep, response - yep, error - nil, not stubs
        
        let data = anyData()
        let response = makeHttpResponse()
        
        let receivedValues = resultForValue(data: data, response: response, error: nil)
        
        XCTAssertEqual(receivedValues?.data, data)
        XCTAssertEqual(receivedValues?.response.url, response.url)
        XCTAssertEqual(receivedValues?.response.statusCode, response.statusCode)
    }

    func test_getFromURL_succeedsWithEmptyDataOnHTTPURLResponseWithNilData() {
        // data = nil, error - nil,
        let response = makeHttpResponse()
        
        let receivedValues = resultForValue(data: nil, response: response, error: nil)
        
        let emptyData = Data()
        
        XCTAssertEqual(receivedValues?.data, emptyData)
        XCTAssertEqual(receivedValues?.response.url, response.url)
        XCTAssertEqual(receivedValues?.response.statusCode, response.statusCode)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> HTTPClient {
        let client = URLSessionHTTPClient()
        trackForMemoryLeaks(client)
        return client
    }
    
    private func makeHttpResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    
    private func makeNonHttpResponse() -> URLResponse {
        URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    private func resultFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> HTTPClient.Result {
        URLProtocolStub.stub(data: data, response: response, error: error)
        let sut = makeSUT()
        let exp = expectation(description: "Wait for completion")
        var receivedResults: HTTPClient.Result!
        
        sut.get(from: anyURL()) { result in
            receivedResults = result
            exp.fulfill()
        }

        wait(for: [exp])
        return receivedResults
    }
    
    private func resultForValue(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (data: Data, response: HTTPURLResponse)? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)
        
        switch result {
        case .success(let data, let response):
            return (data, response)
            
        default:
            XCTFail("Expected success, got \(result) instead", file: file, line: line)
            return nil
        }
    }
    
    private func resultForError(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Error? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)
        switch result {
        case .failure(let error):
            return error
            
        default:
            XCTFail("Expected failure, got \(result) instead", file: file, line: line)
            return nil
        }
    }
    
    // MARK: - URLProtocolStub
    
    private class URLProtocolStub: URLProtocol {

        private struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }
        
        private static var stub: Stub?
        private static var requestObserver: ((URLRequest) -> Void)?

        static func startInterceptingRequests() {
            URLProtocol.registerClass(URLProtocolStub.self)
        }
        
        static func stopInterceptingRequests() {
            URLProtocolStub.registerClass(URLProtocolStub.self)
            stub = nil
            requestObserver = nil
        }
        
        static func stub(data: Data?, response: URLResponse?, error: Error?) {
            stub = .init(data: data, response: response, error: error)
        }
        
        static func observeRequest(completion: @escaping (URLRequest) -> Void) {
            requestObserver = completion
        }
        
        // MARK: - URLProtocol
        
        override static func canInit(with request: URLRequest) -> Bool {
            true
        }
        
        override static func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }
        
        override func startLoading() {
            if let requestObserver = URLProtocolStub.requestObserver {
                client?.urlProtocolDidFinishLoading(self)
                return requestObserver(request)
            }
            
            if let data = URLProtocolStub.stub?.data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let response = URLProtocolStub.stub?.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let error = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
            
            client?.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
            
        }
    }
    
    
}


