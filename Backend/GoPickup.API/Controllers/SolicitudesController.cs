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

        private int? ConductorIdActual =>
            int.TryParse(User.FindFirstValue("ConductorId"), out var id) ? id : null;

        // Verifica que quien llama sea el cliente o el conductor de ESA
        // solicitud en particular -- antes bastaba con tener CUALQUIER cuenta
        // de cliente/conductor autenticada para leer o actuar sobre una
        // solicitud ajena (con solo adivinar/probar el ID).
        private bool EsParticipante(Solicitud solicitud)
        {
            if (User.IsInRole("Cliente") && solicitud.ClienteId == UsuarioIdActual) return true;
            if (User.IsInRole("Conductor") && solicitud.ConductorId is not null && solicitud.ConductorId == ConductorIdActual) return true;
            return false;
        }

        [HttpPost]
        [Authorize(Roles = "Cliente")]
        public async Task<ActionResult<SolicitudRespuestaDto>> CrearSolicitud(CrearSolicitudDto dto)
        {
            // Transacción Serializable: sin esto, dos solicitudes del mismo
            // cliente enviadas casi al mismo tiempo (doble tap, reintento de
            // red) podían pasar juntas la verificación de "ya tiene una
            // solicitud activa" antes de que la primera terminara de
            // guardarse, resultando en dos solicitudes activas simultáneas.
            using var transaccion = await _db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);

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
            await transaccion.CommitAsync();

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
            // Antes esto traía primero solo los IDs y luego hacía UNA consulta
            // completa (con sus Include) POR CADA solicitud -- con 50
            // solicitudes activas eran 51 consultas a la base de datos en vez
            // de 1. Ahora se trae todo en una sola consulta y se arma el DTO
            // en memoria.
            var solicitudes = await ConsultaConIncludes()
                .Where(s => s.Estado == EstadoSolicitud.Buscando)
                .OrderBy(s => s.FechaSolicitud)
                .ToListAsync();

            return Ok(solicitudes.Select(MapearRespuesta).ToList());
        }

        [HttpPost("{id}/aceptar")]
        [Authorize(Roles = "Conductor")]
        public async Task<ActionResult<SolicitudRespuestaDto>> AceptarSolicitud(int id)
        {
            var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
            if (conductor is null) return Forbid();

            if (conductor.EstadoSolicitud != EstadoSolicitudConductor.Aprobada)
                return BadRequest(new { mensaje = "Tu cuenta de conductor aún no ha sido aprobada por el administrador." });

            // Antes solo se validaba el estado de APROBACIÓN del conductor,
            // no si ya estaba en otro viaje -- un conductor con un viaje en
            // curso (Estado = EnViaje/Ocupado) podía aceptar una segunda
            // solicitud simultánea.
            if (conductor.Estado != EstadoConductor.Disponible)
                return BadRequest(new { mensaje = "No puedes aceptar una nueva solicitud mientras tienes otro viaje en curso." });

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

            // Antes cualquier conductor autenticado podía finalizar el viaje
            // de OTRO conductor con solo conocer el ID de la solicitud.
            if (solicitud.ConductorId != ConductorIdActual) return Forbid();

            if (solicitud.Estado != EstadoSolicitud.Iniciada) return BadRequest(new { mensaje = "El servicio no está en curso." });

            solicitud.Estado = EstadoSolicitud.Finalizada;
            solicitud.FechaFin = DateTime.UtcNow;
            solicitud.TarifaFinal = solicitud.TarifaAcordada;

            if (solicitud.Conductor is not null)
                solicitud.Conductor.Estado = EstadoConductor.Disponible;

            await BorrarHistorialChatAsync(id);
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

            // Antes cualquier cliente o conductor autenticado podía cancelar
            // la solicitud de OTRA persona con solo conocer su ID.
            if (!EsParticipante(solicitud)) return Forbid();

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

            // Si ESTA solicitud ya traía un recargo (por una cancelación
            // anterior) y ahora se cancela sin completarse, ese monto se
            // devuelve como pendiente en vez de perderse -- antes desaparecía
            // silenciosamente porque solo vivía sumado a la tarifa de esta
            // solicitud, que nunca se llegó a cobrar.
            if (solicitud.RecargoAplicado is > 0)
            {
                var clienteConRecargo = await _db.Usuarios.FindAsync(solicitud.ClienteId);
                if (clienteConRecargo is not null) clienteConRecargo.RecargoPendiente += solicitud.RecargoAplicado.Value;
            }

            solicitud.Estado = esCliente ? EstadoSolicitud.CanceladaCliente : EstadoSolicitud.CanceladaConductor;
            solicitud.FechaCancelacion = DateTime.UtcNow;
            solicitud.MotivoCancelacion = dto.Motivo;

            if (solicitud.Conductor is not null)
                solicitud.Conductor.Estado = EstadoConductor.Disponible;

            await BorrarHistorialChatAsync(id);
            await _db.SaveChangesAsync();
            await _hub.Clients.Group($"solicitud-{solicitud.Id}").SendAsync("solicitudActualizada", await ObtenerRespuesta(solicitud.Id));

            return Ok(await ObtenerRespuesta(solicitud.Id));
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<SolicitudRespuestaDto>> ObtenerSolicitud(int id)
        {
            var solicitud = await _db.Solicitudes.AsNoTracking().FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            // Antes cualquier cliente o conductor autenticado podía consultar
            // el detalle (nombre, teléfono, cédula, ubicación en vivo...) de
            // la solicitud de OTRA persona con solo conocer/probar su ID.
            if (!EsParticipante(solicitud)) return Forbid();

            return Ok(await ObtenerRespuesta(id));
        }

        [HttpGet("mis-solicitudes")]
        public async Task<ActionResult<List<SolicitudRespuestaDto>>> MisSolicitudes()
        {
            // Antes se traían primero los IDs y luego se hacía una consulta
            // completa por cada uno (N+1). Ahora es una sola consulta con
            // Include y el DTO se arma en memoria.
            List<Solicitud> solicitudes;
            if (User.IsInRole("Conductor"))
            {
                var conductor = await _db.Conductores.FirstOrDefaultAsync(c => c.UsuarioId == UsuarioIdActual);
                solicitudes = conductor is null
                    ? new List<Solicitud>()
                    : await ConsultaConIncludes().Where(s => s.ConductorId == conductor.Id).OrderByDescending(s => s.FechaSolicitud).ToListAsync();
            }
            else
            {
                solicitudes = await ConsultaConIncludes().Where(s => s.ClienteId == UsuarioIdActual).OrderByDescending(s => s.FechaSolicitud).ToListAsync();
            }

            return Ok(solicitudes.Select(MapearRespuesta).ToList());
        }

        [HttpPut("{id}/calificar-conductor")]
        [Authorize(Roles = "Cliente")]
        public async Task<IActionResult> CalificarConductor(int id, CalificarSolicitudDto dto)
        {
            var solicitud = await _db.Solicitudes.Include(s => s.Conductor).FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            // Antes cualquier cliente autenticado podía calificar el viaje de
            // OTRO cliente con solo conocer el ID de la solicitud.
            if (solicitud.ClienteId != UsuarioIdActual) return Forbid();

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

        // Respaldo por HTTP del envío de chat (además de SignalR). El mensaje
        // se guarda mientras la solicitud sigue activa -- se borra al
        // finalizar o cancelarse (ver FinalizarSolicitud / CancelarSolicitud).
        [HttpPost("{id}/mensaje-chat")]
        public async Task<IActionResult> EnviarMensajeChat(int id, EnviarMensajeChatDto dto)
        {
            var solicitud = await _db.Solicitudes.FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            // Antes cualquier cliente o conductor autenticado podía escribir
            // en el chat de una solicitud ajena con solo conocer su ID.
            if (!EsParticipante(solicitud)) return Forbid();

            var remitente = User.IsInRole("Conductor") ? "conductor" : "cliente";
            var fecha = DateTime.UtcNow;

            _db.MensajesChat.Add(new MensajeChatSolicitud { SolicitudId = id, Remitente = remitente, Texto = dto.Mensaje, Fecha = fecha });
            await _db.SaveChangesAsync();

            await _hub.Clients.Group($"solicitud-{id}").SendAsync("mensajeChatRecibido", remitente, dto.Mensaje, fecha.ToString("o"));

            return NoContent();
        }

        // Historial de chat de la solicitud, mientras siga activa. La
        // pantalla de chat lo consulta al abrirse para no perder los
        // mensajes si el usuario había navegado fuera y vuelve a entrar.
        [HttpGet("{id}/mensajes-chat")]
        public async Task<ActionResult<List<MensajeChatRespuestaDto>>> ObtenerMensajesChat(int id)
        {
            var solicitud = await _db.Solicitudes.AsNoTracking().FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            // Antes cualquier cliente o conductor autenticado podía leer el
            // historial de chat de una solicitud ajena con solo conocer su ID.
            if (!EsParticipante(solicitud)) return Forbid();

            var mensajes = await _db.MensajesChat
                .Where(m => m.SolicitudId == id)
                .OrderBy(m => m.Fecha)
                .Select(m => new MensajeChatRespuestaDto { Remitente = m.Remitente, Texto = m.Texto, Fecha = m.Fecha })
                .ToListAsync();

            return Ok(mensajes);
        }

        private async Task<IActionResult> CambiarEstado(int id, EstadoSolicitud nuevoEstado, bool marcarInicio = false)
        {
            var solicitud = await _db.Solicitudes.FirstOrDefaultAsync(s => s.Id == id);
            if (solicitud is null) return NotFound();

            // Antes cualquier conductor autenticado podía marcar "en camino"
            // o "iniciado" el viaje de OTRO conductor con solo conocer el ID.
            if (solicitud.ConductorId != ConductorIdActual) return Forbid();

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

        // El chat se guarda solo mientras la solicitud está activa; al
        // terminar (finalizada o cancelada) se borra el historial.
        private async Task BorrarHistorialChatAsync(int solicitudId)
        {
            var mensajes = await _db.MensajesChat.Where(m => m.SolicitudId == solicitudId).ToListAsync();
            if (mensajes.Count > 0) _db.MensajesChat.RemoveRange(mensajes);
        }

        private async Task NotificarClientePorPush(int clienteId, string titulo, string cuerpo, int solicitudId)
        {
            var token = await _db.Usuarios.Where(u => u.Id == clienteId).Select(u => u.TokenPushNotificacion).FirstOrDefaultAsync();
            await _push.EnviarAsync(token, titulo, cuerpo,
                new Dictionary<string, string> { { "tipo", "actualizacion_solicitud" }, { "solicitudId", solicitudId.ToString() } });
        }

        // Consulta base con los Include necesarios para armar el DTO -- se
        // reutiliza tanto para traer una sola solicitud como para listas
        // (disponibles / mis-solicitudes), evitando el patrón N+1 que había
        // antes de traer una lista de IDs y volver a consultar uno por uno.
        private IQueryable<Solicitud> ConsultaConIncludes() =>
            _db.Solicitudes
                .AsNoTracking()
                .Include(x => x.Cliente)
                .Include(x => x.Conductor).ThenInclude(c => c!.Usuario)
                .Include(x => x.Conductor).ThenInclude(c => c!.Vehiculo);

        private async Task<SolicitudRespuestaDto> ObtenerRespuesta(int solicitudId)
        {
            var s = await ConsultaConIncludes().FirstAsync(x => x.Id == solicitudId);
            return MapearRespuesta(s);
        }

        private static SolicitudRespuestaDto MapearRespuesta(Solicitud s)
        {
            return new SolicitudRespuestaDto
            {
                Id = s.Id,
                Estado = s.Estado,
                ClienteNombre = s.Cliente?.NombreCompleto ?? string.Empty,
                ClienteTelefono = s.Cliente?.Telefono,
                ClienteCedula = s.Cliente?.NumeroCedula,
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
