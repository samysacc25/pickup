using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using GoPickup.API.Data;

namespace GoPickup.API.Controllers
{
    public class ActualizarTokenPushDto
    {
        [Required]
        public string Token { get; set; } = string.Empty;
    }

    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificacionesController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public NotificacionesController(ApplicationDbContext db)
        {
            _db = db;
        }

        [HttpPut("token")]
        public async Task<IActionResult> ActualizarToken(ActualizarTokenPushDto dto)
        {
            var usuarioId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var usuario = await _db.Usuarios.FindAsync(usuarioId);
            if (usuario is null) return NotFound();

            usuario.TokenPushNotificacion = dto.Token;
            await _db.SaveChangesAsync();
            return NoContent();
        }
    }
}
