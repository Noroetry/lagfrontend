# DEVELOPMENT.md

Este documento describe la estructura del proyecto `lagfrontend` en Flutter, su arquitectura, patrones de código, instrucciones para ejecutar/tests/desplegar y una guía práctica para tareas habituales de desarrollo. Está pensado para que puedas entender, explorar y ampliar la aplicación rápidamente.

--

## Contenido

- Resumen del proyecto
- Arquitectura general
- Archivos y carpetas importantes (recorrido)
- Librerías y dependencias clave
- Gestión de estado y DI (Provider)
- Servicios, controladores y modelos: contratos y flujo
- Autenticación y ciclo de vida del token
- UI / Theming / Widgets
- Estrategia de tests y cómo ejecutarlos
- Depuración y diagnósticos
- Ejecutar en local (dispositivo) vs. producción en Render
- Despliegue de builds móviles
- Convenciones de contribución y estilo
- Problemas comunes y soluciones
- Siguientes pasos y recomendaciones de mantenimiento

## Resumen del proyecto

`lagfrontend` es una aplicación móvil escrita en Flutter que consume un backend REST (endpoints de usuarios y mensajes). Emplea una arquitectura de servicios + controladores, usa Provider para inyección de dependencias y ChangeNotifier para las actualizaciones de UI. El proyecto centraliza tokens de tema y contiene componentes UI reutilizables (popups, campos de formulario, etc.).

Responsabilidades principales:
- Autenticación: login/registro, persistencia de token y validación (/me).
- Subsistema de mensajes: modelo `Message` tipado, bandeja de entrada/enviados, enviar/marcar como leído, popup de mensajes no leídos.
- Componentes UI reutilizables y tema centralizado.
- Tests: tests unitarios para servicios/controladores y tests de widgets.

Nota: la aplicación implementa validaciones de cliente (ej. bloquear nombres reservados) por UX, pero la validación definitiva debe ocurrir en el backend.

## Arquitectura general

- Servicios: wrappers que llaman a la API (HTTP), retornan modelos tipados o lanzan excepciones tipadas.
- Controladores: clases `ChangeNotifier` que orquestan llamadas a servicios, mantienen el estado de UI y son expuestos como `Provider` para los widgets.
- Modelos: clases Dart simples con `fromJson` / `toJson` donde procede.
- UI: widgets Flutter organizados en `lib/views/`, con componentes compartidos en `lib/widgets/` y tema en `lib/theme/`.
- DI: se usa `Provider`. Los servicios suelen exponerse por interfaces (`IAuthService`, `IMessagesService`) para facilitar pruebas e intercambio de implementaciones.
- Excepciones: los servicios lanzan excepciones tipadas (`UnauthorizedException`, `ApiException`, `NetworkException`) que los controladores capturan y traducen a mensajes de usuario o acciones de limpieza.

## Archivos y carpetas importantes

En la raíz del proyecto:
- `pubspec.yaml` — dependencias y assets.
- `README.md` — descripción general.
- `DEVELOPMENT.md` — esta guía.

Carpetas clave dentro de `lib/`:
- `lib/main.dart` — punto de entrada y registro del grafo de `Provider`.
- `lib/config/app_config.dart` — URLs base, toggles de entorno y helper para forzar una URL en tiempo de ejecución.
- `lib/utils/` — utilidades:
  - `exceptions.dart` — excepciones tipadas.
  - `custom_http_client.dart` — wrapper para timeouts y comportamiento HTTP.
- `lib/services/` — interfaces e implementaciones de servicios:
  - `i_auth_service.dart` / `auth_service.dart` — endpoints de autenticación.
  - `i_messages_service.dart` / `messages_service.dart` — endpoints de mensajería.
- `lib/controllers/` — controladores `ChangeNotifier`:
  - `auth_controller.dart` — login/registro/logout y gestión de token.
  - `messages_controller.dart` — carga de mensajes y lógica de popup de no leídos.
- `lib/models/` — modelos tipados (`user_model.dart`, `auth_response_model.dart`, `message_model.dart`).
- `lib/views/` — pantallas y vistas.
- `lib/widgets/` — componentes compartidos (popups, campos personalizados).
- `lib/theme/` — `app_theme.dart` con tokens y paleta.

Los tests están en `test/`.

## Librerías y dependencias clave

