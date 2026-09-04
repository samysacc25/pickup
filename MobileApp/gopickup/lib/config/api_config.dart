// Ajusta esta URL según dónde esté corriendo tu backend ASP.NET Core.
class ApiConfig {
  static const String baseUrl = 'https://gopickup-bxf2eweba3b9d2ag.westus3-01.azurewebsites.net/api';
  static const String hubUrl = 'https://gopickup-bxf2eweba3b9d2ag.westus3-01.azurewebsites.net/hubs/solicitud';

  // Misma API Key que configures en AndroidManifest.xml, con Places API y
  // Geocoding API también habilitadas en Google Cloud Console.
  static const String googlePlacesApiKey = 'AIzaSyCyZMq0YpJvuKGbo8gB0TDK7mjGjhCDMkA';
}
