using GoPickup.API.Models;

namespace GoPickup.API.DTOs
{
    public class CambiarEstadoConductorDto
    {
        public EstadoConductor Estado { get; set; }
    }

    public class ConductorResumenDto
    {
        public int Id { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public string Placa { get; set; } = string.Empty;
        public TipoCamioneta TipoCamioneta { get; set; }
        public double CalificacionPromedio { get; set; }
        public EstadoConductor Estado { get; set; }
        public EstadoSolicitudConductor EstadoSolicitud { get; set; }
        public double? Latitud { get; set; }
        public double? Longitud { get; set; }
    }

    public class RevisarSolicitudConductorDto
    {
        public bool Aprobar { get; set; }
        public string? MotivoRechazo { get; set; }
    }
}
