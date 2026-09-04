using Twilio;
using Twilio.Rest.Api.V2010.Account;
using Twilio.Types;

namespace GoPickup.API.Services
{
    public interface ISmsService
    {
        Task<bool> EnviarCodigoAsync(string telefono, string codigo);
    }

    public class TwilioSmsService : ISmsService
    {
        private readonly ILogger<TwilioSmsService> _logger;
        private readonly string? _numeroOrigen;
        private readonly bool _habilitado;

        public TwilioSmsService(IConfiguration config, ILogger<TwilioSmsService> logger)
        {
            _logger = logger;

            var accountSid = config["Twilio:AccountSid"];
            var authToken = config["Twilio:AuthToken"];
            _numeroOrigen = config["Twilio:NumeroOrigen"];

            if (string.IsNullOrWhiteSpace(accountSid) || string.IsNullOrWhiteSpace(authToken) || string.IsNullOrWhiteSpace(_numeroOrigen))
            {
                _habilitado = false;
                _logger.LogWarning("Twilio no está configurado. La verificación por SMS quedará desactivada.");
                return;
            }

            TwilioClient.Init(accountSid, authToken);
            _habilitado = true;
        }

        public async Task<bool> EnviarCodigoAsync(string telefono, string codigo)
        {
            if (!_habilitado) return false;

            try
            {
                var numeroDestino = NormalizarTelefonoEcuador(telefono);

                await MessageResource.CreateAsync(
                    body: $"Tu código de verificación de Go Pickup es: {codigo}. Válido por 10 minutos.",
                    from: new PhoneNumber(_numeroOrigen),
                    to: new PhoneNumber(numeroDestino)
                );

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al enviar SMS de verificación a {Telefono}", telefono);
                return false;
            }
        }

        private static string NormalizarTelefonoEcuador(string telefono)
        {
            var limpio = new string(telefono.Where(char.IsDigit).ToArray());

            if (telefono.TrimStart().StartsWith("+"))
                return "+" + limpio;

            if (limpio.StartsWith("0"))
                return "+593" + limpio[1..];

            if (limpio.StartsWith("593"))
                return "+" + limpio;

            return "+593" + limpio;
        }
    }
}