(consulta `pubspec.yaml` para versiones exactas)
- Flutter SDK
- Provider — gestión de estado e inyección de dependencias
- http — cliente HTTP (envuelto por `CustomHttpClient`)
- flutter_secure_storage — almacenamiento seguro del JWT
- jwt_decoder — chequeo de expiración y decodificado local del JWT
- mocktail + flutter_test — para tests unitarios y de widgets

## Gestión de estado y DI

- Se usa `Provider` para registrar servicios y controladores. Los servicios se exponen por interfaz para facilitar los mocks.
- Los controladores son `ChangeNotifier` que dependen de servicios. Grafo típico:
  - Proveer `IAuthService` (concreto `AuthService`)
  - Proveer `IMessagesService` (concreto `MessagesService`)
  - Proveer `AuthController` (depende de `IAuthService`)
  - Proveer `MessagesController` (depende de `IMessagesService` y escucha cambios de `AuthController`)

Las interfaces permiten cambiar implementaciones y facilitar las pruebas.

## Servicios, controladores y modelos — contratos y flujo

Servicios:
- Aceptan `http.Client` y `FlutterSecureStorage` inyectables (útil en tests).
- Devuelven modelos tipados o lanzan excepciones tipadas.
- `_getAuthHeaders()` gestiona la inclusión del token en los headers.

Controladores:
- Consumidores de servicios por interfaz.
- Mantienen el estado de UI (`isLoading`, `errorMessage`, `currentUser`, listas de mensajes).
- Gestionan persistencia de token y limpieza (borrar token en 401 / logout).
- Exponen métodos para la UI (`login`, `registerAndLogin`, `logout`, `loadInbox`, etc.).

Modelos:
- `User` — datos de usuario.
- `AuthResponse` — usuario + token devuelto por login/registro.
- `Message` — payload tipado para mensajes.

## Autenticación y ciclo de vida del token

Flujo resumido:
1. `login` / `register` devuelven `AuthResponse` con `token` y `user`.
2. El controlador guarda `jwt_token` en `flutter_secure_storage`.
3. Al iniciar la app, `AuthController.checkAuthenticationStatus()`:
   - Lee el token guardado (de forma defensiva, para tolerar mocks y casos borde).
   - Comprueba expiración local con `jwt_decoder`.
   - Si no está expirado localmente, intenta validar con `/me` vía `AuthService.getProfile()`.
     - Si `/me` responde 200 con perfil, el controlador queda autenticado.
     - Si `/me` responde 401, el controlador borra el token y queda no autenticado.
   - Si `getProfile()` no está disponible (por ejemplo, un mock no stubbed en tests), hay un fallback que decodifica el JWT para poblar un `User` y permitir tests/local flows.
4. Los servicios lanzan `UnauthorizedException` en 401; los controladores la capturan y borran el token.

Nota de seguridad: las validaciones del frontend son para UX; la validación definitiva debe implementarla el backend.

## UI / Theming / Widgets

- `lib/theme/app_theme.dart` centraliza colores y tipografías.
- Componentes popup (ej. `PopupForm`) están en `lib/widgets/` y se usan en pantallas de auth.
- Los widgets obtienen controladores con `Provider.of` o `Consumer`. En tests, ten en cuenta que el widget puede necesitar un `Provider` en el arbol para no lanzar `ProviderNotFoundException`.

## Tests

Este repositorio no contiene tests automatizados. Se han eliminado los archivos de prueba y las dependencias de test del `pubspec.yaml`.

Si más adelante quieres volver a añadir pruebas, la recomendación es:

- Añadir tests en la carpeta `test/` con `flutter_test` y `mocktail`.
- Documentar cómo ejecutar `flutter test` en tus scripts/CI.

Analizador de código:

```powershell
flutter analyze
```

## Depuración y diagnósticos

- Hay `debugPrint(...)` en puntos clave (lectura/escritura de token, llamadas al backend) que ayudan a rastrear comportamientos.
- Para inspeccionar tráfico HTTP puedes ampliar `CustomHttpClient` o usar un `http.Client` mock para validar solicitudes.

Problemas comunes y soluciones rápidas:
- `ProviderNotFoundException` en tests: añade el provider necesario en el setup del test o haz el widget más defensivo.
- `TypeError` por mocks: asegúrate de usar `thenAnswer((_) async => ...)` y devolver `Future` cuando el código lo espera.
- 401 del backend: revisar headers de autorización y `AppConfig` (URL base).
- Token no persistente: comprobar `flutter_secure_storage` en la plataforma de destino; el controlador registra las operaciones de lectura/escritura.

## Ejecutar en local en dispositivo vs. producción en Render

