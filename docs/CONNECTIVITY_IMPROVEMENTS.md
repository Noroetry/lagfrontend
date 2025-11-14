# Sistema de Conectividad y Refresco Mejorado

## Resumen de Mejoras Implementadas

Se ha realizado una revisión completa del sistema de conectividad y refresco de la aplicación para solucionar los problemas reportados. Los cambios garantizan una experiencia fluida y sin errores incluso con servidores lentos que tardan ~30 segundos en despertar.

---

## 🔧 Cambios Principales

### 1. **ConnectivityService** (NUEVO)
**Archivo:** `lib/services/connectivity_service.dart`

Servicio centralizado que maneja toda la lógica de conectividad:

- ✅ **Timeouts largos (35 segundos)**: Suficiente para servidores que se despiertan lentamente
- ✅ **Sistema de reintentos con backoff exponencial**: Hasta 3 reintentos automáticos
- ✅ **Detección inteligente de conexión**: Seguimiento del estado de conectividad
- ✅ **Mensajes descriptivos**: Información clara sobre el estado de la conexión

**Características clave:**
```dart
- defaultTimeout: 35 segundos (para operaciones normales)
- quickTimeout: 10 segundos (para verificaciones rápidas)
- pingTimeout: 8 segundos (para pings)
- maxRetries: 3 intentos
- Backoff exponencial: 2s, 4s, 8s entre reintentos
```

---

### 2. **Servicios HTTP Actualizados**

Todos los servicios ahora usan `ConnectivityService` para:
- Reintentos automáticos en caso de error
- Timeouts largos configurables
- Mejor manejo de errores

**Archivos actualizados:**
- ✅ `lib/services/auth_service.dart`
- ✅ `lib/services/quest_service.dart`
- ✅ `lib/services/message_service.dart`
- ✅ `lib/utils/cookie_client.dart`

**Ejemplo de uso:**
```dart
return await _connectivity.executeWithRetry(
  operationName: 'Load Quests',
  request: () async {
    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(ConnectivityService.defaultTimeout);
    // ... procesar respuesta
  },
);
```

---

### 3. **Mejoras en AppLifecycle**

**Archivo:** `lib/main.dart`

El sistema ahora responde a **TODOS** los estados del ciclo de vida:

- ✅ `resumed`: Refresca datos cuando la app vuelve al primer plano
- ✅ `inactive`: Registra cuando la app está en transición
- ✅ `paused`: Registra cuando la app está en background
- ✅ `hidden`: Registra cuando la app no es visible
- ✅ `detached`: Registra cuando la app se está cerrando

**Características adicionales:**
- **Throttling**: No refresca si ya se hizo hace menos de 3 segundos
- **Verificación de autenticación**: Solo refresca si el usuario está logueado
- **Skip initial resume**: HomeScreen maneja la carga inicial

---

### 4. **Banner de Estado de Conexión**

**Archivo:** `lib/widgets/connection_status_banner.dart` (NUEVO)

Widget visual que muestra el estado de conexión en tiempo real:

- 🟠 **Naranja**: Problema temporal, reintentando (1-2 fallos)
- 🔴 **Rojo**: Error persistente, con botón de reintento (3+ fallos)
- ✅ **Oculto**: Cuando hay conexión estable

El banner incluye:
- Mensaje descriptivo del problema
- Contador de intentos fallidos
- Aviso sobre servidores que tardan ~30s en arrancar
- Botón "Reintentar" para forzar verificación

---

### 5. **Verificación Pre-Operación en Popups**

**Archivos actualizados:**
- ✅ `lib/widgets/quest_detail_popup.dart`
- ✅ `lib/widgets/quest_form_popup.dart`

Ahora **ANTES** de permitir cualquier acción crítica:
1. Se verifica la conexión al servidor
2. Si no hay conexión, se muestra un mensaje claro
3. Se previene el envío de datos que se perderían

