using Microsoft.EntityFrameworkCore;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.API.Data
{
    public static class DbInitializer
    {
        public static void Inicializar(ApplicationDbContext db, IPasswordService passwordService)
        {
            db.Database.Migrate();

            if (!db.Usuarios.Any(u => u.Rol == RolUsuario.Administrador))
            {
                db.Usuarios.Add(new Usuario
                {
                    NombreCompleto = "Administrador Go Pickup",
                    Correo = "samanthagopickup@gmail.com",
                    Telefono = "0991010657",
                    ClaveHash = passwordService.Hash("Admin123!"),
                    Rol = RolUsuario.Administrador,
                    TelefonoVerificado = true
                });
                db.SaveChanges();
            }
        }
    }
}
