using Microsoft.AspNetCore.SignalR;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.API.Hubs
{
    public class SolicitudHub : Hub
    {
        private readonly ApplicationDbContext _db;

        public SolicitudHub(ApplicationDbContext db)
        {
            _db = db;
        }

        public async Task UnirseASolicitud(int solicitudId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"solicitud-{solicitudId}");
        }

        public async Task SalirDeSolicitud(int solicitudId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"solicitud-{solicitudId}");
        }

        public async Task UnirseComoConductorDisponible()
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, "conductores-disponibles");
        }

        public async Task SalirComoConductorDisponible()
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, "conductores-disponibles");
        }

        public async Task EnviarUbicacionConductor(int solicitudId, double lat, double lon)
        {
            await Clients.Group($"solicitud-{solicitudId}").SendAsync("ubicacionConductorActualizada", lat, lon);
        }

        // Chat interno entre cliente y conductor: se retransmite en vivo por
        // este Hub y además se guarda mientras la solicitud sigue activa (se
        // borra al finalizar/cancelarse, ver SolicitudesController), para que
        // sobreviva si alguno de los dos cierra la pantalla del chat o
        // navega fuera y vuelve a entrar.
        public async Task EnviarMensajeChat(int solicitudId, string remitente, string mensaje)
        {
            var fecha = DateTime.UtcNow;

            _db.MensajesChat.Add(new MensajeChatSolicitud { SolicitudId = solicitudId, Remitente = remitente, Texto = mensaje, Fecha = fecha });
            await _db.SaveChangesAsync();

            await Clients.OthersInGroup($"solicitud-{solicitudId}")
                .SendAsync("mensajeChatRecibido", remitente, mensaje, fecha.ToString("o"));
        }
    }
}
