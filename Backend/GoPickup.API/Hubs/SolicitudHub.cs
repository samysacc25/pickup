using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.API.Hubs
{
    // [Authorize] obliga a que la conexión traiga un JWT válido (Program.cs ya
    // acepta el token como ?access_token= en la URL para las rutas /hubs, que
    // es justo como se conecta la app). Antes este Hub no tenía NINGÚN control
    // de acceso: cualquiera, sin sesión, podía conectarse y llamar a sus
    // métodos con cualquier ID -- espiar la ubicación y el chat de viajes
    // ajenos, ver los datos de clientes que llegan por
    // "conductores-disponibles", o inyectar mensajes de chat falsos.
    [Authorize]
    public class SolicitudHub : Hub
    {
        private readonly ApplicationDbContext _db;

        public SolicitudHub(ApplicationDbContext db)
        {
            _db = db;
        }

        private int UsuarioIdActual => int.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);

        private int? ConductorIdActual =>
            int.TryParse(Context.User!.FindFirstValue("ConductorId"), out var id) ? id : null;

        // Verifica que quien llama sea el cliente o el conductor de ESA
        // solicitud en particular -- antes con estar autenticado alcanzaba
        // para unirse al grupo de cualquier ID y recibir su ubicación/chat.
        private async Task<bool> EsParticipanteAsync(int solicitudId)
        {
            var solicitud = await _db.Solicitudes.AsNoTracking()
                .Where(s => s.Id == solicitudId)
                .Select(s => new { s.ClienteId, s.ConductorId })
                .FirstOrDefaultAsync();
            if (solicitud is null) return false;

            if (Context.User!.IsInRole("Cliente") && solicitud.ClienteId == UsuarioIdActual) return true;
            if (Context.User!.IsInRole("Conductor") && solicitud.ConductorId is not null && solicitud.ConductorId == ConductorIdActual) return true;
            return false;
        }

        public async Task UnirseASolicitud(int solicitudId)
        {
            if (!await EsParticipanteAsync(solicitudId)) return;
            await Groups.AddToGroupAsync(Context.ConnectionId, $"solicitud-{solicitudId}");
        }

        public async Task SalirDeSolicitud(int solicitudId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"solicitud-{solicitudId}");
        }

        public async Task UnirseComoConductorDisponible()
        {
            if (!Context.User!.IsInRole("Conductor")) return;

            await Groups.AddToGroupAsync(Context.ConnectionId, "conductores-disponibles");

            // Grupo propio de cada conductor: por aquí le llegan los avisos
            // que son solo para él (si el cliente aceptó o rechazó el precio
            // que ofertó), sin exponerlos al resto de conductores.
            if (ConductorIdActual is int conductorId)
                await Groups.AddToGroupAsync(Context.ConnectionId, $"conductor-{conductorId}");
        }

        public async Task SalirComoConductorDisponible()
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, "conductores-disponibles");

            if (ConductorIdActual is int conductorId)
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"conductor-{conductorId}");
        }

        public async Task EnviarUbicacionConductor(int solicitudId, double lat, double lon)
        {
            // Solo el conductor ASIGNADO a esta solicitud puede reportar su
            // ubicación en ella -- antes cualquiera podía enviar coordenadas
            // falsas a un viaje ajeno y el cliente las veía como reales.
            if (!Context.User!.IsInRole("Conductor")) return;
            var solicitud = await _db.Solicitudes.AsNoTracking()
                .Where(s => s.Id == solicitudId)
                .Select(s => new { s.ConductorId })
                .FirstOrDefaultAsync();
            if (solicitud is null || solicitud.ConductorId != ConductorIdActual) return;

            await Clients.Group($"solicitud-{solicitudId}").SendAsync("ubicacionConductorActualizada", lat, lon);
        }

        // Chat interno entre cliente y conductor: se retransmite en vivo por
        // este Hub y además se guarda mientras la solicitud sigue activa (se
        // borra al finalizar/cancelarse, ver SolicitudesController), para que
        // sobreviva si alguno de los dos cierra la pantalla del chat o
        // navega fuera y vuelve a entrar.
        public async Task EnviarMensajeChat(int solicitudId, string remitente, string mensaje)
        {
            if (!await EsParticipanteAsync(solicitudId)) return;
            if (string.IsNullOrWhiteSpace(mensaje)) return;

            // El remitente se calcula del lado del servidor según el rol real
            // de quien llama -- antes se confiaba ciegamente en el string que
            // mandaba el cliente, así que alguien podía hacerse pasar por el
            // conductor (o el cliente) escribiendo el valor que quisiera.
            var remitenteReal = Context.User!.IsInRole("Conductor") ? "conductor" : "cliente";
            var fecha = DateTime.UtcNow;

            _db.MensajesChat.Add(new MensajeChatSolicitud { SolicitudId = solicitudId, Remitente = remitenteReal, Texto = mensaje, Fecha = fecha });
            await _db.SaveChangesAsync();

            await Clients.OthersInGroup($"solicitud-{solicitudId}")
                .SendAsync("mensajeChatRecibido", remitenteReal, mensaje, fecha.ToString("o"));
        }
    }
}
