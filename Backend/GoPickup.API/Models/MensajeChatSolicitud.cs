namespace GoPickup.API.Models
{
    // Historial de chat de una solicitud, guardado SOLO mientras el servicio
    // está activo. Antes el chat vivía solo en memoria del celular y se
    // perdía si el usuario cerraba la pantalla o navegaba fuera; ahora queda
    // aquí hasta que la solicitud finaliza o se cancela, momento en el que se
    // borra (ver SolicitudesController.FinalizarSolicitud / CancelarSolicitud).
    public class MensajeChatSolicitud
    {
        public int Id { get; set; }

        public int SolicitudId { get; set; }
        public Solicitud? Solicitud { get; set; }

        public string Remitente { get; set; } = string.Empty; // "cliente" o "conductor"
        public string Texto { get; set; } = string.Empty;

        public DateTime Fecha { get; set; } = DateTime.UtcNow;
    }
}
