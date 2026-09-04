namespace GoPickup.API.Services
{
    public interface IPasswordService
    {
        string Hash(string clave);
        bool Verificar(string clave, string hash);
    }

    public class PasswordService : IPasswordService
    {
        public string Hash(string clave) => BCrypt.Net.BCrypt.HashPassword(clave);
        public bool Verificar(string clave, string hash) => BCrypt.Net.BCrypt.Verify(clave, hash);
    }
}
