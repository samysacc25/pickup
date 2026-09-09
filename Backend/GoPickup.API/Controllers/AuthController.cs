using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.DTOs;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly IPasswordService _passwordService;
        private readonly ITokenService _tokenService;
        private readonly ISmsService _smsService;
        private readonly IWebHostEnvironment _entorno;

        // Color único para toda la flota de camionetas.
        private const string ColorFlota = "Blanco-Verde";
        private const int MaxIntentos = 5;

        public AuthController(ApplicationDbContext db, IPasswordService passwordService, ITokenService tokenService, ISmsService smsService, IWebHostEnvironment entorno)
        {
            _db = db;
            _passwordService = passwordService;
            _tokenService = tokenService;
            _smsService = smsService;
            _entorno = entorno;
        }

        [HttpPost("registro/cliente")]
        public async Task<ActionResult<AuthRespuestaDto>> RegistrarCliente(RegistroClienteDto dto)
        {
            if (await _db.Usuarios.AnyAsync(u => u.Correo == dto.Correo))
                return Conflict(new { mensaje = "Ya existe una cuenta registrada con ese correo." });

            if (await _db.Usuarios.AnyAsync(u => u.NumeroCedula == dto.NumeroCedula))
                return Conflict(new { mensaje = "Ya existe una cuenta registrada con esa cédula." });

            // Antes no se validaba el teléfono contra duplicados aquí -- dos
            // registros casi simultáneos con el mismo número (uno ya
            // verificado, el otro reusando esa verificación dentro de la
            // ventana de 30 min) podían crear dos cuentas con el mismo
            // teléfono, rompiendo el login/reseteo por teléfono.
            if (await _db.Usuarios.AnyAsync(u => u.Telefono == dto.Telefono))
                return Conflict(new { mensaje = "Ya existe una cuenta registrada con ese número de teléfono." });

            if (!await TelefonoFueVerificadoAsync(dto.Telefono))
                return BadRequest(new { mensaje = "Debes verificar tu número de teléfono antes de registrarte." });

            var usuario = new Usuario
            {
                NombreCompleto = dto.NombreCompleto,
                Correo = dto.Correo,
                Telefono = dto.Telefono,
                NumeroCedula = dto.NumeroCedula,
                ClaveHash = _passwordService.Hash(dto.Clave),
                Rol = RolUsuario.Cliente,
                TelefonoVerificado = true
            };

            _db.Usuarios.Add(usuario);
            await _db.SaveChangesAsync();

            var token = _tokenService.GenerarToken(usuario);
            return Ok(new AuthRespuestaDto
            {
                Token = token,
                UsuarioId = usuario.Id,
                NombreCompleto = usuario.NombreCompleto,
                Rol = usuario.Rol
            });
        }

        [HttpPost("registro/conductor")]
        public async Task<ActionResult<AuthRespuestaDto>> SolicitarSerConductor(SolicitudConductorDto dto)
        {
            if (await _db.Usuarios.AnyAsync(u => u.Correo == dto.Correo))
                return Conflict(new { mensaje = "Ya existe una cuenta registrada con ese correo." });

            if (await _db.Vehiculos.AnyAsync(v => v.Placa == dto.Placa))
                return Conflict(new { mensaje = "Ya existe un vehículo registrado con esa placa." });

            if (await _db.Conductores.AnyAsync(c => c.NumeroCedula == dto.NumeroCedula))
                return Conflict(new { mensaje = "Ya existe un conductor registrado con esa cédula." });

            // Mismo caso que en el registro de cliente: cierra la ventana de
            // carrera donde dos registros con el mismo teléfono podían
            // colarse antes de esta validación.
            if (await _db.Usuarios.AnyAsync(u => u.Telefono == dto.Telefono))
                return Conflict(new { mensaje = "Ya existe una cuenta registrada con ese número de teléfono." });

            if (!await TelefonoFueVerificadoAsync(dto.Telefono))
                return BadRequest(new { mensaje = "Debes verificar tu número de teléfono antes de registrarte." });

            using var transaccion = await _db.Database.BeginTransactionAsync();

            var usuario = new Usuario
            {
                NombreCompleto = dto.NombreCompleto,
                Correo = dto.Correo,
                Telefono = dto.Telefono,
                ClaveHash = _passwordService.Hash(dto.Clave),
                Rol = RolUsuario.Conductor,
                TelefonoVerificado = true
            };
            _db.Usuarios.Add(usuario);
            await _db.SaveChangesAsync();

            var conductor = new Conductor
            {
                UsuarioId = usuario.Id,
                NumeroCedula = dto.NumeroCedula,
                TipoLicencia = dto.TipoLicencia,
                EstadoSolicitud = EstadoSolicitudConductor.PendienteRevision,
                Estado = EstadoConductor.Desconectado
            };
            _db.Conductores.Add(conductor);
            await _db.SaveChangesAsync();

            var vehiculo = new Vehiculo
            {
                ConductorId = conductor.Id,
                Placa = dto.Placa,
                Marca = dto.Marca,
                Modelo = dto.Modelo,
                // El color es fijo para toda la flota (Blanco-Verde); se ignora
                // cualquier valor que venga del cliente en vez de confiar en el
                // campo bloqueado de la app -- así queda garantizado también si
                // alguien llama al endpoint directamente.
                Color = ColorFlota,
                Anio = dto.Anio,
                TipoCamioneta = dto.TipoCamioneta,
                DescripcionCapacidad = dto.DescripcionCapacidad
            };
            _db.Vehiculos.Add(vehiculo);
            await _db.SaveChangesAsync();

            await transaccion.CommitAsync();

            var token = _tokenService.GenerarToken(usuario, conductor.Id);
            return Ok(new AuthRespuestaDto
            {
                Token = token,
                UsuarioId = usuario.Id,
                NombreCompleto = usuario.NombreCompleto,
                Rol = usuario.Rol,
                ConductorId = conductor.Id,
                EstadoSolicitudConductor = conductor.EstadoSolicitud
            });
        }

        [HttpPost("login")]
        public async Task<ActionResult<AuthRespuestaDto>> Login(LoginDto dto)
        {
            var usuario = await _db.Usuarios
                .Include(u => u.PerfilConductor)
                .FirstOrDefaultAsync(u => u.Correo == dto.Correo);

            if (usuario is null || !_passwordService.Verificar(dto.Clave, usuario.ClaveHash))
                return Unauthorized(new { mensaje = "Correo o contraseña incorrectos." });

            if (!usuario.Activo)
                return Unauthorized(new { mensaje = "Esta cuenta ha sido deshabilitada. Contacta al soporte." });

            var token = _tokenService.GenerarToken(usuario, usuario.PerfilConductor?.Id);
            return Ok(new AuthRespuestaDto
            {
                Token = token,
                UsuarioId = usuario.Id,
                NombreCompleto = usuario.NombreCompleto,
                Rol = usuario.Rol,
                ConductorId = usuario.PerfilConductor?.Id,
                EstadoSolicitudConductor = usuario.PerfilConductor?.EstadoSolicitud
            });
        }

        // Reseteo de contraseña por teléfono, paso 1: el usuario ingresa solo
        // su número, se busca a qué cuenta pertenece (sin revelar nombre
        // completo/correo en este paso, solo el primer nombre para que la
        // persona confirme que es su cuenta) y se envía un código SMS.
        [HttpPost("reset-clave/solicitar")]
        public async Task<IActionResult> SolicitarResetClave(SolicitarResetClaveDto dto)
        {
            var usuario = await _db.Usuarios.FirstOrDefaultAsync(u => u.Telefono == dto.Telefono);
            if (usuario is null)
                return NotFound(new { mensaje = "No encontramos ninguna cuenta con ese número de teléfono." });

            var registro = await _db.CodigosVerificacionTelefono.FirstOrDefaultAsync(c => c.Telefono == dto.Telefono);

            // Mismo límite de 60s que en /verificacion/enviar-codigo, para
            // que no se pueda saturar de SMS un número reenviando el
            // formulario.
            if (registro is not null && registro.FechaCreacion > DateTime.UtcNow.AddSeconds(-60))
                return BadRequest(new { mensaje = "Espera un momento antes de solicitar otro código." });

            var codigo = Random.Shared.Next(100000, 999999).ToString();

            if (registro is null)
            {
                registro = new CodigoVerificacionTelefono { Telefono = dto.Telefono };
                _db.CodigosVerificacionTelefono.Add(registro);
            }

            registro.Codigo = codigo;
            registro.FechaCreacion = DateTime.UtcNow;
            registro.FechaExpiracion = DateTime.UtcNow.AddMinutes(10);
            registro.Verificado = false;
            registro.FechaVerificacion = null;
            registro.Intentos = 0;

            await _db.SaveChangesAsync();

            var enviado = await _smsService.EnviarCodigoAsync(dto.Telefono, codigo);
            var primerNombre = usuario.NombreCompleto.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? usuario.NombreCompleto;

            return Ok(new
            {
                mensaje = enviado
                    ? "Te enviamos un código de verificación por SMS."
                    : (_entorno.IsDevelopment() ? "Código generado." : "No se pudo enviar el SMS. Intenta de nuevo más tarde."),
                nombre = primerNombre,
                smsEnviado = enviado,
                codigoDesarrollo = _entorno.IsDevelopment() ? codigo : null
            });
        }

        // Paso 2: confirma el código SMS y, si es correcto, aplica la nueva
        // contraseña directamente (a diferencia de /verificacion/confirmar-codigo,
        // que solo marca el teléfono como verificado para el registro).
        [HttpPost("reset-clave/confirmar")]
        public async Task<IActionResult> ConfirmarResetClave(ConfirmarResetClaveDto dto)
        {
            var registro = await _db.CodigosVerificacionTelefono.FirstOrDefaultAsync(c => c.Telefono == dto.Telefono);
            if (registro is null)
                return BadRequest(new { mensaje = "Primero solicita un código de verificación." });

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

            var usuario = await _db.Usuarios.FirstOrDefaultAsync(u => u.Telefono == dto.Telefono);
            if (usuario is null)
                return NotFound(new { mensaje = "No encontramos ninguna cuenta con ese número de teléfono." });

            usuario.ClaveHash = _passwordService.Hash(dto.NuevaClave);

            // Invalida el código para que no pueda reusarse para otro reseteo.
            registro.FechaExpiracion = DateTime.UtcNow;
            registro.Verificado = false;

            await _db.SaveChangesAsync();
            return Ok(new { mensaje = "Contraseña actualizada correctamente." });
        }

        private async Task<bool> TelefonoFueVerificadoAsync(string telefono)
        {
            var registro = await _db.CodigosVerificacionTelefono.FirstOrDefaultAsync(c => c.Telefono == telefono);
            return registro is not null
                && registro.Verificado
                && registro.FechaVerificacion is not null
                && registro.FechaVerificacion > DateTime.UtcNow.AddMinutes(-30);
        }
    }
}
