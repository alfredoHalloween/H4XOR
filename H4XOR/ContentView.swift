//
//  ContentView.swift
//  H4XOR
//
//  Created by Alfredo García on 20/11/26.
//

import SwiftUI
import Observation

struct ContentView: View {

    @State private var viewModel: PostViewModel

    init(viewModel: PostViewModel = PostViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle("H4XOR News")
        }
        .task {
            await viewModel.fetchPosts()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let posts):
            List(posts) { post in
                HStack {
                    Text(String(post.points))
                    Text(post.title)
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("No se pudieron cargar las noticias", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.fetchPosts() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Posts (mock)") {
    // `front_page.json` vive en H4XOR/Networking/Mocks/JSON/ y se copia al bundle de la app.
    let client = try! MockNetworkClient(jsonFile: "front_page")
    ContentView(viewModel: PostViewModel(dataManager: PostDataManager(client: client)))
}

#Preview("Error (mock)") {
    let client = MockNetworkClient(error: .invalidResponse)
    ContentView(viewModel: PostViewModel(dataManager: PostDataManager(client: client)))
}
