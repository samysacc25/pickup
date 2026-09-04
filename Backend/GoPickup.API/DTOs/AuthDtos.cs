using System.ComponentModel.DataAnnotations;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.API.DTOs
{
    public class RegistroClienteDto
    {
        [Required, MaxLength(120)]
        public string NombreCompleto { get; set; } = string.Empty;

        [Required, EmailAddress]
        public string Correo { get; set; } = string.Empty;

        [Required, MaxLength(20)]
        public string Telefono { get; set; } = string.Empty;

        [Required, MinLength(6)]
        public string Clave { get; set; } = string.Empty;
    }

    public class SolicitudConductorDto
    {
        [Required, MaxLength(120)]
        public string NombreCompleto { get; set; } = string.Empty;

        [Required, EmailAddress]
        public string Correo { get; set; } = string.Empty;

        [Required, MaxLength(20)]
        public string Telefono { get; set; } = string.Empty;

        [Required, MinLength(6)]
        public string Clave { get; set; } = string.Empty;

        [Required, CedulaEcuatoriana]
        public string NumeroCedula { get; set; } = string.Empty;

        [Required]
        public TipoLicencia TipoLicencia { get; set; }

        [Required]
        public string Placa { get; set; } = string.Empty;

        [Required]
        public string Marca { get; set; } = string.Empty;

        [Required]
        public string Modelo { get; set; } = string.Empty;

        public string Color { get; set; } = string.Empty;

        public int Anio { get; set; }

        [Required]
        public TipoCamioneta TipoCamioneta { get; set; }

        public string? DescripcionCapacidad { get; set; }
    }

    public class LoginDto
    {
        [Required, EmailAddress]
        public string Correo { get; set; } = string.Empty;

        [Required]
        public string Clave { get; set; } = string.Empty;
    }

    public class AuthRespuestaDto
    {
        public string Token { get; set; } = string.Empty;
        public int UsuarioId { get; set; }
        public string NombreCompleto { get; set; } = string.Empty;
        public RolUsuario Rol { get; set; }
        public int? ConductorId { get; set; }
        public EstadoSolicitudConductor? EstadoSolicitudConductor { get; set; }
    }
}
