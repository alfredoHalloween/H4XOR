//
//  ResponseDecoderTests.swift
//  H4XORTests
//

import Foundation
import Testing
@testable import H4XOR

/// Registra en qué hilo se ejecuta su `init(from:)`.
nonisolated struct DecodingThreadProbe: Decodable, Sendable {
    let decodedOnMainThread: Bool

    init(from decoder: any Decoder) throws {
        decodedOnMainThread = Thread.isMainThread
    }
}

struct ResponseDecoderTests {

    @Test func decodesValidJSON() async throws {
        let json = #"{ "hits": [ { "objectID": "1", "points": 10, "title": "Hola", "url": null } ] }"#

        let results = try await ResponseDecoder().decode(Results.self, from: Data(json.utf8))

        #expect(results.hits.count == 1)
        #expect(results.hits.first?.title == "Hola")
        #expect(results.hits.first?.url == nil)
    }

    @Test func invalidJSONThrowsDecodingError() async {
        do {
            _ = try await ResponseDecoder().decode(Results.self, from: Data("no es json".utf8))
            Issue.record("Se esperaba NetworkError.decoding")
        } catch {
            guard case .decoding = error else {
                Issue.record("Se esperaba .decoding y llegó \(error)")
                return
            }
        }
    }

    @MainActor
    @Test func decodesOffTheMainThreadEvenWhenCalledFromMainActor() async throws {
        MainActor.assertIsolated()

        let probe = try await ResponseDecoder().decode(DecodingThreadProbe.self, from: Data("{}".utf8))

        #expect(probe.decodedOnMainThread == false)
    }
}
