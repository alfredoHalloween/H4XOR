//
//  PostViewModel.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

import Foundation
import Observation

@Observable
final class PostViewModel {
    
    var posts: [Post] = []
    private let dataManager = PostDataManager()
    
    func fetchPosts() async {
        let results = try? await dataManager.fetchPosts()
        if let results = results {
            posts.append(contentsOf: results.hits)
        }
    }
}
