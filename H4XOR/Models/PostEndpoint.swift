//
//  PostEndpoint.swift
//  H4XOR
//

import Foundation

/// Endpoints de la API de Algolia HN.
enum PostEndpoint: Endpoint {
    case frontPage

    var baseURL: String { "https://hn.algolia.com" }

    var path: String {
        switch self {
        case .frontPage: "/api/v1/search"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .frontPage: [URLQueryItem(name: "tags", value: "front_page")]
        }
    }
}
