using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.DTOs;
using GoPickup.API.Models;

namespace GoPickup.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Administrador")]
    public class AdminController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public AdminController(ApplicationDbContext db)
        {
            _db = db;
        }

        [HttpGet("resumen")]
        public async Task<IActionResult> Resumen()
        {
            var hoy = DateTime.UtcNow.Date;

            return Ok(new
            {
                totalClientes = await _db.Usuarios.CountAsync(u => u.Rol == RolUsuario.Cliente),
                totalConductores = await _db.Conductores.CountAsync(),
                solicitudesConductorPendientes = await _db.Conductores.CountAsync(c => c.EstadoSolicitud == EstadoSolicitudConductor.PendienteRevision),
                conductoresDisponiblesAhora = await _db.Conductores.CountAsync(c => c.Estado == EstadoConductor.Disponible),
                solicitudesHoy = await _db.Solicitudes.CountAsync(s => s.FechaSolicitud.Date == hoy),
                solicitudesFinalizadasHoy = await _db.Solicitudes.CountAsync(s => s.FechaFin != null && s.FechaFin.Value.Date == hoy),
                solicitudesEnCursoAhora = await _db.Solicitudes.CountAsync(s =>
                    s.Estado == EstadoSolicitud.Buscando || s.Estado == EstadoSolicitud.Aceptada ||
                    s.Estado == EstadoSolicitud.EnCamino || s.Estado == EstadoSolicitud.Iniciada),
                ingresosHoy = await _db.Solicitudes
                    .Where(s => s.FechaFin != null && s.FechaFin.Value.Date == hoy && s.TarifaFinal != null)
                    .SumAsync(s => s.TarifaFinal)
            });
        }

        [HttpGet("conductores/pendientes")]
        public async Task<IActionResult> ConductoresPendientes()
        {
            var pendientes = await _db.Conductores
                .Include(c => c.Usuario)
                .Include(c => c.Vehiculo)
                .Where(c => c.EstadoSolicitud == EstadoSolicitudConductor.PendienteRevision)
                .OrderBy(c => c.Id)
                .Select(c => new
                {
                    c.Id,
                    Nombre = c.Usuario!.NombreCompleto,
                    c.Usuario.Correo,
                    c.Usuario.Telefono,
                    c.Usuario.FotoPerfilUrl,
                    c.NumeroCedula,
                    c.TipoLicencia,
                    c.FotoLicenciaFrontalUrl,
                    Placa = c.Vehiculo!.Placa,
                    Marca = c.Vehiculo.Marca,
                    Modelo = c.Vehiculo.Modelo,
                    TipoCamioneta = c.Vehiculo.TipoCamioneta,
                    c.Vehiculo.FotoLateralUrl,
                    c.Vehiculo.FotoFrontalUrl,
                    c.Vehiculo.FotoCabinaUrl,
                    c.Usuario.FechaRegistro
                })
                .ToListAsync();

            return Ok(pendientes);
        }

        [HttpPut("conductores/{id}/revisar")]
        public async Task<IActionResult> RevisarSolicitudConductor(int id, RevisarSolicitudConductorDto dto)
        {
            var conductor = await _db.Conductores.FindAsync(id);
            if (conductor is null) return NotFound();

            conductor.EstadoSolicitud = dto.Aprobar ? EstadoSolicitudConductor.Aprobada : EstadoSolicitudConductor.Rechazada;
            conductor.MotivoRechazo = dto.Aprobar ? null : dto.MotivoRechazo;
            conductor.FechaRevision = DateTime.UtcNow;

            await _db.SaveChangesAsync();
            return NoContent();
        }

        [HttpPut("usuarios/{id}/desactivar")]
        public async Task<IActionResult> DesactivarUsuario(int id)
        {
            var usuario = await _db.Usuarios.FindAsync(id);
            if (usuario is null) return NotFound();
            usuario.Activo = false;
            await _db.SaveChangesAsync();
            return NoContent();
        }

        [HttpPut("usuarios/{id}/activar")]
        public async Task<IActionResult> ActivarUsuario(int id)
        {
            var usuario = await _db.Usuarios.FindAsync(id);
            if (usuario is null) return NotFound();
            usuario.Activo = true;
            await _db.SaveChangesAsync();
            return NoContent();
        }
    }
}
