# SPEC 01 — Network manager genérico y mockeable

> **Status:** Aprobado
> **Depends on:** —
> **Date:** 2026-11-21
> **Objective:** Reemplazar `NetworkManager` por un cliente HTTP basado en un protocolo `Endpoint`, que soporte GET/POST/PUT/PATCH/DELETE, se pueda mockear vía el protocolo `NetworkClient` y esté cubierto por tests.

## Por qué existe esta spec

El `NetworkManager` actual solo hace GET, no valida códigos HTTP y está instanciado de forma rígida dentro de `PostDataManager`. Eso impide consultar otros servicios, probar sin red y mostrar errores. `PostViewModel` usa `try?`, así que cualquier fallo es silencioso.

## Scope

**In:**

- Enum `HTTPMethod` con `get`, `post`, `put`, `patch`, `delete`.
- Protocolo `Endpoint` (base URL, path, método, headers, query items, body `Encodable`) con valores por defecto y construcción de `URLRequest`.
- Enum `NetworkError` con casos tipados.
- Protocolo `NetworkClient` con dos métodos: respuesta `Decodable` y respuesta vacía.
- `NetworkManager` reescrito sobre `URLSession`, conforme a `NetworkClient`, que valida códigos 2xx.
- Decodificación de las respuestas fuera del main actor mediante `ResponseDecoder` (función `@concurrent`), usada por `NetworkManager` y `MockNetworkClient`.
- `MockNetworkClient` en el target de app (usable en previews y tests).
- `PostEndpoint` y `PostDataManager` con inyección de `NetworkClient` por init.
- `PostViewModel` con estado `LoadState` (idle / loading / loaded / failed) y sin `try?` silencioso.
- `ContentView` con `ProgressView` al cargar y `ContentUnavailableView` con botón "Reintentar" al fallar; preview con el mock.
- Nuevo target de tests `H4XORTests` con Swift Testing.
- Actualizar `CLAUDE.md` (arquitectura y tests).

**Out of scope (para futuras specs):**

- Cambiar el endpoint de `http://` a `https://` o agregar excepciones ATS (seguimos en fase de pruebas).
- Headers globales, autenticación e interceptores.
- Bodies form-urlencoded o multipart, y respuestas como `Data` cruda.
- Stubs con `URLProtocol` para probar `URLSession` de punta a punta.
- Reintentos automáticos, timeouts configurables, caché y paginación.
- Codificar el body fuera del main actor (es pequeño y se hace al construir la `URLRequest`).

## Data model

Todos los archivos nuevos de red viven en `H4XOR/Networking/`. Se compilan solos por estar dentro de la carpeta vinculada `H4XOR/`.

```swift
// H4XOR/Networking/HTTPMethod.swift
enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

// H4XOR/Networking/NetworkError.swift
enum NetworkError: Error {
    case invalidURL
    case invalidResponse                 // la respuesta no es HTTPURLResponse
    case httpStatus(code: Int, data: Data) // código fuera de 200..<300
    case encoding(any Error)
    case decoding(any Error)
    case transport(any Error)            // errores de URLSession
}

// H4XOR/Networking/Endpoint.swift
protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }          // default: .get
    var headers: [String: String] { get }   // default: [:]
    var queryItems: [URLQueryItem] { get }  // default: []
    var body: (any Encodable)? { get }      // default: nil
}
// extension Endpoint: defaults + func makeURLRequest(encoder: JSONEncoder) throws(NetworkError) -> URLRequest
//   - Siempre agrega "Accept: application/json".
//   - Si hay body: lo codifica como JSON y agrega "Content-Type: application/json".
//   - Los headers del endpoint sobrescriben a los automáticos.

// H4XOR/Networking/ResponseDecoder.swift
nonisolated struct ResponseDecoder: Sendable {
    let decoder: JSONDecoder               // default: JSONDecoder()
    @concurrent
    func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws(NetworkError) -> T
    // Corre en el pool de hilos global, nunca en el main actor.
    // Envuelve cualquier fallo en NetworkError.decoding.
}

// H4XOR/Networking/NetworkClient.swift
protocol NetworkClient {
    func request<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T
    func request(_ endpoint: some Endpoint) async throws   // respuestas sin contenido (DELETE / 204)
}

// H4XOR/Networking/NetworkManager.swift
final class NetworkManager: NetworkClient {
    init(session: URLSession = .shared, responseDecoder: ResponseDecoder = ResponseDecoder(), encoder: JSONEncoder = JSONEncoder())
    static func validate(data: Data, response: URLResponse) throws(NetworkError) -> Data // función pura, testeable
    // request<T>: construye la URLRequest, llama a URLSession, valida y delega en `await responseDecoder.decode(T.self, from:)`.
}

// H4XOR/Networking/Mocks/MockNetworkClient.swift
final class MockNetworkClient: NetworkClient {
    var responseData: Data = Data()            // JSON que se decodificará con ResponseDecoder (también fuera del main actor)
    var error: NetworkError?                   // si no es nil, se lanza
    private(set) var receivedRequests: [URLRequest] = [] // registro para asserts
}

// H4XOR/Models/PostEndpoint.swift
enum PostEndpoint: Endpoint {
    case frontPage   // http://hn.algolia.com /api/v1/search ?tags=front_page
}

// H4XOR/Models/PostViewModel.swift
enum LoadState: Equatable {
    case idle, loading, loaded, failed(message: String)
}
```

