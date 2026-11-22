# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

H4XOR es una app SwiftUI para iOS/iPadOS que muestra las historias de la portada de Hacker News, obtenidas de la API de Algolia HN (`https://hn.algolia.com/api/v1/search?tags=front_page`). Tiene un target de app, `H4XOR`, y un target de tests unitarios, `H4XORTests` (Swift Testing). No usa dependencias de terceros.

## Compilar, ejecutar y probar

```sh
# Compilar para el simulador
xcodebuild -project H4XOR.xcodeproj -scheme H4XOR -destination 'generic/platform=iOS Simulator' build

# Listar simuladores disponibles / elegir un destino concreto
xcrun simctl list devices available
xcodebuild -project H4XOR.xcodeproj -scheme H4XOR -destination 'platform=iOS Simulator,name=<dispositivo>' build

# Ejecutar los tests (necesita un simulador concreto, no el destino genérico)
xcodebuild test -project H4XOR.xcodeproj -scheme H4XOR -destination 'platform=iOS Simulator,name=<dispositivo>'
```

Si `xcodebuild` falla con "requires Xcode, but active developer directory ... is a command line tools instance", antepón `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` o ejecuta `sudo xcode-select -s /Applications/Xcode.app`.

No hay linter configurado.

## Formato del proyecto

El proyecto usa el formato JSON de Xcode `H4XOR.xcodeproj/project.xcproj` (no el clásico `project.pbxproj`). Las carpetas `H4XOR/` y `H4XORTests/` están vinculadas como **folder** con pertenencia a su target. Cualquier archivo que se agregue dentro se compila (o se copia como recurso) automáticamente. No hace falta editar el archivo del proyecto para registrar archivos nuevos. Los recursos como `.json` se copian a la raíz del bundle, sin subcarpetas.

El scheme `H4XOR` lo genera Xcode automáticamente (no hay `.xcscheme` compartido) e incluye `H4XORTests`, que corre alojado en la app (`TEST_HOST`), así que los tests usan `@testable import H4XOR` y `Bundle.main` es el bundle de la app.

Ajustes de compilación que afectan cómo hay que escribir el código (iguales en ambos targets):
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY = YES`: los tipos están aislados en el main actor por defecto. Hay que marcar el código como `nonisolated` / `@concurrent` explícitamente cuando deba correr fuera del main actor.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`: cada archivo debe hacer `import` de los módulos cuyos miembros usa (p. ej. `Observation`, `Foundation`).
- El Info.plist se genera automáticamente (`GENERATE_INFOPLIST_FILE = YES`); las claves se agregan con ajustes `INFOPLIST_KEY_*`. El deployment target es iOS 27.2.

## Arquitectura

Flujo de datos por capas, todo con async/await (sin Combine):

`ContentView` → `PostViewModel` → `PostDataManager` → `NetworkClient` (`NetworkManager` o `MockNetworkClient`)

Las dependencias se inyectan por `init` con valores por defecto reales. Así la app usa la red, y los previews y tests pasan un `MockNetworkClient`.

### Capa de red (`H4XOR/Networking/`)

Especificada en `specs/01-network-manager.md`.

- **`Endpoint`**: protocolo que describe una petición (`baseURL`, `path`, `method`, `headers`, `queryItems`, `body: (any Encodable)?`), con valores por defecto (GET, sin headers/query/body). `makeURLRequest()` agrega `Accept: application/json` y, si hay body, lo codifica como JSON con `Content-Type: application/json`. Los headers del endpoint mandan sobre los automáticos. Cada servicio define su propio tipo (p. ej. `PostEndpoint` en `Models/`).
- **`HTTPMethod`**: `get`, `post`, `put`, `patch`, `delete`.
- **`NetworkClient`**: protocolo con `request<T: Decodable & Sendable>(_:) -> T` y `request(_:)` sin retorno (DELETE / 204).
- **`NetworkManager`**: implementación sobre `URLSession`. Valida que la respuesta sea HTTP 2xx con `static validate(data:response:)`.
- **`NetworkError`**: `invalidURL`, `invalidResponse`, `httpStatus(code:data:)`, `encoding`, `decoding`, `transport`.
- **`ResponseDecoder`**: decodifica las respuestas **fuera del main actor** (`decode` es `@concurrent`). Tanto `NetworkManager` como `MockNetworkClient` decodifican solo a través de él.
- **`Mocks/MockNetworkClient`**: no toca la red. Registra cada petición en `receivedRequests`, lanza `error` si está configurado y, si no, decodifica la respuesta mockeada. La respuesta se configura con un string JSON (`init(json:)`), un archivo `.json` de un bundle (`init(jsonFile:bundle:)`) o un objeto dummy `Encodable` (`init(response:)`). Cada forma tiene su método `respond(...)` equivalente.
- **`Mocks/PostData+Dummy.swift`** (`Post.dummy`, `Post.dummies`, `Results.dummy`) y **`Mocks/JSON/front_page.json`**: datos de ejemplo para previews y tests.

**Regla para modelos de respuesta:** deben declararse `nonisolated` y `Sendable` (y `Codable` si se quieren usar como dummies del mock). Sin `nonisolated`, su conformidad a `Decodable` queda aislada al main actor y no compila al pasar por `ResponseDecoder`.

### App

- **`PostDataManager`**: recibe un `NetworkClient` y pide `PostEndpoint.frontPage`.
- **`PostViewModel`**: clase `@Observable` con un único `state: LoadState` (`idle`, `loading`, `loaded([Post])`, `failed(message:)`). Los posts viajan dentro de `.loaded`; no hay una propiedad `posts` aparte. `fetchPosts()` reemplaza los posts en cada carga, así que reintentar no duplica resultados. Los errores ya no son silenciosos: terminan en `.failed`.
- **`ContentView`**: guarda el view model con `@State` (framework Observation, no `@StateObject`), dispara la carga en `.task` y hace `switch` sobre `state`: `ProgressView`, lista, o `ContentUnavailableView` con botón "Reintentar". Tiene dos previews sin red: "Posts (mock)" y "Error (mock)".
- **`PostData.swift`**: `Results { hits: [Post] }` y `Post` (`Identifiable` mediante `objectID`, con `url` opcional), reflejando la estructura del JSON de Algolia.

### Tests (`H4XORTests/`)

Un archivo por pieza: `EndpointTests`, `ResponseDecoderTests` (incluye `DecodingThreadProbe`, que verifica que la decodificación ocurre fuera del hilo principal), `NetworkManagerValidationTests`, `MockNetworkClientTests`, `PostDataManagerTests` y `PostViewModelTests`. No hay tests que toquen la red: `URLSession` no se stubbea (`URLProtocol` quedó fuera de alcance) y la validación HTTP se prueba vía `NetworkManager.validate`.
