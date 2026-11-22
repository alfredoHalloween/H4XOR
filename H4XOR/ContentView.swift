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
            List(viewModel.posts) { post in
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
}

#Preview {
    ContentView()
}
