//
//  PostDataManager.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

final class PostDataManager {

    private let client: any NetworkClient

    init(client: any NetworkClient = NetworkManager()) {
        self.client = client
    }

    func fetchPosts() async throws -> Results {
        return try await client.request(PostEndpoint.frontPage)
    }
}
