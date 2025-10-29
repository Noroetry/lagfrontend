# Guía de Pruebas Manuales - Autenticación

## Prueba de Persistencia de Sesión

### Pasos para Testing Manual

1. **Registro de Usuario Nuevo**:
   ```
   - Abrir la aplicación
   - Ir a la pantalla de registro
   - Crear una cuenta con:
     * Username: test_user
     * Email: test@example.com
     * Password: test123!
   ```
   ✓ Deberías ver logs indicando que se guardó un token

2. **Verificar Persistencia**:
   ```
   - Cerrar completamente la aplicación
   - Volver a abrir la aplicación
   ```
   ✓ Deberías entrar directamente sin necesidad de login
   ✓ Los logs mostrarán "Token encontrado: ..."

3. **Verificar Expiración**:
   ```
   - Con la sesión activa, esperar a que expire el token (15 minutos)
   - Intentar acceder a la lista de usuarios u otra ruta protegida
   ```
   ✓ Deberías ver logs de error 401
   ✓ La app debería volver a la pantalla de login
   ✓ Los logs mostrarán que el token fue borrado

4. **Verificar Logout**:
   ```
   - Hacer login con las credenciales anteriores
   - Realizar logout manualmente
   ```
   ✓ Deberías volver a la pantalla de login
   ✓ Al reiniciar la app, debería pedir credenciales

### Identificar Logs Importantes

Los logs usan emojis para facilitar el seguimiento:
- 🔐 [Auth Check] - Verificación inicial de token
- 🔑 [Auth Headers] - Uso del token en peticiones
- ⚠️ [Auth Error] - Errores de autenticación
- 🗑️ [Auth Error] - Borrado de token

### Comportamiento Esperado

1. **Al Iniciar**:
   - Si hay token válido: Entrada directa a la app
   - Si no hay token: Pantalla de login

2. **En Peticiones**:
   - Todas las rutas protegidas deben incluir el token
   - Error 401 debe borrar el token y redirigir a login

3. **Al Cerrar Sesión**:
   - El token debe eliminarse del storage
   - La próxima apertura debe requerir login

### Resolución de Problemas

Si los tests fallan, verificar:
1. La conexión con el backend (URL correcta)
2. Los permisos de almacenamiento en el dispositivo
3. La validez del token (formato JWT correcto)
4. Los logs en la consola para identificar el punto de fallo