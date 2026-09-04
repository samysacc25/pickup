using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.API.Controllers
{
    public class EnviarCodigoDto
    {
        [Required, MaxLength(20)]
        public string Telefono { get; set; } = string.Empty;
    }

    public class ConfirmarCodigoDto
    {
        [Required, MaxLength(20)]
        public string Telefono { get; set; } = string.Empty;

        [Required, MaxLength(6)]
        public string Codigo { get; set; } = string.Empty;
    }

    [ApiController]
    [Route("api/[controller]")]
    public class VerificacionController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly ISmsService _smsService;
        private readonly IWebHostEnvironment _entorno;

        private const int MinutosValidez = 10;
        private const int MaxIntentos = 5;

        public VerificacionController(ApplicationDbContext db, ISmsService smsService, IWebHostEnvironment entorno)
        {
            _db = db;
            _smsService = smsService;
            _entorno = entorno;
        }

        [HttpPost("enviar-codigo")]
        public async Task<IActionResult> EnviarCodigo(EnviarCodigoDto dto)
        {
            var yaExiste = await _db.Usuarios.AnyAsync(u => u.Telefono == dto.Telefono);
            if (yaExiste)
                return Conflict(new { mensaje = "Ese número de teléfono ya está registrado en otra cuenta." });

            var codigo = Random.Shared.Next(100000, 999999).ToString();

            var registro = await _db.CodigosVerificacionTelefono.FirstOrDefaultAsync(c => c.Telefono == dto.Telefono);
            if (registro is null)
            {
                registro = new CodigoVerificacionTelefono { Telefono = dto.Telefono };
                _db.CodigosVerificacionTelefono.Add(registro);
            }

            registro.Codigo = codigo;
            registro.FechaCreacion = DateTime.UtcNow;
            registro.FechaExpiracion = DateTime.UtcNow.AddMinutes(MinutosValidez);
            registro.Verificado = false;
            registro.FechaVerificacion = null;
            registro.Intentos = 0;

            await _db.SaveChangesAsync();

            var enviado = await _smsService.EnviarCodigoAsync(dto.Telefono, codigo);

            if (!enviado)
            {
                return Ok(new
                {
                    mensaje = _entorno.IsDevelopment()
                        ? "Modo desarrollo: Twilio no está configurado. Usa el código mostrado abajo."
                        : "No se pudo enviar el código de verificación. Intenta de nuevo más tarde.",
                    smsEnviado = false,
                    codigoDesarrollo = _entorno.IsDevelopment() ? codigo : null
                });
            }

            return Ok(new { mensaje = "Te enviamos un código de verificación por SMS.", smsEnviado = true, codigoDesarrollo = (string?)null });
        }

        [HttpPost("confirmar-codigo")]
        public async Task<IActionResult> ConfirmarCodigo(ConfirmarCodigoDto dto)
        {
            var registro = await _db.CodigosVerificacionTelefono.FirstOrDefaultAsync(c => c.Telefono == dto.Telefono);

            if (registro is null)
                return BadRequest(new { mensaje = "Primero debes solicitar un código de verificación." });

            if (registro.Intentos >= MaxIntentos)
                return BadRequest(new { mensaje = "Superaste el número de intentos permitidos. Solicita un nuevo código." });

            if (registro.FechaExpiracion < DateTime.UtcNow)
                return BadRequest(new { mensaje = "El código expiró. Solicita uno nuevo." });

            registro.Intentos++;

            if (registro.Codigo != dto.Codigo.Trim())
            {
                await _db.SaveChangesAsync();
                return BadRequest(new { mensaje = "El código ingresado es incorrecto." });
            }

            registro.Verificado = true;
            registro.FechaVerificacion = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return Ok(new { mensaje = "Número de teléfono verificado correctamente." });
        }
    }
}
