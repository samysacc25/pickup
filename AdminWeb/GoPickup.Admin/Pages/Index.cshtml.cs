using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.Admin.Pages
{
    [Authorize]
    public class IndexModel : PageModel
    {
        private readonly ApplicationDbContext _db;

        public IndexModel(ApplicationDbContext db)
        {
            _db = db;
        }

        public int TotalClientes { get; set; }
        public int TotalConductores { get; set; }
        public int SolicitudesConductorPendientes { get; set; }
        public int ConductoresDisponibles { get; set; }
        public int SolicitudesHoy { get; set; }
        public int SolicitudesEnCurso { get; set; }
        public decimal IngresosHoy { get; set; }
        public List<Solicitud> UltimasSolicitudes { get; set; } = new();

        public async Task OnGetAsync()
        {
            var hoy = DateTime.UtcNow.Date;

            TotalClientes = await _db.Usuarios.CountAsync(u => u.Rol == RolUsuario.Cliente);
            TotalConductores = await _db.Conductores.CountAsync();
            SolicitudesConductorPendientes = await _db.Conductores.CountAsync(c => c.EstadoSolicitud == EstadoSolicitudConductor.PendienteRevision);
            ConductoresDisponibles = await _db.Conductores.CountAsync(c => c.Estado == EstadoConductor.Disponible);
            SolicitudesHoy = await _db.Solicitudes.CountAsync(s => s.FechaSolicitud.Date == hoy);
            SolicitudesEnCurso = await _db.Solicitudes.CountAsync(s =>
                s.Estado == EstadoSolicitud.Buscando || s.Estado == EstadoSolicitud.Aceptada ||
                s.Estado == EstadoSolicitud.EnCamino || s.Estado == EstadoSolicitud.Iniciada);
            IngresosHoy = await _db.Solicitudes
                .Where(s => s.FechaFin != null && s.FechaFin.Value.Date == hoy && s.TarifaFinal != null)
                .SumAsync(s => s.TarifaFinal) ?? 0;

            UltimasSolicitudes = await _db.Solicitudes
                .Include(s => s.Cliente)
                .Include(s => s.Conductor).ThenInclude(c => c!.Usuario)
                .OrderByDescending(s => s.FechaSolicitud)
                .Take(20)
                .ToListAsync();
        }
    }
}
