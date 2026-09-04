# 🟢 Go Pickup

Plataforma de transporte de personas y carga mixta con camionetas en la
provincia de Tungurahua.

```
GoPickupProyecto/
├── GoPickup.sln
├── Backend/GoPickup.API/          → API REST + SignalR
├── AdminWeb/GoPickup.Admin/       → Panel web de administración
└── MobileApp/go_pickup/           → App Flutter (clientes y conductores)
```

## Últimos 7 ajustes incluidos en esta versión

1. **Tarifa**: `$0.50 por km` (solo pasajero) o `$0.80 por km` (con carga adicional) — sin tarifa base fija
2. **Recargo por cancelación**: si el cliente cancela después de que un conductor ya aceptó, se le cobra `$0.40` automáticamente en su **próxima** solicitud
3. **Foto frontal de la licencia** de conducir, obligatoria en el registro de conductor
4. **Nombre de calle real** al elegir ubicación (ya no muestra "Plus Codes" tipo `Q99H+FX2`)
5. **Ícono de camioneta** 🚚 en el mapa para ver en tiempo real dónde está el conductor
6. **Notificación push automática** cuando el conductor está a menos de 150 m del punto de recogida
7. **Chat interno** entre cliente y conductor — se retransmite en vivo por SignalR y **nunca se guarda** en la base de datos ni en el celular

---

## 1. Requisitos previos

| Herramienta | Versión sugerida |
|---|---|
| .NET SDK | 8.0 |
| SQL Server | 2019+ |
| Flutter SDK | 3.22+ |
| Cuenta de Google Cloud (Maps SDK, Places API, Geocoding API) | — |
| Cuenta de Firebase (opcional, para push) | — |
| Cuenta de Twilio (opcional, para SMS real) | — |

---

## 2. Backend (GoPickup.API) — pasos para correr en local

```bash
cd Backend/GoPickup.API
dotnet restore
```

### 2.1 Configura appsettings.json
- `ConnectionStrings:DefaultConnection`: tu SQL Server local
- `Jwt:Key`: cambia por una clave propia de al menos 32 caracteres
- `Tarifas:TarifaPorKmSinCarga` / `TarifaPorKmConCarga`: ya vienen en 0.50 y 0.80
- `Twilio` y `Firebase`: pueden quedar vacíos para desarrollo (ver notas abajo)

### 2.2 Crea la base de datos

```bash
dotnet tool install --global dotnet-ef   # solo la primera vez
dotnet ef migrations add InicialCompleta
dotnet ef database update
```

> Si ya tenías una base de datos de una versión anterior sin estos campos
> nuevos (`RecargoPendiente`, `RecargoAplicado`, `FotoLicenciaFrontalUrl`,
> `NotificadoLlegada`), es más simple borrarla y crearla de cero con los
> comandos de arriba.

### 2.3 Ejecuta la API

```bash
dotnet run
```

Debe quedar escuchando en `http://localhost:5236` (puerto fijo por
`Properties/launchSettings.json`). Swagger disponible en `/swagger`.

Usuario administrador creado automáticamente:
- Correo: `admin@gopickup.com`
- Contraseña: `Admin123!`

---

## 3. Web de Administración (GoPickup.Admin)

```bash
cd AdminWeb/GoPickup.Admin
dotnet restore
dotnet run
```

Usa la misma cadena de conexión que el backend en su propio `appsettings.json`,
más `ApiBaseUrl` apuntando a donde corra el backend (para mostrar las fotos).

Incluye:
- Dashboard con estadísticas
- **Solicitudes de conductores**: aprobación con vista de las 4 fotos (3 del vehículo + licencia)
- Listado de conductores, clientes (con su recargo pendiente visible), y envíos

---

## 4. App móvil (Flutter)

```bash
cd MobileApp/go_pickup
flutter pub get
```

### 4.1 Configura la URL del backend

Edita `lib/config/api_config.dart` con la URL real de tu backend (local o publicado).

### 4.2 Configura Google Maps

Habilita en Google Cloud Console: **Maps SDK for Android**, **Places API**,
**Geocoding API**. Pega tu API Key en:
- `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
- `lib/config/api_config.dart` (`googlePlacesApiKey`)

### 4.3 Ejecuta la app

```bash
flutter run
```

---

## 5. Configuración opcional: Firebase (push) y Twilio (SMS)

Ambas son **opcionales para desarrollo local** — la app y el backend funcionan
sin ellas:

- **Sin Firebase configurado**: no llegan notificaciones push, pero el resto
  de la app funciona normal.
- **Sin Twilio configurado**: el backend corriendo en modo `Development`
  muestra el código de verificación directo en la app (recuadro amarillo
  "modo desarrollo"), así puedes probar el registro sin gastar en SMS reales.

Para configurarlas en serio, revisa los comentarios en:
- `Backend/GoPickup.API/Services/FirebasePushNotificationService.cs`
- `Backend/GoPickup.API/Services/TwilioSmsService.cs`
- `Backend/GoPickup.API/appsettings.json` (secciones `Firebase` y `Twilio`)

---

## 6. Notas importantes

- El pago **no se procesa dentro de la app** — es coordinación entre cliente
  y conductor (efectivo, transferencia o DeUna).
- El chat interno **no persiste mensajes en ningún lado**: si cierras la
  pantalla de chat, el historial se pierde (por diseño, a pedido).
- Las fotos se guardan en `Backend/GoPickup.API/wwwroot/uploads/`.
- Antes de producción: revisa HTTPS real, restricción de la API Key de Maps,
  políticas de privacidad, y cambia `ASPNETCORE_ENVIRONMENT` a `Production`
  (esto desactiva el atajo de código SMS de desarrollo).
