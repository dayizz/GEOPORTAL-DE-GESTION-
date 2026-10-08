{{flutter_js}}
{{flutter_build_config}}

(async () => {
  // Retira únicamente el caché de Flutter antes de iniciar la aplicación.
  // No se registra otro service worker: Hosting controla la actualización.
  const isFlutterWorker = (worker) => worker &&
    new URL(worker.scriptURL, window.location.href).pathname.endsWith('/flutter_service_worker.js');
  let reloadRequired = false;
  try {
    if ('serviceWorker' in navigator) {
      const controlled = isFlutterWorker(navigator.serviceWorker.controller);
      const registrations = await navigator.serviceWorker.getRegistrations();
      for (const registration of registrations) {
        if ([registration.active, registration.waiting, registration.installing].some(isFlutterWorker)) {
          const removed = await registration.unregister();
          reloadRequired = reloadRequired || (controlled && removed);
        }
      }
    }
    if ('caches' in window) {
      const flutterCaches = new Set(['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest']);
      const names = await window.caches.keys();
      await Promise.all(names.filter((name) => flutterCaches.has(name))
        .map((name) => window.caches.delete(name)));
    }
  } catch (error) {
    console.warn('No se pudo retirar el caché anterior de Flutter.', error);
  }

  // Un worker desregistrado sigue controlando la pestaña hasta la recarga.
  const url = new URL(window.location.href);
  if (reloadRequired && url.searchParams.get('web_update') !== 'network-v1') {
    url.searchParams.set('web_update', 'network-v1');
    window.location.replace(url.href);
    return;
  }
  await _flutter.loader.load();
})();
