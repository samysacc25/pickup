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

        public AuthController(ApplicationDbContext db, IPasswordService passwordService, ITokenService tokenService)
        {
            _db = db;
            _passwordService = passwordService;
            _tokenService = tokenService;
        }

        [HttpPost("registro/cliente")]
        public async Task<ActionResult<AuthRespuestaDto>> RegistrarCliente(RegistroClienteDto dto)
        {
            if (await _db.Usuarios.AnyAsync(u => u.Correo == dto.Correo))
                return Conflict(new { mensaje = "Ya existe una cuenta registrada con ese correo." });

            if (!await TelefonoFueVerificadoAsync(dto.Telefono))
                return BadRequest(new { mensaje = "Debes verificar tu número de teléfono antes de registrarte." });

            var usuario = new Usuario
            {
                NombreCompleto = dto.NombreCompleto,
                Correo = dto.Correo,
                Telefono = dto.Telefono,
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
                Color = dto.Color,
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
