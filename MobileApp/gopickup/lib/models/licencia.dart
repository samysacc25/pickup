enum TipoLicencia { a, a1, b, c1, c, d1, d, e1Especial, e, f, g }

const Map<TipoLicencia, String> _codigosLicencia = {
  TipoLicencia.a: 'A',
  TipoLicencia.a1: 'A1',
  TipoLicencia.b: 'B',
  TipoLicencia.c1: 'C1',
  TipoLicencia.c: 'C',
  TipoLicencia.d1: 'D1',
  TipoLicencia.d: 'D',
  TipoLicencia.e1Especial: 'E1 Especial',
  TipoLicencia.e: 'E',
  TipoLicencia.f: 'F',
  TipoLicencia.g: 'G',
};

const Map<TipoLicencia, int> _numerosLicencia = {
  TipoLicencia.a: 1,
  TipoLicencia.a1: 2,
  TipoLicencia.b: 3,
  TipoLicencia.c1: 4,
  TipoLicencia.c: 5,
  TipoLicencia.d1: 6,
  TipoLicencia.d: 7,
  TipoLicencia.e1Especial: 8,
  TipoLicencia.e: 9,
  TipoLicencia.f: 10,
  TipoLicencia.g: 11,
};

String textoTipoLicencia(TipoLicencia tipo) => _codigosLicencia[tipo]!;
int tipoLicenciaANumero(TipoLicencia tipo) => _numerosLicencia[tipo]!;
