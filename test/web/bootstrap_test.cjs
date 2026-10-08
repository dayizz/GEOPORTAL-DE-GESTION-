const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync('web/flutter_bootstrap.js', 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

async function run({ controlled = false, fail = false, migrated = false } = {}) {
  const events = [];
  const worker = { scriptURL: 'https://example.com/flutter_service_worker.js' };
  const other = { scriptURL: 'https://example.com/other-worker.js' };
  const href = 'https://example.com/?filter=S13' + (migrated ? '&web_update=network-v1' : '') + '#/balance';
  const context = {
    URL, console: { warn: () => events.push('warning') },
    navigator: { serviceWorker: {
      controller: controlled ? worker : null,
      getRegistrations: async () => {
        if (fail) throw new Error('denied');
        return [
          { active: worker, unregister: async () => { events.push('unregister'); return true; } },
          { active: other, unregister: async () => { throw new Error('unrelated worker'); } },
        ];
      },
    } },
    window: {
      location: { href, replace: (url) => events.push(url) },
      caches: {
        keys: async () => ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest', 'user-files'],
        delete: async (name) => { events.push(name); return true; },
      },
    },
    _flutter: { loader: { load: async (options) => {
      assert.equal(options, undefined);
      events.push('load');
    } } },
  };
  await vm.runInNewContext(script, context);
  return events;
}

test('cleans only Flutter resources before loading without a worker', async () => {
  assert.deepEqual(await run(), ['unregister', 'flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest', 'load']);
});
test('old controlled tab reloads, preserving query and route', async () => {
  const events = await run({ controlled: true });
  assert.equal(events.at(-1), 'https://example.com/?filter=S13&web_update=network-v1#/balance');
  assert.ok(!events.includes('load'));
});
test('migration cannot cause a reload loop', async () => {
  assert.equal((await run({ controlled: true, migrated: true })).at(-1), 'load');
});
test('cache API failure does not prevent app startup', async () => {
  assert.deepEqual(await run({ fail: true }), ['warning', 'load']);
});
