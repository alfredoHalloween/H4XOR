//
//  MockNetworkClient.swift
//  H4XOR
//

import Foundation

/// `NetworkClient` falso para previews y tests. No toca la red.
///
/// Registra cada petición en `receivedRequests` y, si `error` no es `nil`, lo lanza.
/// En caso contrario decodifica `responseData` con `ResponseDecoder`, igual que `NetworkManager`
/// (es decir, fuera del main actor).
///
/// La respuesta se puede configurar de tres formas:
/// - JSON en un `String`: `MockNetworkClient(json: "{ \"hits\": [] }")`
/// - Archivo `.json` de un bundle: `try MockNetworkClient(jsonFile: "front_page")`
/// - Objeto dummy `Encodable`: `try MockNetworkClient(response: Results.dummy)`
final class MockNetworkClient: NetworkClient {

    /// Errores al preparar los datos mockeados.
    enum MockDataError: Error {
        /// No existe `<name>.json` en el bundle indicado.
        case fileNotFound(name: String)
    }

    /// JSON que se decodificará como respuesta.
    var responseData: Data
    /// Si no es `nil`, se lanza en lugar de devolver una respuesta.
    var error: NetworkError?
    /// Peticiones recibidas, en orden, para hacer asserts.
    private(set) var receivedRequests: [URLRequest] = []

    private let responseDecoder: ResponseDecoder

    init(
        responseData: Data = Data(),
        error: NetworkError? = nil,
        responseDecoder: ResponseDecoder = ResponseDecoder()
    ) {
        self.responseData = responseData
        self.error = error
        self.responseDecoder = responseDecoder
    }

    /// Mock que responde con el JSON del string.
    convenience init(json: String) {
        self.init()
        respond(withJSON: json)
    }

    /// Mock que responde con el contenido de `<name>.json` del bundle.
    convenience init(jsonFile name: String, bundle: Bundle = .main) throws {
        self.init()
        try respond(withJSONFile: name, bundle: bundle)
    }

    /// Mock que responde con un objeto dummy, codificado a JSON.
    convenience init(response: some Encodable, encoder: JSONEncoder = JSONEncoder()) throws {
        self.init()
        try respond(with: response, encoder: encoder)
    }

    // MARK: - Configurar la respuesta

    /// Usa el JSON del string como respuesta.
    func respond(withJSON json: String) {
        responseData = Data(json.utf8)
    }

    /// Usa el contenido de `<name>.json` del bundle como respuesta.
    func respond(withJSONFile name: String, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw MockDataError.fileNotFound(name: name)
        }
        responseData = try Data(contentsOf: url)
    }

    /// Codifica el objeto dummy a JSON y lo usa como respuesta.
    /// Se codifica (en lugar de devolverlo tal cual) para que la respuesta pase por `ResponseDecoder`.
    func respond(with value: some Encodable, encoder: JSONEncoder = JSONEncoder()) throws {
        responseData = try encoder.encode(value)
    }

    // MARK: - NetworkClient

    func request<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        try record(endpoint)
        return try await responseDecoder.decode(T.self, from: responseData)
    }

    func request(_ endpoint: some Endpoint) async throws {
        try record(endpoint)
    }

    /// Guarda la `URLRequest` del endpoint y lanza `error` si está configurado.
    private func record(_ endpoint: some Endpoint) throws(NetworkError) {
        receivedRequests.append(try endpoint.makeURLRequest())
        if let error {
            throw error
        }
    }
}
