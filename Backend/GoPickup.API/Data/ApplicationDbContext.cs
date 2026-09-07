using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
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
        public DbSet<MensajeChatSolicitud> MensajesChat => Set<MensajeChatSolicitud>();

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

            modelBuilder.Entity<MensajeChatSolicitud>()
                .HasOne(m => m.Solicitud)
                .WithMany()
                .HasForeignKey(m => m.SolicitudId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<MensajeChatSolicitud>().HasIndex(m => m.SolicitudId);

            // SQL Server no guarda la zona horaria de un DateTime: aunque se
            // guarde con DateTime.UtcNow, al leerlo de vuelta EF Core lo
            // entrega como Kind=Unspecified. Eso hacía que el JSON de la API
            // no incluyera la "Z" de UTC, y la app (Flutter) interpretaba esa
            // fecha como si ya fuera la hora local del celular en vez de
            // convertirla -- por eso las fechas/horas se veían adelantadas
            // (la diferencia entre UTC y Ecuador, 5 horas). Este converter
            // fuerza Kind=Utc en toda columna DateTime al leerla de la base,
            // para que el celular pueda calcular la hora de Ecuador bien.
            var conversorUtc = new ValueConverter<DateTime, DateTime>(
                v => v,
                v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
            var conversorUtcNulo = new ValueConverter<DateTime?, DateTime?>(
                v => v,
                v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : v);

            foreach (var entityType in modelBuilder.Model.GetEntityTypes())
            {
                foreach (var property in entityType.GetProperties())
                {
                    if (property.ClrType == typeof(DateTime))
                        property.SetValueConverter(conversorUtc);
                    else if (property.ClrType == typeof(DateTime?))
                        property.SetValueConverter(conversorUtcNulo);
                }
            }
        }
    }
}
