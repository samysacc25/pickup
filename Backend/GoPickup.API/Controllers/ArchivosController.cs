using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;

namespace GoPickup.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [DisableRequestSizeLimit]
    [RequestFormLimits(MultipartBodyLengthLimit = long.MaxValue)]
    public class ArchivosController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly IWebHostEnvironment _entorno;

        private static readonly string[] ExtensionesPermitidas = { ".jpg", ".jpeg", ".png", ".webp" };
        private const long TamanioMaximoBytes = 25 * 1024 * 1024;

        public ArchivosController(ApplicationDbContext db, IWebHostEnvironment entorno)
        {
            _db = db;
            _entorno = entorno;
        }

        private int UsuarioIdActual => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpPost("foto-perfil")]
        public async Task<IActionResult> SubirFotoPerfil(IFormFile foto)
        {
            var errorValidacion = ValidarArchivo(foto);
            if (errorValidacion != null) return BadRequest(new { mensaje = errorValidacion });

            var usuario = await _db.Usuarios.FindAsync(UsuarioIdActual);
            if (usuario is null) return NotFound(new { mensaje = "Usuario no encontrado." });

            var rutaRelativa = await GuardarArchivoAsync(foto, $"usuarios/{usuario.Id}", "perfil");
            usuario.FotoPerfilUrl = rutaRelativa;
            await _db.SaveChangesAsync();

            return Ok(new { url = rutaRelativa });
        }

        // POST api/archivos/foto-vehiculo?tipo=lateral|frontal|cabina
        [HttpPost("foto-vehiculo")]
        [Authorize(Roles = "Conductor")]
        public async Task<IActionResult> SubirFotoVehiculo(IFormFile foto, [FromQuery] string tipo)
        {
            var errorValidacion = ValidarArchivo(foto);
            if (errorValidacion != null) return BadRequest(new { mensaje = errorValidacion });

            var tiposValidos = new[] { "lateral", "frontal", "cabina" };
            if (!tiposValidos.Contains(tipo?.ToLower()))
                return BadRequest(new { mensaje = "El tipo de foto debe ser: lateral, frontal o cabina." });

            var conductor = await _db.Conductores.Include(c => c.Vehiculo).FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
            if (conductor?.Vehiculo is null) return NotFound(new { mensaje = "No se encontró el vehículo del conductor." });

            var rutaRelativa = await GuardarArchivoAsync(foto, $"vehiculos/{conductor.Id}", tipo!.ToLower());

            switch (tipo.ToLower())
            {
                case "lateral": conductor.Vehiculo.FotoLateralUrl = rutaRelativa; break;
                case "frontal": conductor.Vehiculo.FotoFrontalUrl = rutaRelativa; break;
                case "cabina": conductor.Vehiculo.FotoCabinaUrl = rutaRelativa; break;
            }

            await _db.SaveChangesAsync();
            return Ok(new { url = rutaRelativa });
        }

        // Foto frontal de la licencia de conducir del conductor.
        [HttpPost("foto-licencia")]
        [Authorize(Roles = "Conductor")]
        public async Task<IActionResult> SubirFotoLicencia(IFormFile foto)
        {
            var errorValidacion = ValidarArchivo(foto);
            if (errorValidacion != null) return BadRequest(new { mensaje = errorValidacion });

            var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
            if (conductor is null) return NotFound(new { mensaje = "No se encontró el perfil de conductor." });

            var rutaRelativa = await GuardarArchivoAsync(foto, $"licencias/{conductor.Id}", "frontal");
            conductor.FotoLicenciaFrontalUrl = rutaRelativa;
            await _db.SaveChangesAsync();

            return Ok(new { url = rutaRelativa });
        }

        private string? ValidarArchivo(IFormFile? foto)
        {
            if (foto is null || foto.Length == 0) return "No se recibió ninguna foto.";

            var extension = Path.GetExtension(foto.FileName).ToLowerInvariant();
            if (!ExtensionesPermitidas.Contains(extension))
                return "Formato de imagen no permitido. Usa JPG, PNG o WEBP.";

            if (foto.Length > TamanioMaximoBytes)
                return "La foto es demasiado pesada (máximo 25 MB). Intenta con una foto de menor resolución.";

            return null;
        }

        private async Task<string> GuardarArchivoAsync(IFormFile foto, string subcarpeta, string nombreBase)
        {
            var carpetaRaiz = _entorno.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
            var carpetaDestino = Path.Combine(carpetaRaiz, "uploads", subcarpeta);
            Directory.CreateDirectory(carpetaDestino);

            var extension = Path.GetExtension(foto.FileName).ToLowerInvariant();
            var nombreArchivo = $"{nombreBase}{extension}";
            var rutaCompleta = Path.Combine(carpetaDestino, nombreArchivo);

            await using (var stream = new FileStream(rutaCompleta, FileMode.Create))
            {
                await foto.CopyToAsync(stream);
            }

            return $"uploads/{subcarpeta}/{nombreArchivo}".Replace("\\", "/");
        }
    }
}
