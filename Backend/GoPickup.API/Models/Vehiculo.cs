using System.ComponentModel.DataAnnotations;

namespace GoPickup.API.Models
{
    public class Vehiculo
    {
        public int Id { get; set; }

        [Required, MaxLength(10)]
        public string Placa { get; set; } = string.Empty;

        [Required, MaxLength(60)]
        public string Marca { get; set; } = string.Empty;

        [Required, MaxLength(60)]
        public string Modelo { get; set; } = string.Empty;

        [MaxLength(30)]
        public string Color { get; set; } = string.Empty;

        public int Anio { get; set; }

        public TipoCamioneta TipoCamioneta { get; set; } = TipoCamioneta.Pequena;

        [MaxLength(150)]
        public string? DescripcionCapacidad { get; set; }

        public string? FotoLateralUrl { get; set; }
        public string? FotoFrontalUrl { get; set; }
        public string? FotoCabinaUrl { get; set; }

        public int ConductorId { get; set; }
        public Conductor? Conductor { get; set; }
    }
}
