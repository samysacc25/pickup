using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;

namespace GoPickup.Admin.Pages
{
    [Authorize]
    public class ClientesModel : PageModel
    {
        private readonly ApplicationDbContext _db;

        public ClientesModel(ApplicationDbContext db)
        {
            _db = db;
        }

        public List<Usuario> Clientes { get; set; } = new();

        public async Task OnGetAsync()
        {
            Clientes = await _db.Usuarios
                .Where(u => u.Rol == RolUsuario.Cliente)
                .OrderByDescending(u => u.Id)
                .ToListAsync();
        }

        public async Task<IActionResult> OnPostDesactivarAsync(int id)
        {
            var usuario = await _db.Usuarios.FindAsync(id);
            if (usuario is not null) { usuario.Activo = false; await _db.SaveChangesAsync(); }
            return RedirectToPage();
        }

        public async Task<IActionResult> OnPostActivarAsync(int id)
        {
            var usuario = await _db.Usuarios.FindAsync(id);
            if (usuario is not null) { usuario.Activo = true; await _db.SaveChangesAsync(); }
            return RedirectToPage();
        }
    }
}
