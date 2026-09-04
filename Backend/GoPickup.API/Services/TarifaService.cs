namespace GoPickup.API.Services
{
    public interface ITarifaService
    {
        double CalcularDistanciaKm(double lat1, double lon1, double lat2, double lon2);
        int EstimarDuracionMinutos(double distanciaKm);
        (decimal tarifa, bool esInterprovincial) CalcularTarifaSugerida(double origenLat, double origenLon, double destinoLat, double destinoLon, bool llevaCarga);
    }

    // Tarifa: $0.50 por km si es solo transporte de pasajero, $0.80 por km si
    // además lleva carga. "EsInterprovincial" queda solo como dato informativo
    // (se muestra en la app) y ya NO afecta el cálculo del precio.
    public class TarifaService : ITarifaService
    {
        private readonly decimal _tarifaPorKmSinCarga;
        private readonly decimal _tarifaPorKmConCarga;
        private readonly double _umbralKmInterprovincial;
        private readonly double _latRef;
        private readonly double _lonRef;

        private const double VelocidadPromedioKmH = 35.0;

        public TarifaService(IConfiguration config)
        {
            _tarifaPorKmSinCarga = config.GetValue<decimal>("Tarifas:TarifaPorKmSinCarga", 0.50m);
            _tarifaPorKmConCarga = config.GetValue<decimal>("Tarifas:TarifaPorKmConCarga", 0.80m);
            _umbralKmInterprovincial = config.GetValue<double>("Tarifas:UmbralKmInterprovincial", 45);
            _latRef = config.GetValue<double>("Tarifas:LatitudReferenciaTungurahua", -1.2417);
            _lonRef = config.GetValue<double>("Tarifas:LongitudReferenciaTungurahua", -78.6197);
        }

        public double CalcularDistanciaKm(double lat1, double lon1, double lat2, double lon2)
        {
            const double radioTierraKm = 6371.0;
            var dLat = ARad(lat2 - lat1);
            var dLon = ARad(lon2 - lon1);

            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                    Math.Cos(ARad(lat1)) * Math.Cos(ARad(lat2)) *
                    Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return Math.Round(radioTierraKm * c, 2);
        }

        public int EstimarDuracionMinutos(double distanciaKm)
        {
            var horas = distanciaKm / VelocidadPromedioKmH;
            return Math.Max(5, (int)Math.Ceiling(horas * 60));
        }

        public (decimal tarifa, bool esInterprovincial) CalcularTarifaSugerida(double origenLat, double origenLon, double destinoLat, double destinoLon, bool llevaCarga)
        {
            var distanciaViaje = CalcularDistanciaKm(origenLat, origenLon, destinoLat, destinoLon);

            var distanciaDestinoDesdeReferencia = CalcularDistanciaKm(_latRef, _lonRef, destinoLat, destinoLon);
            var esInterprovincial = distanciaDestinoDesdeReferencia > _umbralKmInterprovincial || distanciaViaje > _umbralKmInterprovincial;

            var tarifaPorKm = llevaCarga ? _tarifaPorKmConCarga : _tarifaPorKmSinCarga;
            var tarifa = tarifaPorKm * (decimal)distanciaViaje;

            return (Math.Round(tarifa, 2), esInterprovincial);
        }

        private static double ARad(double grados) => grados * Math.PI / 180.0;
    }
}
