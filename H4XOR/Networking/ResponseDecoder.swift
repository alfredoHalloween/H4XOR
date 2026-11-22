//
//  ResponseDecoder.swift
//  H4XOR
//

import Foundation

/// Decodifica respuestas de red fuera del main actor.
///
/// `decode` está marcado `@concurrent`, así que siempre se ejecuta en el pool de hilos global
/// aunque se llame desde el main actor. Los tipos decodificados deben ser `nonisolated` y `Sendable`.
nonisolated struct ResponseDecoder: Sendable {
    let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    @concurrent
    func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws(NetworkError) -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decoding(error)
        }
    }
}
