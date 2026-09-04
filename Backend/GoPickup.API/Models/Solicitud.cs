namespace GoPickup.API.Models
{
    public class Solicitud
    {
        public int Id { get; set; }

        public int ClienteId { get; set; }
        public Usuario? Cliente { get; set; }

        public int? ConductorId { get; set; }
        public Conductor? Conductor { get; set; }

        public double OrigenLatitud { get; set; }
        public double OrigenLongitud { get; set; }
        public string OrigenDireccion { get; set; } = string.Empty;

        public double DestinoLatitud { get; set; }
        public double DestinoLongitud { get; set; }
        public string DestinoDireccion { get; set; } = string.Empty;

        public string? DescripcionCarga { get; set; }
        public bool LlevaCarga { get; set; }

        public bool EsInterprovincial { get; set; }

        public TipoCamioneta TipoCamionetaRequerida { get; set; } = TipoCamioneta.Pequena;

        public EstadoSolicitud Estado { get; set; } = EstadoSolicitud.Buscando;

        public decimal TarifaSugerida { get; set; }
        public decimal? TarifaPropuestaCliente { get; set; }
        public decimal? TarifaAcordada { get; set; }
        public decimal? TarifaFinal { get; set; }

        // Recargo por cancelación de una carrera anterior, aplicado aquí (ej. $0.40)
        public decimal? RecargoAplicado { get; set; }

        public MetodoPago MetodoPago { get; set; } = MetodoPago.Efectivo;

        public double? DistanciaKm { get; set; }
        public int? DuracionEstimadaMin { get; set; }

        public int? CalificacionConductor { get; set; }
        public int? CalificacionCliente { get; set; }

        // Evita notificar la llegada del conductor más de una vez al cliente.
        public bool NotificadoLlegada { get; set; }

        public DateTime FechaSolicitud { get; set; } = DateTime.UtcNow;
        public DateTime? FechaAceptacion { get; set; }
        public DateTime? FechaInicio { get; set; }
        public DateTime? FechaFin { get; set; }
        public DateTime? FechaCancelacion { get; set; }
        public string? MotivoCancelacion { get; set; }
    }
}
