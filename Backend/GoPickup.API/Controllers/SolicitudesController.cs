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
    [Authorize]
    public class SolicitudesController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly ITarifaService _tarifaService;
        private readonly IHubContext<SolicitudHub> _hub;
        private readonly IPushNotificationService _push;

        // Recargo aplicado a la SIGUIENTE solicitud cuando el cliente cancela
        // una carrera después de que un conductor ya la había aceptado.
        private const decimal RecargoPorCancelacion = 0.40m;

        public SolicitudesController(ApplicationDbContext db, ITarifaService tarifaService, IHubContext<SolicitudHub> hub, IPushNotificationService push)
        {
            _db = db;
            _tarifaService = tarifaService;
            _hub = hub;
            _push = push;
        }

        private int UsuarioIdActual => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpPost]
        [Authorize(Roles = "Cliente")]
        public async Task<ActionResult<SolicitudRespuestaDto>> CrearSolicitud(CrearSolicitudDto dto)
        {
            var yaTieneSolicitudActiva = await _db.Solicitudes.AnyAsync(s =>
                s.ClienteId == UsuarioIdActual &&
                (s.Estado == EstadoSolicitud.Buscando || s.Estado == EstadoSolicitud.Aceptada ||
                 s.Estado == EstadoSolicitud.EnCamino || s.Estado == EstadoSolicitud.Iniciada));

            if (yaTieneSolicitudActiva)
                return BadRequest(new { mensaje = "Ya tienes una solicitud en curso." });

            var cliente = await _db.Usuarios.FindAsync(UsuarioIdActual);
            if (cliente is null) return NotFound();

            var distancia = _tarifaService.CalcularDistanciaKm(dto.OrigenLatitud, dto.OrigenLongitud, dto.DestinoLatitud, dto.DestinoLongitud);
            var (tarifaSugerida, esInterprovincial) = _tarifaService.CalcularTarifaSugerida(dto.OrigenLatitud, dto.OrigenLongitud, dto.DestinoLatitud, dto.DestinoLongitud, dto.LlevaCarga);

            // Si el cliente tiene un recargo pendiente de una cancelación anterior,
            // se suma aquí y se limpia el pendiente.
            decimal? recargoAplicado = null;
            if (cliente.RecargoPendiente > 0)
            {
                recargoAplicado = cliente.RecargoPendiente;
                tarifaSugerida += cliente.RecargoPendiente;
                cliente.RecargoPendiente = 0;
            }

            var solicitud = new Solicitud
            {
                ClienteId = UsuarioIdActual,
                OrigenLatitud = dto.OrigenLatitud,
                OrigenLongitud = dto.OrigenLongitud,
                OrigenDireccion = dto.OrigenDireccion,
                DestinoLatitud = dto.DestinoLatitud,
                DestinoLongitud = dto.DestinoLongitud,
                DestinoDireccion = dto.DestinoDireccion,
                DescripcionCarga = dto.DescripcionCarga,
                LlevaCarga = dto.LlevaCarga,
                TipoCamionetaRequerida = dto.TipoCamionetaRequerida,
                MetodoPago = dto.MetodoPago,
                DistanciaKm = distancia,
                DuracionEstimadaMin = _tarifaService.EstimarDuracionMinutos(distancia),
                TarifaSugerida = tarifaSugerida,
                TarifaPropuestaCliente = dto.TarifaPropuesta,
                RecargoAplicado = recargoAplicado,
                EsInterprovincial = esInterprovincial,
                Estado = EstadoSolicitud.Buscando
            };

            _db.Solicitudes.Add(solicitud);
            await _db.SaveChangesAsync();

            var respuesta = await ObtenerRespuesta(solicitud.Id);
            await _hub.Clients.Group("conductores-disponibles").SendAsync("nuevaSolicitudDisponible", respuesta);

            var tokensConductores = await _db.Conductores
                .Where(c => c.EstadoSolicitud == EstadoSolicitudConductor.Aprobada && c.Estado == EstadoConductor.Disponible)
                .Include(c => c.Usuario)
                .Select(c => c.Usuario!.TokenPushNotificacion)
                .Where(t => t != null)
                .ToListAsync();

            await _push.EnviarATokensAsync(
                tokensConductores!,
                "Nueva solicitud de transporte",
                $"{solicitud.OrigenDireccion} → {solicitud.DestinoDireccion} · ${solicitud.TarifaSugerida:0.00}",
                new Dictionary<string, string> { { "tipo", "nueva_solicitud" }, { "solicitudId", solicitud.Id.ToString() } });

            return Ok(respuesta);
        }

        [HttpGet("disponibles")]
        [Authorize(Roles = "Conductor")]
        public async Task<ActionResult<List<SolicitudRespuestaDto>>> SolicitudesDisponibles()
        {
            var ids = await _db.Solicitudes
                .Where(s => s.Estado == EstadoSolicitud.Buscando)
                .OrderBy(s => s.FechaSolicitud)
                .Select(s => s.Id)
                .ToListAsync();

            var resultado = new List<SolicitudRespuestaDto>();
            foreach (var id in ids) resultado.Add(await ObtenerRespuesta(id));
            return Ok(resultado);
        }

        [HttpPost("{id}/aceptar")]
        [Authorize(Roles = "Conductor")]
        public async Task<ActionResult<SolicitudRespuestaDto>> AceptarSolicitud(int id)
        {
            var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
            if (conductor is null) return Forbid();

            if (conductor.EstadoSolicitud != EstadoSolicitudConductor.Aprobada)
                return BadRequest(new { mensaje = "Tu cuenta de conductor aún no ha sido aprobada por el administrador." });

            var solicitud = await _db.Solicitudes.FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            if (solicitud.Estado != EstadoSolicitud.Buscando)
                return BadRequest(new { mensaje = "Esta solicitud ya no está disponible." });

            solicitud.ConductorId = conductor.Id;
            solicitud.Estado = EstadoSolicitud.Aceptada;
            solicitud.FechaAceptacion = DateTime.UtcNow;
            solicitud.TarifaAcordada = solicitud.TarifaPropuestaCliente ?? solicitud.TarifaSugerida;

            conductor.Estado = EstadoConductor.EnViaje;

            await _db.SaveChangesAsync();
            var respuestaAceptada = await ObtenerRespuesta(solicitud.Id);
            await _hub.Clients.Group($"solicitud-{solicitud.Id}").SendAsync("solicitudActualizada", respuestaAceptada);

            await NotificarClientePorPush(solicitud.ClienteId, "¡Conductor asignado!", $"{respuestaAceptada.ConductorNombre} va a atender tu solicitud.", solicitud.Id);

            return Ok(respuestaAceptada);
        }

        [HttpPut("{id}/en-camino")]
        [Authorize(Roles = "Conductor")]
        public async Task<IActionResult> MarcarEnCamino(int id) => await CambiarEstado(id, EstadoSolicitud.EnCamino);

        [HttpPut("{id}/iniciar")]
        [Authorize(Roles = "Conductor")]
        public async Task<IActionResult> IniciarSolicitud(int id) => await CambiarEstado(id, EstadoSolicitud.Iniciada, marcarInicio: true);

        [HttpPut("{id}/finalizar")]
        [Authorize(Roles = "Conductor")]
        public async Task<IActionResult> FinalizarSolicitud(int id)
        {
            var solicitud = await _db.Solicitudes.Include(s => s.Conductor).FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();
            if (solicitud.Estado != EstadoSolicitud.Iniciada) return BadRequest(new { mensaje = "El servicio no está en curso." });

            solicitud.Estado = EstadoSolicitud.Finalizada;
            solicitud.FechaFin = DateTime.UtcNow;
            solicitud.TarifaFinal = solicitud.TarifaAcordada;

            if (solicitud.Conductor is not null)
                solicitud.Conductor.Estado = EstadoConductor.Disponible;

            await _db.SaveChangesAsync();
            await _hub.Clients.Group($"solicitud-{solicitud.Id}").SendAsync("solicitudActualizada", await ObtenerRespuesta(solicitud.Id));

            await NotificarClientePorPush(solicitud.ClienteId, "Servicio finalizado", $"Tu viaje terminó. Total: ${solicitud.TarifaFinal:0.00}", solicitud.Id);

            return Ok(await ObtenerRespuesta(solicitud.Id));
        }

        [HttpPut("{id}/cancelar")]
        public async Task<IActionResult> CancelarSolicitud(int id, CancelarSolicitudDto dto)
        {
            var solicitud = await _db.Solicitudes.Include(s => s.Conductor).FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            var esCliente = User.IsInRole("Cliente");

            // Si el cliente cancela DESPUÉS de que un conductor ya la había
            // aceptado (o va en camino / ya inició), se le carga un recargo de
            // $0.40 que se cobrará automáticamente en su próxima solicitud.
            if (esCliente && solicitud.ConductorId != null &&
                (solicitud.Estado == EstadoSolicitud.Aceptada || solicitud.Estado == EstadoSolicitud.EnCamino || solicitud.Estado == EstadoSolicitud.Iniciada))
            {
                var cliente = await _db.Usuarios.FindAsync(solicitud.ClienteId);
                if (cliente is not null) cliente.RecargoPendiente += RecargoPorCancelacion;
            }

            solicitud.Estado = esCliente ? EstadoSolicitud.CanceladaCliente : EstadoSolicitud.CanceladaConductor;
            solicitud.FechaCancelacion = DateTime.UtcNow;
            solicitud.MotivoCancelacion = dto.Motivo;

            if (solicitud.Conductor is not null)
                solicitud.Conductor.Estado = EstadoConductor.Disponible;

            await _db.SaveChangesAsync();
            await _hub.Clients.Group($"solicitud-{solicitud.Id}").SendAsync("solicitudActualizada", await ObtenerRespuesta(solicitud.Id));

            return Ok(await ObtenerRespuesta(solicitud.Id));
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<SolicitudRespuestaDto>> ObtenerSolicitud(int id)
        {
            var existe = await _db.Solicitudes.AnyAsync(s => s.Id == id);
            if (!existe) return NotFound();
            return Ok(await ObtenerRespuesta(id));
        }

        [HttpGet("mis-solicitudes")]
        public async Task<ActionResult<List<SolicitudRespuestaDto>>> MisSolicitudes()
        {
            List<int> ids;
            if (User.IsInRole("Conductor"))
            {
                var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
                ids = conductor is null
                    ? new List<int>()
                    : await _db.Solicitudes.Where(s => s.ConductorId == conductor.Id).OrderByDescending(s => s.FechaSolicitud).Select(s => s.Id).ToListAsync();
            }
            else
            {
                ids = await _db.Solicitudes.Where(s => s.ClienteId == UsuarioIdActual).OrderByDescending(s => s.FechaSolicitud).Select(s => s.Id).ToListAsync();
            }

            var resultado = new List<SolicitudRespuestaDto>();
            foreach (var id in ids) resultado.Add(await ObtenerRespuesta(id));
            return Ok(resultado);
        }

        [HttpPut("{id}/calificar-conductor")]
        [Authorize(Roles = "Cliente")]
        public async Task<IActionResult> CalificarConductor(int id, CalificarSolicitudDto dto)
        {
            var solicitud = await _db.Solicitudes.Include(s => s.Conductor).FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();
            if (solicitud.Estado != EstadoSolicitud.Finalizada) return BadRequest(new { mensaje = "Solo puedes calificar servicios finalizados." });

            solicitud.CalificacionConductor = dto.Calificacion;

            if (solicitud.Conductor is not null)
            {
                var calificaciones = await _db.Solicitudes
                    .Where(s => s.ConductorId == solicitud.ConductorId && s.CalificacionConductor != null)
                    .Select(s => s.CalificacionConductor!.Value)
                    .ToListAsync();
                calificaciones.Add(dto.Calificacion);
                solicitud.Conductor.CalificacionPromedio = Math.Round(calificaciones.Average(), 2);
            }

            await _db.SaveChangesAsync();
            return NoContent();
        }

        // Chat interno: NO se guarda nada en base de datos, solo se retransmite
        // en vivo al otro participante de la solicitud (cliente <-> conductor).
        [HttpPost("{id}/mensaje-chat")]
        public async Task<IActionResult> EnviarMensajeChat(int id, EnviarMensajeChatDto dto)
        {
            var solicitud = await _db.Solicitudes.FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            var remitente = User.IsInRole("Conductor") ? "conductor" : "cliente";
            await _hub.Clients.Group($"solicitud-{id}").SendAsync("mensajeChatRecibido", remitente, dto.Mensaje, DateTime.UtcNow.ToString("o"));

            return NoContent();
        }

        private async Task<IActionResult> CambiarEstado(int id, EstadoSolicitud nuevoEstado, bool marcarInicio = false)
        {
            var solicitud = await _db.Solicitudes.FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            solicitud.Estado = nuevoEstado;
            if (marcarInicio) solicitud.FechaInicio = DateTime.UtcNow;

            await _db.SaveChangesAsync();
            await _hub.Clients.Group($"solicitud-{solicitud.Id}").SendAsync("solicitudActualizada", await ObtenerRespuesta(solicitud.Id));

            if (nuevoEstado == EstadoSolicitud.EnCamino)
                await NotificarClientePorPush(solicitud.ClienteId, "Tu conductor va en camino", "Está en ruta hacia el punto de recogida.", solicitud.Id);
            else if (nuevoEstado == EstadoSolicitud.Iniciada)
                await NotificarClientePorPush(solicitud.ClienteId, "Servicio iniciado", "Tu viaje está en camino al destino.", solicitud.Id);

            return Ok(await ObtenerRespuesta(solicitud.Id));
        }

        private async Task NotificarClientePorPush(int clienteId, string titulo, string cuerpo, int solicitudId)
        {
            var token = await _db.Usuarios.Where(u => u.Id == clienteId).Select(u => u.TokenPushNotificacion).FirstOrDefaultAsync();
            await _push.EnviarAsync(token, titulo, cuerpo,
                new Dictionary<string, string> { { "tipo", "actualizacion_solicitud" }, { "solicitudId", solicitudId.ToString() } });
        }

        private async Task<SolicitudRespuestaDto> ObtenerRespuesta(int solicitudId)
        {
            var s = await _db.Solicitudes
                .Include(x => x.Cliente)
                .Include(x => x.Conductor).ThenInclude(c => c!.Usuario)
                .Include(x => x.Conductor).ThenInclude(c => c!.Vehiculo)
                .FirstAsync(x => x.Id == solicitudId);

            return new SolicitudRespuestaDto
            {
                Id = s.Id,
                Estado = s.Estado,
                ClienteNombre = s.Cliente?.NombreCompleto ?? string.Empty,
                ClienteTelefono = s.Cliente?.Telefono,
                ConductorId = s.ConductorId,
                ConductorNombre = s.Conductor?.Usuario?.NombreCompleto,
                ConductorTelefono = s.Conductor?.Usuario?.Telefono,
                VehiculoPlaca = s.Conductor?.Vehiculo?.Placa,
                VehiculoDescripcion = s.Conductor?.Vehiculo is null ? null : $"{s.Conductor.Vehiculo.Marca} {s.Conductor.Vehiculo.Modelo} - {s.Conductor.Vehiculo.Color}",
                VehiculoTipo = s.Conductor?.Vehiculo?.TipoCamioneta,
                ConductorLatitud = s.Conductor?.UltimaLatitud,
                ConductorLongitud = s.Conductor?.UltimaLongitud,
                OrigenLatitud = s.OrigenLatitud,
                OrigenLongitud = s.OrigenLongitud,
                OrigenDireccion = s.OrigenDireccion,
                DestinoLatitud = s.DestinoLatitud,
                DestinoLongitud = s.DestinoLongitud,
                DestinoDireccion = s.DestinoDireccion,
                DescripcionCarga = s.DescripcionCarga,
                LlevaCarga = s.LlevaCarga,
                EsInterprovincial = s.EsInterprovincial,
                TipoCamionetaRequerida = s.TipoCamionetaRequerida,
                MetodoPago = s.MetodoPago,
                TarifaSugerida = s.TarifaSugerida,
                TarifaPropuestaCliente = s.TarifaPropuestaCliente,
                TarifaAcordada = s.TarifaAcordada,
                TarifaFinal = s.TarifaFinal,
                RecargoAplicado = s.RecargoAplicado,
                DistanciaKm = s.DistanciaKm,
                DuracionEstimadaMin = s.DuracionEstimadaMin,
                FechaSolicitud = s.FechaSolicitud,
                FechaFin = s.FechaFin
            };
        }
    }
}
