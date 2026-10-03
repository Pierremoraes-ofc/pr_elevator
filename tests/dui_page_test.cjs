const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../ui/script.js'), 'utf8');
function page(search = '') {
  const listeners = {}, callbacks = [];
  const elements = { '.display': [{ style: {}, textContent: '' }], '.keypad': [{ style: {} }], '.mouse': [{ style: {} }] };
  const context = { URLSearchParams, console,
    document: { querySelectorAll: selector => elements[selector] || [], getElementById: () => null,
      addEventListener: (name, fn) => { listeners[name] = fn; } },
    window: { location: { search, hostname: 'cfx-nui-pr_elevator' },
      addEventListener: (name, fn) => { listeners[name] = fn; } },
    GetParentResourceName: () => 'pr_elevator',
    fetch: (url, options) => { callbacks.push({url, options}); return Promise.resolve({}); }
  };
  vm.runInNewContext(source, context);
  return { elements, callbacks, message: data => listeners.message({data}), ready: () => listeners.DOMContentLoaded() };
}
const early = page('?dui=1');
early.message({ action: 'KEYPAD', value: true });
early.message({ action: 'DISPLAY', value: 'ANDAR' });
early.ready();
assert.equal(early.elements['.keypad'][0].style.display, 'flex', 'DOMContentLoaded must not hide an already visible DUI');
assert.equal(early.elements['.display'][0].textContent, 'ANDAR');
early.message({ action: 'DISPLAY', value: '12' });
assert.equal(early.elements['.display'][0].textContent, '12');
early.message({ action: 'DISPLAY', value: 'SENHA' });
assert.equal(early.elements['.display'][0].textContent, 'SENHA');
assert.equal(early.callbacks.length, 1);
assert.equal(early.callbacks[0].url, 'https://pr_elevator/keypadDuiReady');
const normal = page(); normal.ready();
assert.equal(normal.elements['.keypad'][0].style.display, 'none', 'Normal NUI must remain transparent without fullscreen keypad');
assert.equal(normal.callbacks.length, 0);
const cold = page('?dui=1'); cold.ready();
assert.equal(cold.elements['.keypad'][0].style.display, 'flex', 'DUI texture must render before the first Lua message');
early.message(null); early.message({action: 'BUTTON', value: 99});
console.log('PASS: early messages, DUI/overlay isolation, floor/digits/password display, ready callback and malformed message safety');
