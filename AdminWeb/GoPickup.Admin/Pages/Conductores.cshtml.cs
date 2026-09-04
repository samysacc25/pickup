using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.Admin.Pages
{
    [Authorize]
    public class ConductoresModel : PageModel
    {
        private readonly ApplicationDbContext _db;

        public ConductoresModel(ApplicationDbContext db)
        {
            _db = db;
        }

        public List<Conductor> Conductores { get; set; } = new();

        public async Task OnGetAsync()
        {
            Conductores = await _db.Conductores
                .Include(c => c.Usuario)
                .Include(c => c.Vehiculo)
                .OrderByDescending(c => c.Id)
                .ToListAsync();
        }
    }
}
