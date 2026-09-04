namespace GoPickup.API.Services
{
    public interface ITarifaService
    {
        double CalcularDistanciaKm(double lat1, double lon1, double lat2, double lon2);
        int EstimarDuracionMinutos(double distanciaKm);
        (decimal tarifa, bool esInterprovincial) CalcularTarifaSugerida(double origenLat, double origenLon, double destinoLat, double destinoLon, bool llevaCarga);
    }

    // Tarifa = Banderazo (arranque, distinto de día/noche) + $0.50 por km si es
    // solo transporte de pasajero (o $0.80/km si además lleva carga), con un
    // piso de tarifa mínima: si el cálculo por distancia da un valor menor al
    // mínimo (viajes muy cortos), se cobra la tarifa mínima en su lugar. Para
    // viajes más largos el precio sigue creciendo normalmente con la
    // distancia — el mínimo NUNCA se aplica como valor fijo para todos los
    // viajes, solo como piso. "EsInterprovincial" queda solo como dato
    // informativo (se muestra en la app) y no afecta el cálculo del precio.
    public class TarifaService : ITarifaService
    {
        private readonly decimal _tarifaPorKmSinCarga;
        private readonly decimal _tarifaPorKmConCarga;
        private readonly decimal _banderazoDia;
        private readonly decimal _banderazoNoche;
        private readonly decimal _tarifaMinima;
        private readonly double _umbralKmInterprovincial;
        private readonly double _latRef;
        private readonly double _lonRef;

        private const double VelocidadPromedioKmH = 35.0;

        // Ecuador no observa horario de verano: usamos el offset fijo de
        // Tungurahua/Ecuador continental (UTC-5) en vez de la hora del
        // servidor, para que el horario nocturno sea correcto sin importar
        // dónde esté alojado el backend (Azure, etc.).
        private static readonly TimeSpan OffsetEcuador = TimeSpan.FromHours(-5);

        public TarifaService(IConfiguration config)
        {
            _tarifaPorKmSinCarga = config.GetValue<decimal>("Tarifas:TarifaPorKmSinCarga", 0.50m);
            _tarifaPorKmConCarga = config.GetValue<decimal>("Tarifas:TarifaPorKmConCarga", 0.80m);
            _banderazoDia = config.GetValue<decimal>("Tarifas:BanderazoDia", 0.42m);
            _banderazoNoche = config.GetValue<decimal>("Tarifas:BanderazoNoche", 0.46m);
            _tarifaMinima = config.GetValue<decimal>("Tarifas:TarifaMinima", 1.45m);
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
            var banderazo = EsHorarioNocturno() ? _banderazoNoche : _banderazoDia;

            var tarifaCalculada = banderazo + tarifaPorKm * (decimal)distanciaViaje;
            var tarifa = Math.Max(tarifaCalculada, _tarifaMinima);

            return (Math.Round(tarifa, 2), esInterprovincial);
        }

        // Horario nocturno: 19:00 a 05:59 hora de Ecuador (igual que el
        // recargo nocturno de los taxímetros reales en Ambato).
        private static bool EsHorarioNocturno()
        {
            var horaEcuador = DateTime.UtcNow + OffsetEcuador;
            return horaEcuador.Hour >= 19 || horaEcuador.Hour < 6;
        }

        private static double ARad(double grados) => grados * Math.PI / 180.0;
    }
}
