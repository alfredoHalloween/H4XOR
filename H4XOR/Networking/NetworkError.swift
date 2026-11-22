//
//  NetworkError.swift
//  H4XOR
//

import Foundation

/// Errores tipados de la capa de red.
///
/// Es `nonisolated` porque también se lanza desde `ResponseDecoder`, que corre fuera del main actor.
nonisolated enum NetworkError: Error {
    /// No se pudo construir una URL válida a partir del `Endpoint`.
    case invalidURL
    /// La respuesta no es una `HTTPURLResponse`.
    case invalidResponse
    /// El servidor respondió con un código fuera de `200..<300`.
    case httpStatus(code: Int, data: Data)
    /// No se pudo codificar el body como JSON.
    case encoding(any Error)
    /// No se pudo decodificar la respuesta.
    case decoding(any Error)
    /// Error de transporte de `URLSession` (sin conexión, timeout, ATS, etc.).
    case transport(any Error)
}
