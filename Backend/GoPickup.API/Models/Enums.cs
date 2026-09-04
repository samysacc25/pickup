namespace GoPickup.API.Models
{
    public enum RolUsuario
    {
        Cliente = 1,
        Conductor = 2,
        Administrador = 3
    }

    public enum EstadoSolicitud
    {
        Buscando = 1,
        Aceptada = 2,
        EnCamino = 3,
        Iniciada = 4,
        Finalizada = 5,
        CanceladaCliente = 6,
        CanceladaConductor = 7,
        SinConductores = 8
    }

    public enum EstadoConductor
    {
        Desconectado = 0,
        Disponible = 1,
        EnViaje = 2,
        Ocupado = 3
    }

    public enum TipoCamioneta
    {
        Pequena = 1,
        Mediana = 2,
        Grande = 3
    }

    public enum MetodoPago
    {
        Efectivo = 1,
        Transferencia = 2,
        DeUna = 3
    }

    public enum EstadoSolicitudConductor
    {
        PendienteRevision = 1,
        Aprobada = 2,
        Rechazada = 3
    }

    public enum TipoLicencia
    {
        A = 1,
        A1 = 2,
        B = 3,
        C1 = 4,
        C = 5,
        D1 = 6,
        D = 7,
        E1Especial = 8,
        E = 9,
        F = 10,
        G = 11
    }
}
