import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/reportes/utils/balance_calculos.dart';

void main() {
  test('tipos de liberación cuenta solo liberados y conserva las siete opciones', () {
    Predio registro(String? tipo, String estatus) => Predio(
      id: '$tipo-$estatus', claveCatastral: '1', tramo: 'T1',
      tipoPropiedad: 'PRIVADA', createdAt: DateTime(2026),
      tipoLiberacion: tipo, rangoEstatus: estatus,
    );
    final conteos = tiposDeRegistrosLiberados([
      registro('COP', 'Liberado'),
      registro('COP', 'Negociacion'),
      registro('DOT', 'No liberado'),
      registro('ESPROPIACION', 'Liberado'),
      registro(' anuencia por oficio ', 'Con ingreso'),
      registro(null, 'Liberado'),
    ]);
    expect(conteos.keys, ['COP', 'DOT', 'AOP', 'EXPROPIACION', 'ANUENCIA POR OFICIO', 'MINUTA', 'SIN TIPO']);
    expect(conteos.values, [1, 0, 0, 1, 1, 0, 1]);
    expect(tiposDeRegistrosLiberados([]).values.every((v) => v == 0), isTrue);
  });
  test('la dona conserva los ocho estatus y consolida acentos y mayúsculas', () {
    final entries = ordenarRangoEstatus({
      'Liberado': 2,
      'negociación': 3,
      'Negociacion': 1,
      'investigacion': 2,
    });
    expect(entries.map((e) => e.key), Predio.rangoEstatusOpciones);
    expect(Map.fromEntries(entries)['Negociacion'], 4);
    expect(Map.fromEntries(entries)['Investigación'], 2);
    expect(Map.fromEntries(entries)['Posible DOT'], 0);
    expect(entries.fold<int>(0, (sum, e) => sum + e.value), 8);
    expect(ordenarRangoEstatus({}).every((e) => e.value == 0), isTrue);
  });
  test('clasifica variantes del catálogo y conserva otros tipos separados', () {
    for (final tipo in [
      'Estación',
      ' estacion ',
      'Edificio auxiliar',
      'ZICA',
      'sica',
    ]) {
      expect(
        grupoInfraestructuraBalance(tipo),
        GrupoInfraestructuraBalance.estacionesEdificios,
      );
    }
    for (final tipo in ['viaducto', 'Troncal', 'DDV Troncal', 'CARRETERA']) {
      expect(
        grupoInfraestructuraBalance(tipo),
        GrupoInfraestructuraBalance.predios,
      );
    }
    expect(
      grupoInfraestructuraBalance('Sin afectación'),
      GrupoInfraestructuraBalance.sinAfectacion,
    );
    for (final tipo in [null, '', '  ', 'null', 'NULO']) {
      expect(
        grupoInfraestructuraBalance(tipo),
        GrupoInfraestructuraBalance.nulos,
      );
    }
    expect(
      grupoInfraestructuraBalance('Cruce/Transversal'),
      GrupoInfraestructuraBalance.cruces,
    );
    expect(
      grupoInfraestructuraBalance('cruces/transversales'),
      GrupoInfraestructuraBalance.cruces,
    );
    expect(
      grupoInfraestructuraBalance('Desconocido'),
      GrupoInfraestructuraBalance.otros,
    );
  });

  test('el balance usa superficie para estaciones y km efectivos para predios', () {
    final estacion = Predio(
      id: 'estacion', claveCatastral: '1', tramo: 'T1',
      tipoPropiedad: 'PRIVADA', createdAt: DateTime(2026),
      estructura: 'Estación', superficie: 1250, kmEfectivos: 3.5,
    );
    final predio = Predio(
      id: 'predio', claveCatastral: '2', tramo: 'T1',
      tipoPropiedad: 'PRIVADA', createdAt: DateTime(2026),
      estructura: 'Viaducto', superficie: 900, kmEfectivos: 2.25,
    );

    expect(
      medidaPredioBalance(estacion, usaM2: true),
      1250,
    );
    expect(
      medidaPredioBalance(predio, usaM2: false),
      2.25,
    );
  });

  test(
    'los grupos no duplican registros ni mezclan liberados o kilómetros',
    () {
      final tipos = [
        'Viaducto',
        'Troncal',
        'Carretera',
        'Estacion',
        'Edificio auxiliar',
        'ZICA',
        'Sin afectación',
        null,
        'Cruce/Transversal',
      ];
      final registros = [
        for (var i = 0; i < tipos.length; i++)
          Predio(
            id: '$i',
            claveCatastral: '$i',
            tramo: 'T1',
            tipoPropiedad: 'PRIVADA',
            createdAt: DateTime(2026),
            estructura: tipos[i],
            rangoEstatus: i == 1 ? 'No liberado' : 'Liberado',
            kmEfectivos: 1,
          ),
      ];
      final grupos = agruparInfraestructuraBalance(registros);
      expect(grupos.values.map((g) => g.length), [3, 3, 1, 1, 1, 0]);
      final todos = grupos.values.expand((g) => g).toList();
      expect(todos.length, registros.length);
      expect(todos.map((p) => p.id).toSet().length, registros.length);
      final predios = grupos[GrupoInfraestructuraBalance.predios]!;
      expect(predios.where(predioEstaLiberado).length, 2);
      expect(
        predios
            .where(predioEstaLiberado)
            .fold<double>(0, (s, p) => s + (p.kmEfectivos ?? 0)),
        2,
      );
      expect(
        grupos[GrupoInfraestructuraBalance.estacionesEdificios]!
            .where(predioEstaLiberado)
            .length,
        3,
      );
      expect(
        agruparInfraestructuraBalance([]).values.every((g) => g.isEmpty),
        isTrue,
      );
    },
  );
}
