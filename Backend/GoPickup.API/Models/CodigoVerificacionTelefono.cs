namespace GoPickup.API.Models
{
    public class CodigoVerificacionTelefono
    {
        public int Id { get; set; }
        public string Telefono { get; set; } = string.Empty;
        public string Codigo { get; set; } = string.Empty;
        public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
        public DateTime FechaExpiracion { get; set; }
        public bool Verificado { get; set; }
        public DateTime? FechaVerificacion { get; set; }
        public int Intentos { get; set; }
    }
}
