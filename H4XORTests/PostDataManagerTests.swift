//
//  PostDataManagerTests.swift
//  H4XORTests
//

import Foundation
import Testing
@testable import H4XOR

struct PostDataManagerTests {

    @Test func fetchesFrontPageThroughTheClient() async throws {
        let client = try MockNetworkClient(response: Results.dummy)
        let manager = PostDataManager(client: client)

        let results = try await manager.fetchPosts()

        #expect(results.hits == Post.dummies)
        let request = try #require(client.receivedRequests.first)
        #expect(client.receivedRequests.count == 1)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://hn.algolia.com/api/v1/search?tags=front_page")
    }
}
