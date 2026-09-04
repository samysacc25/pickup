using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace GoPickup.API.Services
{
    public interface IPushNotificationService
    {
        Task EnviarAsync(string? tokenDispositivo, string titulo, string cuerpo, Dictionary<string, string>? datos = null);
        Task EnviarATokensAsync(IEnumerable<string> tokens, string titulo, string cuerpo, Dictionary<string, string>? datos = null);
    }

    public class FirebasePushNotificationService : IPushNotificationService
    {
        private readonly ILogger<FirebasePushNotificationService> _logger;
        private readonly bool _habilitado;

        public FirebasePushNotificationService(IConfiguration config, ILogger<FirebasePushNotificationService> logger)
        {
            _logger = logger;
            var rutaCredenciales = config["Firebase:RutaCredencialesJson"];

            if (string.IsNullOrWhiteSpace(rutaCredenciales) || !File.Exists(rutaCredenciales))
            {
                _habilitado = false;
                _logger.LogWarning("Firebase no está configurado. Las notificaciones push quedarán desactivadas.");
                return;
            }

            if (FirebaseApp.DefaultInstance is null)
            {
                FirebaseApp.Create(new AppOptions { Credential = GoogleCredential.FromFile(rutaCredenciales) });
            }

            _habilitado = true;
        }

        public async Task EnviarAsync(string? tokenDispositivo, string titulo, string cuerpo, Dictionary<string, string>? datos = null)
        {
            if (string.IsNullOrWhiteSpace(tokenDispositivo)) return;
            await EnviarATokensAsync(new[] { tokenDispositivo }, titulo, cuerpo, datos);
        }

        public async Task EnviarATokensAsync(IEnumerable<string> tokens, string titulo, string cuerpo, Dictionary<string, string>? datos = null)
        {
            var listaTokens = tokens.Where(t => !string.IsNullOrWhiteSpace(t)).Distinct().ToList();
            if (!_habilitado || listaTokens.Count == 0) return;

            try
            {
                var mensaje = new MulticastMessage
                {
                    Tokens = listaTokens,
                    Notification = new Notification { Title = titulo, Body = cuerpo },
                    Data = datos
                };

                await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(mensaje);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al enviar notificaciones push");
            }
        }
    }
}
