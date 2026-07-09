import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/carga/utils/imported_file_cleanup.dart';

void main() {
  group('extractClavesFromFeatures', () {
    test('normalizes and deduplicates clave catastral values', () {
      final claves = extractClavesFromFeatures([
        {
          'properties': {'CLAVE_CATASTRAL': ' abc-123 '},
        },
        {
          'properties': {'clave_catastral': 'ABC-123'},
        },
        {
          'properties': {'clave catastral': 'xyz-999'},
        },
        {
          'properties': {'sin_clave': 'n/a'},
        },
      ]);

      expect(claves, {'ABC-123', 'XYZ-999'});
    });
  });

  group('shouldClearImportedMapAfterFileDeletion', () {
    test('returns true when the same feature list instance is active', () {
      final features = [
        {
          'type': 'Feature',
          'properties': {'clave_catastral': 'ABC-123'},
        },
      ];

      final shouldClear = shouldClearImportedMapAfterFileDeletion(
        currentImported: features,
        fileFeatures: features,
      );

      expect(shouldClear, isTrue);
    });

    test('returns true when the active import matches by first feature content', () {
      final shouldClear = shouldClearImportedMapAfterFileDeletion(
        currentImported: [
          {
            'type': 'Feature',
            'properties': {'clave_catastral': 'ABC-123'},
          },
        ],
        fileFeatures: [
          {
            'type': 'Feature',
            'properties': {'clave_catastral': 'ABC-123'},
          },
        ],
      );

      expect(shouldClear, isTrue);
    });

    test('returns false when imported content does not match the deleted file', () {
      final shouldClear = shouldClearImportedMapAfterFileDeletion(
        currentImported: [
          {
            'type': 'Feature',
            'properties': {'clave_catastral': 'ABC-123'},
          },
        ],
        fileFeatures: [
          {
            'type': 'Feature',
            'properties': {'clave_catastral': 'XYZ-999'},
          },
        ],
      );

      expect(shouldClear, isFalse);
    });
  });
}