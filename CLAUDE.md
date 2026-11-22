# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

H4XOR es una app SwiftUI para iOS/iPadOS que muestra las historias de la portada de Hacker News, obtenidas de la API de Algolia HN (`hn.algolia.com/api/v1/search?tags=front_page`). Un solo target de app, `H4XOR`, sin tests y sin dependencias de terceros.

## Compilar y ejecutar

```sh
# Compilar para el simulador
xcodebuild -project H4XOR.xcodeproj -scheme H4XOR -destination 'generic/platform=iOS Simulator' build

# Listar simuladores disponibles / elegir un destino concreto
xcrun simctl list devices available
xcodebuild -project H4XOR.xcodeproj -scheme H4XOR -destination 'platform=iOS Simulator,name=<dispositivo>' build
```

No hay target de tests ni linter configurado.

## Formato del proyecto

El proyecto usa el formato JSON de Xcode `H4XOR.xcodeproj/project.xcproj` (no el clásico `project.pbxproj`). La carpeta `H4XOR/` está vinculada como **folder** con pertenencia al target, así que cualquier archivo `.swift` que se agregue dentro de `H4XOR/` se compila automáticamente. No hace falta editar el archivo del proyecto para registrar archivos nuevos.

Ajustes de compilación que afectan cómo hay que escribir el código:
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY = YES`: los tipos están aislados en el main actor por defecto. Hay que marcar el código como `nonisolated` / `@concurrent` explícitamente cuando deba correr fuera del main actor.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`: cada archivo debe hacer `import` de los módulos cuyos miembros usa (p. ej. `Observation`, `Foundation`).
- El Info.plist se genera automáticamente (`GENERATE_INFOPLIST_FILE = YES`); las claves se agregan con ajustes `INFOPLIST_KEY_*`. El deployment target es iOS 27.2.

## Arquitectura

Flujo de datos por capas, todo con async/await (sin Combine):

`ContentView` → `PostViewModel` → `PostDataManager` → `NetworkManager`

- **`NetworkManager`** (`H4XOR/Models/NetworkManager.swift`): método genérico `fetchData<T: Decodable>(url:)` con URLSession + JSONDecoder. Conserva comentada una implementación antigua con `ObservableObject`/`dataTask` como referencia.
- **`PostDataManager`**: contiene la URL del endpoint y devuelve los `Results` decodificados.
- **`PostViewModel`**: clase `@Observable` con `posts`; `fetchPosts()` ignora los errores con `try?` y agrega los resultados.
- **`ContentView`**: guarda el view model con `@State` (framework Observation, no `@StateObject`) y dispara la carga en `.task`.
- **`PostData.swift`**: `Results { hits: [Post] }` y `Post` (`Identifiable` mediante `objectID`, con `url` opcional), reflejando la estructura del JSON de Algolia.

Nota: el endpoint usa `http://` sin cifrar y el Info.plist generado no tiene excepción de App Transport Security, así que la petición probablemente se bloquea en tiempo de ejecución. El fallo es silencioso porque el view model usa `try?`.
