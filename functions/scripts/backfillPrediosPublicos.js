/**
 * Script de un solo uso: pobla `predios_publicos` con los predios que ya
 * existían en Firestore antes de desplegar la Cloud Function
 * `sincronizarPredioPublico` (esa función solo reacciona a escrituras
 * futuras, no reprocesa el historial).
 *
 * Uso:
 *   1. Firebase Console → Configuración del proyecto → Cuentas de servicio
 *      → "Generar nueva clave privada". Descarga el JSON.
 *   2. GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/tu-clave.json \
 *        node functions/scripts/backfillPrediosPublicos.js
 *   3. Borra el archivo de la clave al terminar; nunca lo subas al repo.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { sanitizarPredio } = require('../sanitize');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error(
    'Falta GOOGLE_APPLICATION_CREDENTIALS. Exporta la ruta al JSON de la ' +
    'cuenta de servicio antes de correr este script (ver comentario arriba).',
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const BATCH_SIZE = 400;

async function main() {
  const snap = await db.collection('predios').get();
  console.log(`Encontrados ${snap.size} predios. Sincronizando a predios_publicos...`);

  let procesados = 0;
  let batch = db.batch();
  let enBatch = 0;

  for (const doc of snap.docs) {
    const publicRef = db.collection('predios_publicos').doc(doc.id);
    batch.set(publicRef, sanitizarPredio(doc.data()));
    enBatch += 1;
    procesados += 1;

    if (enBatch >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      enBatch = 0;
      console.log(`  ${procesados}/${snap.size} procesados...`);
    }
  }

  if (enBatch > 0) {
    await batch.commit();
  }

  console.log(`Listo. ${procesados} predios sincronizados a predios_publicos.`);
}

main().catch((err) => {
  console.error('Backfill falló:', err);
  process.exit(1);
});
