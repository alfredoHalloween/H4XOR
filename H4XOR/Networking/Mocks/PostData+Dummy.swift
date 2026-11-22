//
//  PostData+Dummy.swift
//  H4XOR
//

/// Datos dummy para previews y tests.
extension Post {
    static let dummy = Post(
        objectID: "1",
        points: 120,
        title: "Show HN: A tiny HTTP client in Swift",
        url: "https://example.com/http-client"
    )

    static let dummies: [Post] = [
        dummy,
        Post(objectID: "2", points: 85, title: "Swift Concurrency in practice", url: "https://example.com/concurrency"),
        Post(objectID: "3", points: 42, title: "Ask HN: How do you test your networking layer?", url: nil),
    ]
}

extension Results {
    static let dummy = Results(hits: Post.dummies)
}
