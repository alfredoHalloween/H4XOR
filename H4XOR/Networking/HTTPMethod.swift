//
//  HTTPMethod.swift
//  H4XOR
//

/// Verbos HTTP soportados por `NetworkClient`.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
