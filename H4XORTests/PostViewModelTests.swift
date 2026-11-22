//
//  PostViewModelTests.swift
//  H4XORTests
//

import Foundation
import Testing
@testable import H4XOR

struct PostViewModelTests {

    private func makeViewModel(client: MockNetworkClient) -> PostViewModel {
        PostViewModel(dataManager: PostDataManager(client: client))
    }

    @Test func startsIdle() throws {
        let viewModel = makeViewModel(client: MockNetworkClient())
        #expect(viewModel.state == .idle)
    }

    @Test func successEndsInLoadedWithPosts() async throws {
        let viewModel = makeViewModel(client: try MockNetworkClient(response: Results.dummy))

        await viewModel.fetchPosts()

        #expect(viewModel.state == .loaded(Post.dummies))
    }

    @Test func errorEndsInFailed() async {
        let viewModel = makeViewModel(client: MockNetworkClient(error: .invalidResponse))

        await viewModel.fetchPosts()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("Se esperaba .failed y llegó \(viewModel.state)")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func fetchingTwiceDoesNotDuplicatePosts() async throws {
        let viewModel = makeViewModel(client: try MockNetworkClient(response: Results.dummy))

        await viewModel.fetchPosts()
        await viewModel.fetchPosts()

        guard case .loaded(let posts) = viewModel.state else {
            Issue.record("Se esperaba .loaded y llegó \(viewModel.state)")
            return
        }
        #expect(posts.count == Post.dummies.count)
    }

    @Test func retryAfterErrorLoadsPosts() async throws {
        let client = MockNetworkClient(error: .invalidResponse)
        let viewModel = makeViewModel(client: client)

        await viewModel.fetchPosts()
        client.error = nil
        try client.respond(with: Results.dummy)
        await viewModel.fetchPosts()

        #expect(viewModel.state == .loaded(Post.dummies))
    }
}
