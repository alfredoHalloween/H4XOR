//
//  PostDataManager.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

final class PostDataManager {
    
    private let networkManager = NetworkManager()
    
    func fetchPosts() async throws -> Results {
        return try await networkManager.fetchData(url: "http://hn.algolia.com/api/v1/search?tags=front_page")
    }
}
