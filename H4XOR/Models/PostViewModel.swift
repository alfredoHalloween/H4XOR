//
//  PostViewModel.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

import Foundation
import Observation

/// Estado de la carga de posts.
enum LoadState: Equatable {
    case idle
    case loading
    case loaded([Post])
    case failed(message: String)
}

@Observable
final class PostViewModel {

    private(set) var state: LoadState = .idle

    private let dataManager: PostDataManager

    init(dataManager: PostDataManager = PostDataManager()) {
        self.dataManager = dataManager
    }

    /// Carga la portada. Los posts viajan dentro de `.loaded`, así que cada carga
    /// reemplaza los anteriores y reintentar no duplica resultados.
    func fetchPosts() async {
        state = .loading
        do {
            let results = try await dataManager.fetchPosts()
            state = .loaded(results.hits)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
