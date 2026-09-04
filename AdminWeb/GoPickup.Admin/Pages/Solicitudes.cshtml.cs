using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.Admin.Pages
{
    [Authorize]
    public class SolicitudesModel : PageModel
    {
        private readonly ApplicationDbContext _db;

        public SolicitudesModel(ApplicationDbContext db)
        {
            _db = db;
        }

        public List<Solicitud> Solicitudes { get; set; } = new();

        public async Task OnGetAsync()
        {
            Solicitudes = await _db.Solicitudes
                .Include(s => s.Cliente)
                .Include(s => s.Conductor).ThenInclude(c => c!.Usuario)
                .OrderByDescending(s => s.FechaSolicitud)
                .Take(100)
                .ToListAsync();
        }
    }
}