- `AppConfig.isDevelopment` (controlado por `--dart-define=DEV_MODE=true/false`) selecciona la URL base:
  - Desarrollo (emulador): `http://10.0.2.2:3000/api` (apunta al host local desde el emulador Android).
  - Producción: `https://lagbackend.onrender.com/api`.

Opciones recomendadas:
- Sin tocar código, ejecutar con la URL de Render:

```powershell
# ejecutar en dispositivo/emulador apuntando a Render
flutter run --dart-define=DEV_MODE=false

# compilar APK release apuntando a Render
flutter build apk --release --dart-define=DEV_MODE=false
```

- Override temporal en código (pruebas rápidas): en `lib/main.dart` antes de `runApp()`:

```dart
AppConfig.setOverrideBaseApiUrl('https://lagbackend.onrender.com/api');
```

Recomendación: no dejar overrides hardcodeados en `main.dart` antes de subir a producción.

## Despliegue de builds móviles

- Android:
  - Debug: `flutter run --dart-define=DEV_MODE=false`
  - Release APK: `flutter build apk --release --dart-define=DEV_MODE=false`
  - App Bundle: `flutter build appbundle --release --dart-define=DEV_MODE=false`
- iOS:
  - macOS necesario: `flutter build ios --release --dart-define=DEV_MODE=false` y firmar con Xcode.

El proceso de firma y publicación en Play Store / App Store sigue la documentación oficial de Flutter y no se cubre aquí en detalle.

## CI y automatización (sugerencias)

- Añadir un workflow de GitHub Actions que ejecute `flutter analyze` y `flutter test` en PRs y pushes a `main`.
- Añadir un workflow de release que construya artefactos con `--dart-define=DEV_MODE=false`.

Pasos mínimos para GH Actions:
- checkout
- set up Flutter
- `flutter pub get`
- `flutter analyze`
- `flutter test`

## Convenciones de contribución y estilo

- Mantén APIs públicas pequeñas y bien tipadas.
- Inyecta `http.Client` y `FlutterSecureStorage` en servicios para facilitar pruebas.
- Usa excepciones tipadas y trátalas en los controladores.
- Tests deben stubbing los mismos contratos que el código de producción.
- Mantén estado de UI en controladores; widgets deben ser lo más declarativos posible.

## Problemas frecuentes y referencia rápida

- `ProviderNotFoundException`: añadir provider en el harness de test o hacer widget más tolerante.
- `TypeError` por mock: devolver `Future` cuando el código lo espera.
- 401: revisar `AuthService._getAuthHeaders()` y `AppConfig`.
- Token no guardado: revisar logs de `AuthController` que imprimen confirmación de escritura/lectura.

## Cómo añadir una nueva funcionalidad (ejemplo: nuevo endpoint)

1. Añadir modelo tipado en `lib/models/` con `fromJson`/`toJson`.
2. Añadir método en la interfaz `i_<service>.dart` e implementarlo en `<service>.dart` (inyectar `http.Client`).
3. Lanzar excepciones tipadas en respuestas no esperadas.
4. Añadir/actualizar un controlador que llame al servicio y actualice el estado.
5. Añadir la UI correspondiente en `lib/views/` y conectarla vía `Provider`.
6. Escribir tests unitarios para el servicio y el controlador.

## Notas operativas y TODOs

- Verifica el valor por defecto de `AppConfig.isDevelopment` para CI/producción.
- Añadir un menú de debug para cambiar la URL en tiempo de ejecución puede ser útil.
- Considerar centralizar cadenas de texto (i18n) en `AppStrings`.

## Lista rápida para empezar a entender el código

1. Abrir `lib/main.dart` y revisar el registro de providers.
2. Leer `lib/controllers/auth_controller.dart` y `lib/services/auth_service.dart` para entender el ciclo del token.
3. Ejecutar `flutter test` y revisar los tests para aprender patrones de mock.
4. Ejecutar la app en tu móvil con `--dart-define=DEV_MODE=false` para probar contra Render.

---

Si quieres, puedo además:
- Generar un diagrama simplificado (ASCII o Mermaid) del grafo Provider→Controller→Service.
- Añadir una pantalla/debug menu para cambiar la URL base en tiempo de ejecución.
- Crear el archivo de workflow de GitHub Actions para CI.
- Revertir `AppConfig.isDevelopment` a `false` por defecto y actualizar los tests para que fijen `DEV_MODE=true` explícitamente.

Dime cuál de estas mejoras prefieres y la implemento (CI, debug UI, diagrama, o revert del `isDevelopment`).