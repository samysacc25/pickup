using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.Admin.Pages
{
    public class LoginModel : PageModel
    {
        private readonly ApplicationDbContext _db;
        private readonly IPasswordService _passwordService;

        public LoginModel(ApplicationDbContext db, IPasswordService passwordService)
        {
            _db = db;
            _passwordService = passwordService;
        }

        [BindProperty]
        public string? MensajeError { get; set; }

        public void OnGet() { }

        public async Task<IActionResult> OnPostAsync(string correo, string clave)
        {
            var usuario = await _db.Usuarios.FirstOrDefaultAsync(u =>
                u.Correo == correo && u.Rol == RolUsuario.Administrador);

            if (usuario is null || !_passwordService.Verificar(clave, usuario.ClaveHash))
            {
                MensajeError = "Credenciales incorrectas o la cuenta no tiene permisos de administrador.";
                return Page();
            }

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
                new Claim(ClaimTypes.Name, usuario.NombreCompleto),
                new Claim(ClaimTypes.Role, "Administrador")
            };

            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identity));

            return RedirectToPage("/Index");
        }
    }
}