Cambios en tipos existentes:

- `PostDataManager`: `init(client: any NetworkClient = NetworkManager())`. `fetchPosts()` llama a `client.request(PostEndpoint.frontPage)`.
- `PostViewModel`: `init(dataManager: PostDataManager = PostDataManager())`, `private(set) var state: LoadState = .idle`. `fetchPosts()` **reemplaza** `posts` en lugar de agregar.
- `ContentView`: `init(viewModel: PostViewModel = PostViewModel())` guardado en `@State`.
- `Results` y `Post` pasan a `nonisolated struct ... : Decodable, Sendable`. Sin esto su conformidad a `Decodable` queda aislada al main actor y no se puede usar desde `ResponseDecoder`. Sus campos no cambian.

Convenciones:

- Todo sigue aislado al main actor por defecto (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), excepto `ResponseDecoder` y los modelos de respuesta.
- Todo modelo de respuesta nuevo debe declararse `nonisolated` y `Sendable` para poder pasar por `NetworkClient.request`.
- Cada archivo importa explícitamente `Foundation` / `Observation` / `SwiftUI` según lo que use.

## Implementation plan

1. Crear `H4XOR/Networking/HTTPMethod.swift`, `NetworkError.swift` y `Endpoint.swift` (protocolo, defaults y `makeURLRequest`). Nada los usa todavía. Compila.
2. Crear `H4XOR/Networking/ResponseDecoder.swift` con `decode` marcado `@concurrent`. Marcar `Results` y `Post` como `nonisolated` y `Sendable` en `PostData.swift`. Nada usa `ResponseDecoder` todavía. Compila sin avisos de concurrencia.
3. Crear `H4XOR/Networking/NetworkClient.swift`. Mover `NetworkManager.swift` de `Models/` a `Networking/`, reescribirlo conforme a `NetworkClient` con `validate(data:response:)`, decodificar con `ResponseDecoder` y borrar el código antiguo comentado. Crear `H4XOR/Models/PostEndpoint.swift` y migrar `PostDataManager` a inyección + `PostEndpoint.frontPage`. La app compila y se comporta igual que antes.
4. Crear `H4XOR/Networking/Mocks/MockNetworkClient.swift`, que también decodifica con `ResponseDecoder`. Compila.
5. Agregar `LoadState` e inyección a `PostViewModel`. Quitar `try?`: en `catch` pasa a `.failed(message:)`. Al cargar reemplaza `posts`. Compila.
6. Actualizar `ContentView`: `ProgressView` en `.loading`, lista en `.loaded`, `ContentUnavailableView` con botón "Reintentar" en `.failed`. Cambiar `#Preview` para usar `MockNetworkClient` con un JSON de ejemplo. Prueba manual: el preview muestra posts sin red. En el simulador se ve el estado de error, porque el `http://` sigue bloqueado por ATS.
7. Agregar el target de tests `H4XORTests` (unit-test bundle, host `H4XOR`) en `H4XOR.xcodeproj/project.xcproj`, con la carpeta `H4XORTests/` vinculada como folder. Incluirlo en la acción de test del scheme. Crear un test trivial con Swift Testing. `xcodebuild test` pasa.
8. Escribir los tests en `H4XORTests/`:
   - `EndpointTests`: método, URL con query, headers por defecto y body JSON.
   - `ResponseDecoderTests`: decodifica un JSON válido; un JSON inválido lanza `NetworkError.decoding`; un tipo sonda `nonisolated struct DecodingThreadProbe: Decodable, Sendable` registra `Thread.isMainThread` en su `init(from:)`, y al decodificarlo desde un test `@MainActor` el valor es `false`.
   - `NetworkManagerValidationTests`: 2xx devuelve los datos, 404 lanza `httpStatus`, una respuesta no HTTP lanza `invalidResponse`.
   - `PostDataManagerTests`: decodifica con el mock y registra un GET a `/api/v1/search?tags=front_page`.
   - `PostViewModelTests`: termina en `.loaded` con posts; error → `.failed`; dos cargas no duplican posts.
