//
//  MockNetworkClientTests.swift
//  H4XORTests
//

import Foundation
import Testing
@testable import H4XOR

private struct DeleteItemEndpoint: Endpoint {
    let baseURL = "https://api.example.com"
    let path = "/items/1"
    let method: HTTPMethod = .delete
}

struct MockNetworkClientTests {

    @Test func respondsWithJSONString() async throws {
        let client = MockNetworkClient(json: #"{ "hits": [ { "objectID": "9", "points": 1, "title": "Desde string", "url": null } ] }"#)

        let results: Results = try await client.request(PostEndpoint.frontPage)

        #expect(results.hits.map(\.objectID) == ["9"])
    }

    @Test func respondsWithBundledJSONFile() async throws {
        let client = try MockNetworkClient(jsonFile: "front_page")

        let results: Results = try await client.request(PostEndpoint.frontPage)

        #expect(results.hits.count == 3)
        #expect(results.hits.first?.objectID == "40000001")
    }

    @Test func respondsWithDummyObject() async throws {
        let client = try MockNetworkClient(response: Results.dummy)

        let results: Results = try await client.request(PostEndpoint.frontPage)

        #expect(results.hits == Post.dummies)
    }

    @Test func respondMethodsReplaceTheResponse() async throws {
        let client = MockNetworkClient(json: #"{ "hits": [] }"#)
        try client.respond(with: Results.dummy)

        let results: Results = try await client.request(PostEndpoint.frontPage)

        #expect(results.hits == Post.dummies)
    }

    @Test func missingJSONFileThrowsFileNotFound() {
        #expect(throws: MockNetworkClient.MockDataError.self) {
            try MockNetworkClient(jsonFile: "no_existe")
        }
    }

    @Test func configuredErrorIsThrownAndRequestIsRecorded() async {
        let client = MockNetworkClient(error: .httpStatus(code: 500, data: Data()))

        do {
            let _: Results = try await client.request(PostEndpoint.frontPage)
            Issue.record("Se esperaba un error")
        } catch {
            guard case .httpStatus(500, _)? = error as? NetworkError else {
                Issue.record("Se esperaba .httpStatus(500) y llegó \(error)")
                return
            }
        }
        #expect(client.receivedRequests.count == 1)
    }

    @Test func noContentRequestIsRecorded() async throws {
        let client = MockNetworkClient()

        try await client.request(DeleteItemEndpoint())

        let request = try #require(client.receivedRequests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://api.example.com/items/1")
    }
}
