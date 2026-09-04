bool esCedulaEcuatorianaValida(String? cedula) {
  if (cedula == null) return false;
  cedula = cedula.trim();

  if (cedula.length != 10 || !RegExp(r'^\d{10}$').hasMatch(cedula)) return false;

  final digitos = cedula.split('').map(int.parse).toList();

  final provincia = digitos[0] * 10 + digitos[1];
  if (provincia < 1 || (provincia > 24 && provincia != 30)) return false;

  if (digitos[2] >= 6) return false;

  const coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
  var suma = 0;
  for (var i = 0; i < 9; i++) {
    var valor = digitos[i] * coeficientes[i];
    if (valor >= 10) valor -= 9;
    suma += valor;
  }

  final digitoVerificador = (10 - (suma % 10)) % 10;
  return digitoVerificador == digitos[9];
}

bool esCorreoValido(String? correo) {
  if (correo == null) return false;
  return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(correo.trim());
}
