namespace GoPickup.API.Models
{
    // Contraoferta de precio de un conductor sobre una solicitud que sigue
    // en estado "Buscando". El cliente ve todas las ofertas recibidas y
    // decide cuál acepta (o las rechaza) -- al aceptar una, esa oferta
    // define la tarifa acordada y ese conductor queda asignado al viaje.
    //
    // Se usa una tabla aparte (en vez de columnas en Solicitud) para que
    // varios conductores puedan ofertar a la vez sobre la misma solicitud
    // sin bloquearse entre ellos, y para que la solicitud nunca quede
    // "trabada" esperando la respuesta del cliente a un solo conductor.
    public class OfertaSolicitud
    {
        public int Id { get; set; }

        public int SolicitudId { get; set; }
        public Solicitud? Solicitud { get; set; }

        public int ConductorId { get; set; }
        public Conductor? Conductor { get; set; }

        public decimal Monto { get; set; }

        public EstadoOferta Estado { get; set; } = EstadoOferta.Pendiente;

        // Ubicación del conductor al momento de ofertar, para poder mostrarle
        // al cliente a qué distancia está y en cuánto tiempo llegaría.
        public double? ConductorLatitud { get; set; }
        public double? ConductorLongitud { get; set; }

        public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
        public DateTime? FechaRespuesta { get; set; }
    }
}
