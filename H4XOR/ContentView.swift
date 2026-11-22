//
//  ContentView.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

import SwiftUI
import Observation

struct ContentView: View {
    
    @State private var viewModel = PostViewModel()
    
    var body: some View {
        NavigationView {
            List(loadedPosts) { post in
                HStack {
                    Text(String(post.points))
                    Text(post.title)
                }
            }
            .navigationTitle("H4XOR News")
        }
        .task {
            await viewModel.fetchPosts()
        }
    }

    // Puente temporal hasta el Paso 6, donde la vista hace `switch` sobre `viewModel.state`.
    private var loadedPosts: [Post] {
        if case .loaded(let posts) = viewModel.state { posts } else { [] }
    }
}

#Preview {
    ContentView()
}
