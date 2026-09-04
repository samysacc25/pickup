using System.ComponentModel.DataAnnotations;
using GoPickup.API.Models;

namespace GoPickup.API.DTOs
{
    public class CrearSolicitudDto
    {
        [Required]
        public double OrigenLatitud { get; set; }
        [Required]
        public double OrigenLongitud { get; set; }
        [Required]
        public string OrigenDireccion { get; set; } = string.Empty;

        [Required]
        public double DestinoLatitud { get; set; }
        [Required]
        public double DestinoLongitud { get; set; }
        [Required]
        public string DestinoDireccion { get; set; } = string.Empty;

        public string? DescripcionCarga { get; set; }
        public bool LlevaCarga { get; set; }

        public TipoCamioneta TipoCamionetaRequerida { get; set; } = TipoCamioneta.Pequena;
        public MetodoPago MetodoPago { get; set; } = MetodoPago.Efectivo;
        public decimal? TarifaPropuesta { get; set; }
    }

    public class ActualizarUbicacionDto
    {
        [Required]
        public double Latitud { get; set; }
        [Required]
        public double Longitud { get; set; }
    }

    public class CalificarSolicitudDto
    {
        [Range(1, 5)]
        public int Calificacion { get; set; }
    }

    public class CancelarSolicitudDto
    {
        public string? Motivo { get; set; }
    }

    // Un mensaje de chat NO se guarda en base de datos: solo viaja en vivo
    // por SignalR entre cliente y conductor mientras dure la solicitud.
    public class EnviarMensajeChatDto
    {
        [Required, MaxLength(500)]
        public string Mensaje { get; set; } = string.Empty;
    }

    public class SolicitudRespuestaDto
    {
        public int Id { get; set; }
        public EstadoSolicitud Estado { get; set; }

        public string ClienteNombre { get; set; } = string.Empty;
        public string? ClienteTelefono { get; set; }

        public int? ConductorId { get; set; }
        public string? ConductorNombre { get; set; }
        public string? ConductorTelefono { get; set; }
        public string? VehiculoPlaca { get; set; }
        public string? VehiculoDescripcion { get; set; }
        public TipoCamioneta? VehiculoTipo { get; set; }
        public double? ConductorLatitud { get; set; }
        public double? ConductorLongitud { get; set; }

        public double OrigenLatitud { get; set; }
        public double OrigenLongitud { get; set; }
        public string OrigenDireccion { get; set; } = string.Empty;

        public double DestinoLatitud { get; set; }
        public double DestinoLongitud { get; set; }
        public string DestinoDireccion { get; set; } = string.Empty;

        public string? DescripcionCarga { get; set; }
        public bool LlevaCarga { get; set; }
        public bool EsInterprovincial { get; set; }
        public TipoCamioneta TipoCamionetaRequerida { get; set; }
        public MetodoPago MetodoPago { get; set; }

        public decimal TarifaSugerida { get; set; }
        public decimal? TarifaPropuestaCliente { get; set; }
        public decimal? TarifaAcordada { get; set; }
        public decimal? TarifaFinal { get; set; }
        public decimal? RecargoAplicado { get; set; }
        public double? DistanciaKm { get; set; }
        public int? DuracionEstimadaMin { get; set; }

        public DateTime FechaSolicitud { get; set; }
        public DateTime? FechaFin { get; set; }
    }
}
