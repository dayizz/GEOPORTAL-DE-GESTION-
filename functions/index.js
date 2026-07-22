const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { sanitizarPredio } = require('./sanitize');

initializeApp();
const db = getFirestore();

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