**Mensajes de error mejorados:**
- Detecta errores de timeout/conexión
- Informa al usuario sobre el tiempo de arranque del servidor
- Sugiere reintentar en lugar de solo mostrar error técnico

---

### 6. **AuthController Mejorado**

**Archivo:** `lib/controllers/auth_controller.dart`

- ✅ Expone `ConnectivityService` a través de `connectivity` getter
- ✅ Usa `ConnectivityService` para verificar conexión
- ✅ Actualiza mensajes de error de conexión automáticamente

---

### 7. **HomeScreen con Estado de Conexión**

**Archivo:** `lib/views/home/home_screen.dart`

- ✅ Muestra `ConnectionStatusBanner` en la parte superior
- ✅ Banner visible solo cuando hay problemas de conexión
- ✅ Permite reintentar manualmente con un botón

---

## 📋 Flujo de Refresco Mejorado

### Eventos que Desencadenan Refresco:

1. **App vuelve al foreground** (resumed)
   - Throttling de 3 segundos entre refrescos
   - Verificación de autenticación
   - Refresco completo de datos

2. **Pull-to-refresh manual**
   - Refresco inmediato
   - Procesamiento de popups después
   - Actualización de UI

3. **Después de completar popups**
   - Refresco para sincronizar cambios
   - Actualización de contadores

4. **Cuando la app se abre por primera vez**
   - Carga inicial en HomeScreen
   - Procesamiento de popups pendientes
   - Refresco post-popups

---

## 🚀 Comportamiento con Servidor Lento

### Escenario: Servidor tarda 30 segundos en despertar

**ANTES:**
- ❌ Timeout de ~7 segundos
- ❌ Error sin reintentos
- ❌ Usuario tenía que cerrar y reabrir la app
- ❌ Checks se marcaban localmente pero no llegaban al servidor

**AHORA:**
- ✅ Timeout de 35 segundos (suficiente para despertar)
- ✅ Hasta 3 reintentos automáticos (2s, 4s, 8s de espera)
- ✅ Banner naranja durante reintentos
- ✅ Banner rojo con botón "Reintentar" si falla
- ✅ Acciones bloqueadas si no hay conexión
- ✅ Mensajes claros sobre el estado

---

## 🎯 Casos de Uso Solucionados

### 1. **App minimizada y reabierta**
✅ **Solucionado**: El lifecycle `resumed` detecta el evento y refresca todos los datos automáticamente.

### 2. **Marcar checks sin conexión**
✅ **Solucionado**: Antes de permitir marcar, se verifica la conexión. Si no hay, se muestra mensaje y se previene la acción.

### 3. **Servidor dormido (~30s de arranque)**
✅ **Solucionado**: 
- Timeout de 35 segundos permite que el servidor despierte
- 3 reintentos automáticos con mensajes claros
- Usuario informado del progreso

### 4. **Refresco "petado" después de inactividad**
✅ **Solucionado**:
- Sistema de reintentos previene que se quede colgado
- Banner visual informa del estado
- Botón de reintento manual disponible

### 5. **Mensajes y quests no se actualizan**
✅ **Solucionado**: 
- Refresco automático en múltiples eventos del lifecycle
- Throttling previene refrescos excesivos
- Método centralizado `refreshAllData()` garantiza consistencia

---

## 🧪 Testing Recomendado

### Escenarios a probar:

1. **Servidor lento:**
   - Abrir app con servidor dormido
   - Verificar que espera ~30s y muestra mensajes apropiados
   - Verificar que eventualmente conecta

2. **Sin conexión:**
   - Desactivar WiFi/datos
   - Intentar marcar checks → debe mostrar error
   - Activar conexión → debe reconectar automáticamente

3. **App en background:**
   - Minimizar app por 1+ hora
   - Reabrir → debe refrescar datos automáticamente
   - Verificar que contadores se actualizan

