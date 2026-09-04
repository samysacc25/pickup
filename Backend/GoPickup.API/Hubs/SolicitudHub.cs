using Microsoft.AspNetCore.SignalR;

namespace GoPickup.API.Hubs
{
    public class SolicitudHub : Hub
    {
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

        // Chat interno entre cliente y conductor: el mensaje SOLO se retransmite
        // en vivo por este Hub, nunca se guarda en la base de datos ni en ningún
        // otro lugar del servidor. Si nadie está conectado al grupo en ese
        // momento, el mensaje simplemente se pierde (no hay historial).
        public async Task EnviarMensajeChat(int solicitudId, string remitente, string mensaje)
        {
            await Clients.OthersInGroup($"solicitud-{solicitudId}")
                .SendAsync("mensajeChatRecibido", remitente, mensaje, DateTime.UtcNow.ToString("o"));
        }
    }
}
