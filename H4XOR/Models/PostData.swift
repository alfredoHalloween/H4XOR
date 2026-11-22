//
//  PostData.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

import Foundation

nonisolated struct Results: Decodable, Sendable {
    let hits: [Post]
}

nonisolated struct Post: Decodable, Identifiable, Sendable {
    var id: String {
        return objectID
    }
    let objectID: String
    let points: Int
    let title: String
    let url: String?
}