9. Actualizar `CLAUDE.md`: nueva capa `Networking/`, decodificación fuera del main actor (los modelos de respuesta deben ser `nonisolated` y `Sendable`), target `H4XORTests`, comando `xcodebuild test` y la nota sobre que el error ya no es silencioso.

## Acceptance criteria

- [ ] `xcodebuild -project H4XOR.xcodeproj -scheme H4XOR -destination 'generic/platform=iOS Simulator' build` termina sin errores.
- [ ] `xcodebuild test -project H4XOR.xcodeproj -scheme H4XOR -destination 'platform=iOS Simulator,name=<dispositivo>'` ejecuta los tests de `H4XORTests` y todos pasan.
- [ ] `HTTPMethod` tiene exactamente los casos `get`, `post`, `put`, `patch`, `delete`.
- [ ] Un `Endpoint` con body produce una `URLRequest` con `httpBody` JSON y `Content-Type: application/json`.
- [ ] `NetworkManager.validate` lanza `NetworkError.httpStatus` para cualquier código fuera de `200..<300`.
- [ ] `NetworkClient` expone un `request` que devuelve `Decodable & Sendable` y otro sin valor de retorno.
- [ ] `ResponseDecoder.decode` está marcado `@concurrent`, y `NetworkManager` y `MockNetworkClient` decodifican exclusivamente a través de él.
- [ ] El test de `DecodingThreadProbe` confirma que `init(from:)` se ejecuta fuera del hilo principal aunque la llamada parta del main actor.
- [ ] `Results` y `Post` están declarados `nonisolated` y `Sendable`.
- [ ] La compilación no muestra avisos de concurrencia en los archivos de `H4XOR/Networking/` ni en `PostData.swift`.
- [ ] `PostDataManager` y `PostViewModel` reciben sus dependencias por init con valores por defecto.
- [ ] `PostViewModel` no contiene `try?`.
- [ ] Llamar `fetchPosts()` dos veces con el mock deja el mismo número de posts que una sola llamada.
- [ ] El `#Preview` de `ContentView` muestra posts del mock sin acceso a red.
- [ ] En el simulador, con el endpoint `http://`, la app muestra `ContentUnavailableView` con botón "Reintentar" en lugar de una lista vacía.
- [ ] `H4XOR/Models/NetworkManager.swift` ya no existe y no queda código comentado antiguo.
- [ ] El endpoint sigue siendo `http://hn.algolia.com`.

## Decisions

