/**
 * Script de un solo uso: asigna `rango_estatus` / `rango_estatus_fecha` a
 * los predios que ya existían en Firestore antes de introducir el campo
 * "Rango de estatus" (extensión detallada de "Estatus"). Para cada predio
 * sin `rango_estatus`, infiere 'Liberado' si `cop === true`, si no
 * 'No liberado' — el mismo criterio binario que ya se mostraba en Gestión.
 *
 * Uso:
 *   1. Firebase Console → Configuración del proyecto → Cuentas de servicio
 *      → "Generar nueva clave privada". Descarga el JSON.
 *   2. GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/tu-clave.json \
 *        node functions/scripts/backfillRangoEstatus.js
 *   3. Borra el archivo de la clave al terminar; nunca lo subas al repo.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

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
  const pendientes = snap.docs.filter((doc) => !doc.data().rango_estatus);
  console.log(
    `Encontrados ${snap.size} predios, ${pendientes.length} sin rango_estatus. Migrando...`,
  );

  const ahora = new Date().toISOString();
  let procesados = 0;
  let batch = db.batch();
  let enBatch = 0;

  for (const doc of pendientes) {
    const rango = doc.data().cop === true ? 'Liberado' : 'No liberado';
    batch.update(doc.ref, {
      rango_estatus: rango,
      rango_estatus_fecha: ahora,
    });
    enBatch += 1;
    procesados += 1;

    if (enBatch >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      enBatch = 0;
      console.log(`  ${procesados}/${pendientes.length} procesados...`);
    }
  }

  if (enBatch > 0) {
    await batch.commit();
  }

  console.log(`Listo. ${procesados} predios migrados con rango_estatus.`);
}

main().catch((err) => {
  console.error('Backfill falló:', err);
  process.exit(1);
});
