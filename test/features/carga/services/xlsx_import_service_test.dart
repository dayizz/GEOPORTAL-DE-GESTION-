import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/carga/services/xlsx_import_service.dart';

Uint8List _buildXlsx(List<String> headers, List<List<String>> rows) {
  final workbook = Excel.createExcel();
  final sheetName = workbook.getDefaultSheet()!;
  final sheet = workbook[sheetName];
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
  for (final row in rows) {
    sheet.appendRow(row.map((v) => TextCellValue(v)).toList());
  }
  return Uint8List.fromList(workbook.save()!);
}

void main() {
  final service = XlsxImportService();

  group('XlsxImportService.parse — clave catastral header detection', () {
    test('recognizes common clave column header spellings', () {
      for (final header in ['Clave Catastral', 'CLAVE', 'Clave', 'clave_catastral', 'Folio']) {
        final bytes = _buildXlsx(
          [header, 'Tramo', 'Tipo de propiedad'],
          [
            ['ABC-123', 'T1', 'PRIVADA'],
          ],
        );
        final result = service.parse(bytes);
        final faltantes = filasPrediosSinClave(result);
        expect(faltantes.isEmpty, isTrue, reason: 'header "$header" should resolve to clave_catastral');
      }
    });

    test('flags every row and reports detected headers when the clave column is unrecognized', () {
      final bytes = _buildXlsx(
        ['Identificador unico', 'Tramo', 'Tipo de propiedad'],
        [
          ['ABC-123', 'T1', 'PRIVADA'],
          ['XYZ-999', 'T2', 'SOCIAL'],
        ],
      );
      final result = service.parse(bytes);
      final faltantes = filasPrediosSinClave(result);

      expect(faltantes.registros.length, 2);
      expect(faltantes.encabezadosPorHojaSinNinguna, isNotEmpty);
      final headers = faltantes.encabezadosPorHojaSinNinguna.values.first;
      expect(headers, contains('Identificador unico'));
    });

    test('does not flag rows when clave is present via a less common alias', () {
      final bytes = _buildXlsx(
        ['No. Predio', 'Tramo', 'Tipo de propiedad'],
        [
          ['001', 'T1', 'PRIVADA'],
        ],
      );
      final result = service.parse(bytes);
      final faltantes = filasPrediosSinClave(result);
      expect(faltantes.isEmpty, isTrue);
    });
  });
}
