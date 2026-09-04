using System.ComponentModel.DataAnnotations;

namespace GoPickup.API.Models
{
    public class Conductor
    {
        public int Id { get; set; }

        public int UsuarioId { get; set; }
        public Usuario? Usuario { get; set; }

        [Required, MaxLength(10)]
        public string NumeroCedula { get; set; } = string.Empty;

        public TipoLicencia TipoLicencia { get; set; } = TipoLicencia.B;

        // Foto frontal de la licencia de conducir del conductor.
        public string? FotoLicenciaFrontalUrl { get; set; }

        public EstadoSolicitudConductor EstadoSolicitud { get; set; } = EstadoSolicitudConductor.PendienteRevision;
        public string? MotivoRechazo { get; set; }
        public DateTime? FechaRevision { get; set; }

        public bool Verificado => EstadoSolicitud == EstadoSolicitudConductor.Aprobada;

        public EstadoConductor Estado { get; set; } = EstadoConductor.Desconectado;

        public double? UltimaLatitud { get; set; }
        public double? UltimaLongitud { get; set; }
        public DateTime? UltimaActualizacionUbicacion { get; set; }

        public double CalificacionPromedio { get; set; } = 5.0;

        public Vehiculo? Vehiculo { get; set; }
        public ICollection<Solicitud> SolicitudesComoConductor { get; set; } = new List<Solicitud>();
    }
}