4. **Pull-to-refresh:**
   - Deslizar hacia abajo en HomeScreen
   - Verificar que refresca todo (user, messages, quests)

5. **Popups:**
   - Abrir popup de quest
   - Sin conexión: intentar marcar check → debe prevenir
   - Con conexión: marcar check → debe funcionar

---

## 📊 Monitoreo y Debug

Todos los cambios incluyen logs detallados:

```dart
// Ejemplos de logs:
🔄 [timestamp] [Main] App resumed - reloading data...
✅ [timestamp] [ConnectivityService] Login - Éxito en intento 1
❌ [timestamp] [ConnectivityService] Check Quest Detail - Error en intento 1: timeout
⏳ [timestamp] [ConnectivityService] Check Quest Detail - Reintentando en 2s...
🟠 [Auth Connection] Ping failed: timeout
```

Para debuggear problemas de conexión:
1. Buscar logs con `[ConnectivityService]`
2. Revisar número de intentos y tiempos
3. Verificar mensajes de lifecycle en `[Main]`

---

## 🎨 UI/UX Mejorada

### Feedback Visual:
- **Banner naranja**: "Problema de conexión. Reintentando..."
- **Banner rojo**: "Sin conexión. Verifica tu conexión a internet."
- **Popup preventivo**: "No se puede marcar el check sin conexión..."
- **Error descriptivo**: "El servidor puede estar arrancando (tarda ~30s)..."

### Acciones del Usuario:
- **Reintentar manualmente**: Botón en banner rojo
- **Pull-to-refresh**: Funciona en HomeScreen
- **Feedback inmediato**: Mensajes claros en cada acción

---

## 📝 Archivos Modificados

### Nuevos:
1. `lib/services/connectivity_service.dart`
2. `lib/widgets/connection_status_banner.dart`

### Modificados:
1. `lib/main.dart` - Lifecycle mejorado
2. `lib/controllers/auth_controller.dart` - ConnectivityService integrado
3. `lib/services/auth_service.dart` - Timeouts y reintentos
4. `lib/services/quest_service.dart` - Timeouts y reintentos
5. `lib/services/message_service.dart` - Timeouts y reintentos
6. `lib/utils/cookie_client.dart` - Timeout configurable
7. `lib/views/home/home_screen.dart` - Banner de conexión
8. `lib/widgets/quest_detail_popup.dart` - Verificación pre-acción
9. `lib/widgets/quest_form_popup.dart` - Verificación pre-acción

---

## ✅ Checklist de Funcionalidades

- [x] Timeouts largos (35s) para servidores lentos
- [x] Sistema de reintentos automáticos (3 intentos)
- [x] Backoff exponencial entre reintentos
- [x] Detección de estado de conexión en tiempo real
- [x] Banner visual de estado de conexión
- [x] Verificación pre-operación en acciones críticas
- [x] Refresco en resumed/inactive/hidden
- [x] Throttling de refrescos (3s)
- [x] Mensajes de error descriptivos
- [x] Botón de reintento manual
- [x] Logs detallados para debugging
- [x] Pull-to-refresh funcional
- [x] Refresco automático post-popups
- [x] Prevención de acciones sin conexión

---

## 🔮 Posibles Mejoras Futuras

1. **Offline Mode**: Guardar cambios localmente y sincronizar cuando haya conexión
2. **Progressive Loading**: Cargar datos parciales mientras se espera el resto
3. **WebSocket**: Conexión persistente para actualizaciones en tiempo real
4. **Retry Strategy Personalizada**: Diferentes estrategias según el tipo de operación
5. **Analytics**: Registrar patrones de fallo para identificar problemas del servidor

---

## 📞 Soporte

Si encuentras algún problema:
1. Revisa los logs de debug
2. Verifica el estado del banner de conexión
3. Prueba el botón "Reintentar"
4. Verifica que el servidor esté accesible

---

**Fecha de implementación:** 14 de Noviembre de 2025
**Versión:** 1.0.0+1
