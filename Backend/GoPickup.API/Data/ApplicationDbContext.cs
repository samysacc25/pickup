using Microsoft.EntityFrameworkCore;
using GoPickup.API.Models;

namespace GoPickup.API.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

        public DbSet<Usuario> Usuarios => Set<Usuario>();
        public DbSet<Conductor> Conductores => Set<Conductor>();
        public DbSet<Vehiculo> Vehiculos => Set<Vehiculo>();
        public DbSet<Solicitud> Solicitudes => Set<Solicitud>();
        public DbSet<CodigoVerificacionTelefono> CodigosVerificacionTelefono => Set<CodigoVerificacionTelefono>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Usuario>().HasIndex(u => u.Correo).IsUnique();
            modelBuilder.Entity<Usuario>().Property(u => u.RecargoPendiente).HasColumnType("decimal(10,2)");

            modelBuilder.Entity<Conductor>()
                .HasOne(c => c.Usuario)
                .WithOne(u => u.PerfilConductor)
                .HasForeignKey<Conductor>(c => c.UsuarioId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Vehiculo>()
                .HasOne(v => v.Conductor)
                .WithOne(c => c.Vehiculo)
                .HasForeignKey<Vehiculo>(v => v.ConductorId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Vehiculo>().HasIndex(v => v.Placa).IsUnique();

            modelBuilder.Entity<Solicitud>()
                .HasOne(s => s.Cliente)
                .WithMany(u => u.SolicitudesComoCliente)
                .HasForeignKey(s => s.ClienteId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Solicitud>()
                .HasOne(s => s.Conductor)
                .WithMany(c => c.SolicitudesComoConductor)
                .HasForeignKey(s => s.ConductorId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Solicitud>().Property(s => s.TarifaSugerida).HasColumnType("decimal(10,2)");
            modelBuilder.Entity<Solicitud>().Property(s => s.TarifaPropuestaCliente).HasColumnType("decimal(10,2)");
            modelBuilder.Entity<Solicitud>().Property(s => s.TarifaAcordada).HasColumnType("decimal(10,2)");
            modelBuilder.Entity<Solicitud>().Property(s => s.TarifaFinal).HasColumnType("decimal(10,2)");
            modelBuilder.Entity<Solicitud>().Property(s => s.RecargoAplicado).HasColumnType("decimal(10,2)");
        }
    }
}
