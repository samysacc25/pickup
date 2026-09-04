namespace GoPickup.API.Services
{
    public static class CedulaEcuatorianaValidator
    {
        public static bool EsValida(string? cedula)
        {
            if (string.IsNullOrWhiteSpace(cedula) || cedula.Length != 10 || !cedula.All(char.IsDigit))
                return false;

            var digitos = cedula.Select(c => int.Parse(c.ToString())).ToArray();

            var provincia = digitos[0] * 10 + digitos[1];
            if (provincia < 1 || (provincia > 24 && provincia != 30))
                return false;

            if (digitos[2] >= 6) return false;

            var coeficientes = new[] { 2, 1, 2, 1, 2, 1, 2, 1, 2 };
            var suma = 0;
            for (var i = 0; i < 9; i++)
            {
                var valor = digitos[i] * coeficientes[i];
                if (valor >= 10) valor -= 9;
                suma += valor;
            }

            var digitoVerificador = (10 - (suma % 10)) % 10;
            return digitoVerificador == digitos[9];
        }
    }

    public class CedulaEcuatorianaAttribute : System.ComponentModel.DataAnnotations.ValidationAttribute
    {
        public CedulaEcuatorianaAttribute()
        {
            ErrorMessage = "El número de cédula ingresado no es válido.";
        }

        public override bool IsValid(object? value)
        {
            return CedulaEcuatorianaValidator.EsValida(value as string);
        }
    }
}
