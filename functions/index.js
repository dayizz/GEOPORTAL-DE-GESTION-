const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { sanitizarPredio } = require('./sanitize');

initializeApp();
const db = getFirestore();

const SIETE_DIAS_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Espeja cada predio hacia `predios_publicos`, saneando campos sensibles
 * (propietario, contacto, documentos) antes de exponerlos al Geoportal de
 * Consulta, que lee esa colección con reglas de lectura pública.
 */
exports.sincronizarPredioPublico = onDocumentWritten(
  'predios/{predioId}',
  async (event) => {
    const { predioId } = event.params;
    const publicRef = db.collection('predios_publicos').doc(predioId);

    const despuesExiste = event.data?.after?.exists;
    if (!despuesExiste) {
      await publicRef.delete().catch(() => {});
      return;
    }

    const data = event.data.after.data();
    await publicRef.set(sanitizarPredio(data));
  },
);

/**
 * Regla de negocio: un predio en rango de estatus "L nueva" pasa
 * automáticamente a "Liberado" tras 7 días de estar en ese rango. Corre una
 * vez al día; la escritura resultante dispara `sincronizarPredioPublico`
 * sola, por lo que aquí no se toca `predios_publicos` directamente.
 */
exports.actualizarLNuevaALiberado = onSchedule(
  { schedule: 'every 24 hours', timeZone: 'America/Mexico_City' },
  async () => {
    const snap = await db
      .collection('predios')
      .where('rango_estatus', '==', 'L nueva')
      .get();

    if (snap.empty) return;

    const ahora = new Date();
    let batch = db.batch();
    let enBatch = 0;

    for (const doc of snap.docs) {
      const fechaStr = doc.data().rango_estatus_fecha;
      const fecha = fechaStr ? new Date(fechaStr) : null;
      if (!fecha || Number.isNaN(fecha.getTime())) continue;
      if (ahora.getTime() - fecha.getTime() < SIETE_DIAS_MS) continue;

      batch.update(doc.ref, {
        rango_estatus: 'Liberado',
        rango_estatus_fecha: ahora.toISOString(),
        cop: true,
        negociacion: false,
      });
      enBatch += 1;

      if (enBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        enBatch = 0;
      }
    }

    if (enBatch > 0) {
      await batch.commit();
    }
  },
);
