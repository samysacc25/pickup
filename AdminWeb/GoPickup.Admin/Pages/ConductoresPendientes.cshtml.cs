using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.Admin.Pages
{
    [Authorize]
    public class ConductoresPendientesModel : PageModel
    {
        private readonly ApplicationDbContext _db;
        private readonly IConfiguration _config;

        public ConductoresPendientesModel(ApplicationDbContext db, IConfiguration config)
        {
            _db = db;
            _config = config;
        }

        public List<Conductor> Pendientes { get; set; } = new();

        public string UrlFoto(string? rutaRelativa)
        {
            if (string.IsNullOrWhiteSpace(rutaRelativa))
                return "https://placehold.co/150x150?text=Sin+foto";

            var apiBaseUrl = _config["ApiBaseUrl"]?.TrimEnd('/') ?? "https://gopickup-bxf2eweba3b9d2ag.westus3-01.azurewebsites.net/api";
            return $"{apiBaseUrl}/{rutaRelativa}";
        }

        public async Task OnGetAsync()
        {
            Pendientes = await _db.Conductores
                .Include(c => c.Usuario)
                .Include(c => c.Vehiculo)
                .Where(c => c.EstadoSolicitud == EstadoSolicitudConductor.PendienteRevision)
                .OrderBy(c => c.Id)
                .ToListAsync();
        }

        public async Task<IActionResult> OnPostAprobarAsync(int id)
        {
            var conductor = await _db.Conductores.FindAsync(id);
            if (conductor is not null)
            {
                conductor.EstadoSolicitud = EstadoSolicitudConductor.Aprobada;
                conductor.FechaRevision = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
            return RedirectToPage();
        }

        public async Task<IActionResult> OnPostRechazarAsync(int id, string? motivo)
        {
            var conductor = await _db.Conductores.FindAsync(id);
            if (conductor is not null)
            {
                conductor.EstadoSolicitud = EstadoSolicitudConductor.Rechazada;
                conductor.MotivoRechazo = string.IsNullOrWhiteSpace(motivo) ? "No cumple los requisitos." : motivo;
                conductor.FechaRevision = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
            return RedirectToPage();
        }
    }
}
