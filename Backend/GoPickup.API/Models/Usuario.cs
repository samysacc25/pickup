using System.ComponentModel.DataAnnotations;

namespace GoPickup.API.Models
{
    public class Usuario
    {
        public int Id { get; set; }

        [Required, MaxLength(120)]
        public string NombreCompleto { get; set; } = string.Empty;

        [Required, MaxLength(150)]
        public string Correo { get; set; } = string.Empty;

        [Required, MaxLength(20)]
        public string Telefono { get; set; } = string.Empty;

        [Required]
        public string ClaveHash { get; set; } = string.Empty;

        public RolUsuario Rol { get; set; } = RolUsuario.Cliente;

        public bool Activo { get; set; } = true;

        public string? FotoPerfilUrl { get; set; }

        public bool TelefonoVerificado { get; set; }

        public string? TokenPushNotificacion { get; set; }

        // Recargo pendiente por cancelación (ej. $0.40) que se cobra en la
        // PRÓXIMA solicitud del cliente, ya que no se puede cobrar de inmediato
        // (el pago es en efectivo/transferencia entre cliente y conductor).
        public decimal RecargoPendiente { get; set; }

        public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;

        public Conductor? PerfilConductor { get; set; }
        public ICollection<Solicitud> SolicitudesComoCliente { get; set; } = new List<Solicitud>();
    }
}
