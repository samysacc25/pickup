using Microsoft.EntityFrameworkCore;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.API.Data
{
    public static class DbInitializer
    {
        // Antes la cuenta de administrador inicial se creaba con un correo y
        // una contraseña fijos escritos directamente en el código fuente
        // (que además queda en el historial de git) -- cualquiera con acceso
        // al repositorio (o que lo encontrara filtrado) tenía la contraseña
        // del admin de producción. Ahora se puede configurar por
        // appsettings/variables de entorno y, si no se configura nada, se
        // genera una contraseña aleatoria que se imprime UNA sola vez en el
        // log al arrancar, para que quien despliega la capture y la cambie.
        //
        // IMPORTANTE: esto solo aplica quien VUELVE a crear la cuenta admin
        // (base de datos nueva). Si ya existe un admin (como en producción
        // ahora mismo, con la contraseña vieja "Admin123!"), este cambio NO
        // la modifica -- esa contraseña ya quedó expuesta en el historial de
        // git y debe cambiarse manualmente desde la app/BD.
        public static void Inicializar(ApplicationDbContext db, IPasswordService passwordService, IConfiguration configuracion)
        {
            db.Database.Migrate();

            if (!db.Usuarios.Any(u => u.Rol == RolUsuario.Administrador))
            {
                var correo = configuracion["AdminInicial:Correo"] ?? "admin@gopickup.local";
                var telefono = configuracion["AdminInicial:Telefono"] ?? "0000000000";
                var clave = configuracion["AdminInicial:Clave"];

                var claveGenerada = string.IsNullOrWhiteSpace(clave);
                if (claveGenerada) clave = GenerarClaveAleatoria();

                db.Usuarios.Add(new Usuario
                {
                    NombreCompleto = "Administrador Go Pickup",
                    Correo = correo,
                    Telefono = telefono,
                    ClaveHash = passwordService.Hash(clave!),
                    Rol = RolUsuario.Administrador,
                    TelefonoVerificado = true
                });
                db.SaveChanges();

                if (claveGenerada)
                {
                    Console.WriteLine("========================================================");
                    Console.WriteLine($"Cuenta de administrador creada: {correo}");
                    Console.WriteLine($"Contraseña generada (guárdala, no se volverá a mostrar): {clave}");
                    Console.WriteLine("Configura AdminInicial:Correo / AdminInicial:Clave para fijar tus propios valores.");
                    Console.WriteLine("========================================================");
                }
            }
        }

        private static string GenerarClaveAleatoria()
        {
            const string caracteres = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
            var bytes = new byte[16];
            System.Security.Cryptography.RandomNumberGenerator.Fill(bytes);
            var claveChars = new char[16];
            for (var i = 0; i < claveChars.Length; i++)
                claveChars[i] = caracteres[bytes[i] % caracteres.Length];
            return new string(claveChars);
        }
    }
}