- **Sí:** protocolo `Endpoint` por servicio. Centraliza base URL, path y parámetros, y escala a nuevos servicios sin tocar el cliente.
- **No:** métodos por verbo (`get`/`post`/...). Repiten parámetros y no centralizan la configuración.
- **No:** struct `HTTPRequest` con builder. Más flexible, pero sin tipado por servicio.
- **Sí:** protocolo `NetworkClient` + `MockNetworkClient` inyectado por init. Es el mock más simple y rápido para tests unitarios.
- **No:** stub con `URLProtocol`. Más realista, pero más complejo; queda para otra spec. Para compensar, la validación HTTP se extrae a la función pura `validate`.
- **Sí:** mock en el target de app. Así sirve también para los previews.
- **Sí:** enum `NetworkError` propio. Permite distinguir transporte, HTTP, codificación y decodificación.
- **No:** propagar `URLError`/`DecodingError` sin envolver. Obliga a la UI a conocer detalles de Foundation.
- **Sí:** body solo `Encodable` como JSON, más una variante de respuesta vacía. Cubre REST típico, incluido DELETE/204.
- **No:** form-urlencoded, multipart y `Data` cruda. Agregan superficie sin un caso de uso actual.
- **Sí:** headers solo por endpoint. Auth e interceptores van en otra spec.
- **Sí:** `LoadState` con vistas de carga y error. Elimina el fallo silencioso actual.
- **Sí:** `fetchPosts()` reemplaza `posts`. Con "Reintentar" agregar duplicaría resultados.
- **Sí:** Swift Testing en un nuevo target `H4XORTests`. Es el estándar moderno y encaja con async/await.
- **Sí:** mantener `http://`. Seguimos en fase de pruebas; el simulador mostrará el estado de error.
- **Sí:** borrar la implementación antigua comentada. Queda en el historial de git.
- **Sí:** mantener el nombre `NetworkManager` para la implementación real. Minimiza la sorpresa al leer el código.
- **Sí:** decodificar fuera del main actor con una función `@concurrent` en `ResponseDecoder`. Con respuestas grandes, decodificar en el main actor bloquearía la UI.
- **No:** convertir `NetworkManager` en un `actor`. Serializaría todas las peticiones y obligaría a cruzar actores para cada llamada; basta con sacar solo la decodificación.
- **No:** `Task.detached` para decodificar. `@concurrent` expresa la misma intención con concurrencia estructurada y sin perder la cancelación.
- **Sí:** el mock también decodifica con `ResponseDecoder`. Así los tests ejercitan el mismo camino de concurrencia que la implementación real.
- **Sí:** exigir `T: Decodable & Sendable` y modelos `nonisolated`. El resultado cruza de vuelta al main actor, y con aislamiento por defecto en el main actor la conformidad a `Decodable` no sería usable fuera de él.
- **No:** codificar el body fuera del main actor. Los bodies son pequeños y no justifican la complejidad extra.

## Risks

| Riesgo | Mitigación |
| --- | --- |
| Agregar un target de tests a mano en el formato JSON `project.xcproj` puede no ser reconocido por Xcode | Si `xcodebuild` no lo reconoce, se crea el target desde la UI de Xcode y se verifica el JSON resultante. |
| El scheme `H4XOR` vive en `xcuserdata` (no compartido) y puede no incluir el target de tests | Compartir el scheme (`xcshareddata/xcschemes`) con el target de tests en la acción Test. |
| Un modelo de respuesta nuevo sin `nonisolated` produce el error "main actor-isolated conformance cannot be used in nonisolated context" | La restricción `Decodable & Sendable` lo detecta al compilar. La convención queda documentada en `CLAUDE.md`. |
| `JSONDecoder` no fuera `Sendable` en el SDK usado | `ResponseDecoder` puede crear su `JSONDecoder` dentro de `decode` en lugar de guardarlo, si el compilador lo exige. |
| `any Encodable` y el aislamiento al main actor pueden producir avisos de concurrencia | La construcción de la `URLRequest` y la codificación del body se quedan en el main actor. |
| Con `http://` la app real nunca carga datos | Es intencional en esta fase. La UI muestra el error y el preview usa el mock. |

## What is **not** in this spec

- Migración a `https://` o excepciones ATS.
- Autenticación, headers globales e interceptores.
- Form-urlencoded, multipart y respuestas `Data`.
- Tests con `URLProtocol`.
- Reintentos, caché, timeouts y paginación.
- Codificación del body fuera del main actor.

Cada uno de estos, si llega, va en su propia spec.
