//
//  NetworkManager.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

import Foundation

final class NetworkManager {
    
    func fetchData<T: Decodable>(url: String) async throws -> T {
        guard let url = URL(string: url) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(T.self, from: data)
        return result
    }
    /*
    
    @Published var posts: [Post] = []
    
    func fetchData() {
        if let url = URL(string: "http://hn.algolia.com/api/v1/search?tags=front_page") {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let data = data,
                      let response = response as? HTTPURLResponse,
                      response.statusCode >= 200 && response.statusCode < 300 else {
                    return
                }
                do {
                    let results = try JSONDecoder().decode(Results.self, from: data)
                    DispatchQueue.main.async {
                        self?.posts = results.hits
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
            .resume()
        }
    }
     */
    
}
