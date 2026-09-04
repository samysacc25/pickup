using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using GoPickup.API.Data;
using GoPickup.API.DTOs;
using GoPickup.API.Hubs;
using GoPickup.API.Models;
using GoPickup.API.Services;

namespace GoPickup.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Conductor")]
    public class ConductoresController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly ITarifaService _tarifaService;
        private readonly IPushNotificationService _push;
        private readonly IHubContext<SolicitudHub> _hub;

        // Distancia (en km) por debajo de la cual consideramos que el
        // conductor "ya llegó" al punto de recogida, para notificar al cliente.
        private const double UmbralLlegadaKm = 0.15; // 150 metros

        public ConductoresController(ApplicationDbContext db, ITarifaService tarifaService, IPushNotificationService push, IHubContext<SolicitudHub> hub)
        {
            _db = db;
            _tarifaService = tarifaService;
            _push = push;
            _hub = hub;
        }

        private int UsuarioIdActual => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpPut("ubicacion")]
        public async Task<IActionResult> ActualizarUbicacion(ActualizarUbicacionDto dto)
        {
            var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
            if (conductor is null) return NotFound();

            conductor.UltimaLatitud = dto.Latitud;
            conductor.UltimaLongitud = dto.Longitud;
            conductor.UltimaActualizacionUbicacion = DateTime.UtcNow;

            // Si el conductor va en camino hacia un cliente y ya está muy cerca
            // del punto de recogida, le notificamos automáticamente por push.
            var solicitudActiva = await _db.Solicitudes.FirstOrDefaultAsync(s =>
                s.ConductorId == conductor.Id && s.Estado == EstadoSolicitud.EnCamino && !s.NotificadoLlegada);

            if (solicitudActiva is not null)
            {
                var distancia = _tarifaService.CalcularDistanciaKm(dto.Latitud, dto.Longitud, solicitudActiva.OrigenLatitud, solicitudActiva.OrigenLongitud);
                if (distancia <= UmbralLlegadaKm)
                {
                    solicitudActiva.NotificadoLlegada = true;

                    // Aviso en tiempo real por SignalR a ambos (cliente y
                    // conductor están unidos al mismo grupo "solicitud-{id}").
                    // Esto no depende de que Firebase esté configurado, así que
                    // siempre llega mientras la app esté conectada.
                    await _hub.Clients.Group($"solicitud-{solicitudActiva.Id}")
                        .SendAsync("conductorLlegoAlPunto", solicitudActiva.Id);

                    // Además, push (si Firebase está configurado) para que le
                    // llegue al cliente aunque tenga la app en segundo plano.
                    var tokenCliente = await _db.Usuarios.Where(u => u.Id == solicitudActiva.ClienteId).Select(u => u.TokenPushNotificacion).FirstOrDefaultAsync();
                    await _push.EnviarAsync(tokenCliente, "Tu conductor llegó", "Tu conductor ya está en el punto de recogida.",
                        new Dictionary<string, string> { { "tipo", "conductor_llego" }, { "solicitudId", solicitudActiva.Id.ToString() } });
                }
            }

            await _db.SaveChangesAsync();
            return NoContent();
        }

        [HttpPut("estado")]
        public async Task<IActionResult> CambiarEstado(CambiarEstadoConductorDto dto)
        {
            var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
            if (conductor is null) return NotFound();

            if (conductor.EstadoSolicitud != EstadoSolicitudConductor.Aprobada && dto.Estado == EstadoConductor.Disponible)
                return BadRequest(new { mensaje = "Tu cuenta aún no ha sido aprobada por el administrador." });

            conductor.Estado = dto.Estado;
            await _db.SaveChangesAsync();
            return NoContent();
        }

        [HttpGet("perfil")]
        public async Task<ActionResult<ConductorResumenDto>> MiPerfil()
        {
            var conductor = await _db.Conductores
                .Include(c => c.Usuario)
                .Include(c => c.Vehiculo)
                .FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);

            if (conductor is null) return NotFound();

            return Ok(new ConductorResumenDto
            {
                Id = conductor.Id,
                NombreCompleto = conductor.Usuario?.NombreCompleto ?? string.Empty,
                Placa = conductor.Vehiculo?.Placa ?? string.Empty,
                TipoCamioneta = conductor.Vehiculo?.TipoCamioneta ?? TipoCamioneta.Pequena,
                CalificacionPromedio = conductor.CalificacionPromedio,
                Estado = conductor.Estado,
                EstadoSolicitud = conductor.EstadoSolicitud,
                Latitud = conductor.UltimaLatitud,
                Longitud = conductor.UltimaLongitud
            });
        }
    }
}
