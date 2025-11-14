# Sistema Uniforme de Refrescos

## 🎯 Objetivo

Garantizar que **siempre** se carguen de forma consistente y en el orden correcto:
1. **Datos del usuario** (perfil, XP, nivel)
2. **Mensajes**
3. **Quests**

## 🔧 Implementación

### Método Centralizado: `AuthController.refreshAllData()`

Se ha creado un método centralizado en `AuthController` que garantiza que todos los datos se refresquen de forma uniforme:

```dart
Future<void> refreshAllData({
  required dynamic messageController,
  required dynamic questController,
}) async
```

Este método:
1. ✅ Verifica la conexión al backend
2. ✅ Refresca el perfil del usuario (XP, nivel, etc.)
3. ✅ Carga los mensajes
4. ✅ Carga las quests
5. ✅ Maneja errores de forma individual sin fallar completamente

## 📍 Dónde se Usa

El método `refreshAllData()` se llama automáticamente en:

### 1. **Reactivación de la app** (`main.dart`)
Cuando el usuario regresa a la app después de tenerla en segundo plano:
```dart
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    await auth.refreshAllData(
      messageController: mc,
      questController: qc,
    );
  }
}
```

### 2. **Pull-to-refresh** (`home_screen.dart`)
Cuando el usuario desliza hacia abajo para refrescar:
```dart
Future<void> _refreshData() async {
  await auth.refreshAllData(
    messageController: mc,
    questController: qc,
  );
  await _processPopups();
}
```

### 3. **Carga inicial** (`home_screen.dart`)
Cuando se carga la pantalla principal por primera vez:
```dart
Future<void> _initializeHomeScreen() async {
  await auth.refreshAllData(
    messageController: mc,
    questController: qc,
  );
  await _processPopups();
}
```

### 4. **Después de completar una quest** (`active_quests_panel.dart`)
Cuando el usuario completa una quest:
```dart
if (completed) {
  await auth.refreshAllData(
    messageController: mc,
    questController: qc,
  );
  await CoordinatedPopupsHandler.processAllPopups(context, mc, qc);
}
```

### 5. **Después de procesar popups** (`home_screen.dart`)
Cuando se procesan popups de recompensas:
```dart
if (processedAny) {
  await auth.refreshAllData(
    messageController: mc,
    questController: qc,
  );
}
```

## ✅ Ventajas

1. **Consistencia**: Todos los refrescos siguen el mismo flujo
2. **Orden garantizado**: Siempre se cargan en el mismo orden (usuario → mensajes → quests)
3. **Manejo de errores**: Si falla uno, los demás continúan
4. **Fácil mantenimiento**: Un solo lugar para modificar la lógica de refrescos
5. **Logs uniformes**: Todos los refrescos tienen el mismo formato de logs para debugging

## 🚫 Lo que NO debes hacer

❌ **NO** llames directamente a:
- `messageController.loadMessages()`
- `questController.loadQuests()`
- `userController.refreshProfile()`

✅ **SÍ** usa siempre:
- `authController.refreshAllData(messageController: mc, questController: qc)`

## 🐛 Debugging

El sistema incluye logs detallados que te ayudarán a diagnosticar problemas:

```
🔄 [HH:MM:SS] [Auth.refreshAllData] Iniciando refresco completo de datos...
✅ [HH:MM:SS] [Auth.refreshAllData] Perfil actualizado
✅ [HH:MM:SS] [Auth.refreshAllData] Mensajes cargados
✅ [HH:MM:SS] [Auth.refreshAllData] Quests cargadas
✅ [HH:MM:SS] [Auth.refreshAllData] Refresco completo finalizado
```

Si algo falla, verás logs específicos:
```
❌ [HH:MM:SS] [Auth.refreshAllData] Error actualizando perfil: <detalle>
❌ [HH:MM:SS] [Auth.refreshAllData] Error cargando mensajes: <detalle>
❌ [HH:MM:SS] [Auth.refreshAllData] Error cargando quests: <detalle>
```

## 🔄 Flujo Completo

```
Usuario regresa a la app
        ↓
didChangeAppLifecycleState(resumed)
        ↓
auth.refreshAllData()
        ↓
    ┌───────────────────────┐
    │ 1. Verificar conexión │
    └───────────┬───────────┘
                ↓
    ┌───────────────────────┐
    │ 2. Refrescar perfil   │
    │    (XP, nivel, etc.)  │
    └───────────┬───────────┘
                ↓
    ┌───────────────────────┐
    │ 3. Cargar mensajes    │
    └───────────┬───────────┘
                ↓
    ┌───────────────────────┐
    │ 4. Cargar quests      │
    └───────────┬───────────┘
                ↓
        ✅ Datos actualizados
        ✅ UI se refresca automáticamente
```

## 📝 Notas Adicionales

- El método es **asíncrono** y debe usarse con `await`
- **No bloquea la UI**: Los errores se manejan internamente
- **Tolerante a fallos**: Si falla un paso, los demás continúan
- **Verifica autenticación**: Solo se ejecuta si el usuario está autenticado
