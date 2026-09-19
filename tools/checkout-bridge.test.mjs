import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../web/checkout-bridge.js', import.meta.url), 'utf8');
const details = JSON.stringify({ key: 'test-only-key', order_id: 'order_test', amount: 100 });
function setup() {
  let instance;
  class Checkout {
    constructor(options) { this.options = options; instance = this; }
    on(name, callback) { this.failure = callback; }
    open() { this.opened = true; }
    close() { this.closed = true; this.options.modal.ondismiss(); }
  }
  const context = vm.createContext({ Razorpay: Checkout, setTimeout, clearTimeout });
  vm.runInContext(source, context);
  return { context, instance: () => instance };
}
test('only matching complete callback is forwarded once; dismissal after success is ignored', async () => {
  const { context, instance } = setup();
  const successes = [], failures = [];
  context.bakalooCheckoutOpen(details, value => successes.push(JSON.parse(value)), value => failures.push(value));
  await new Promise(setImmediate);
  const checkout = instance();
  assert.equal(checkout.opened, true);
  const callback = { razorpay_order_id: 'order_test', razorpay_payment_id: 'pay_test', razorpay_signature: 'test-signature' };
  checkout.options.handler(callback);
  checkout.options.handler(callback);
  checkout.options.modal.ondismiss();
  assert.deepEqual(successes, [{ paymentId: 'pay_test', signature: 'test-signature' }]);
  assert.deepEqual(failures, []);
});
test('mismatched order, SDK failure and dismissal require reconciliation, never success', async () => {
  for (const action of ['mismatch', 'failure', 'dismiss']) {
    const { context, instance } = setup();
    const failures = [];
    context.bakalooCheckoutOpen(details, () => assert.fail('Unexpected success'), value => failures.push(value));
    await new Promise(setImmediate);
    const checkout = instance();
    if (action === 'mismatch') checkout.options.handler({ razorpay_order_id: 'different', razorpay_payment_id: 'pay_test', razorpay_signature: 'sig' });
    if (action === 'failure') checkout.failure();
    checkout.options.modal.ondismiss();
    assert.deepEqual(failures, [-1]);
  }
});
test('active checkout cannot be opened twice; disposal prevents late callbacks', async () => {
  const { context, instance } = setup();
  context.bakalooCheckoutOpen(details, () => assert.fail('Late success'), () => assert.fail('Late failure'));
  assert.throws(() => context.bakalooCheckoutOpen(details, () => {}, () => {}), /already active/);
  await new Promise(setImmediate);
  context.bakalooCheckoutDispose();
  assert.equal(instance().closed, true);
});
test('SDK loading failure becomes one recoverable failure', async () => {
  let script;
  const context = vm.createContext({ setTimeout, clearTimeout, document: { createElement: () => ({ remove() {} }), head: { appendChild: element => script = element } } });
  vm.runInContext(source, context);
  const failures = [];
  context.bakalooCheckoutOpen(details, () => assert.fail('Unexpected success'), value => failures.push(value));
  assert.equal(script.src, 'https://checkout.razorpay.com/v1/checkout.js');
  script.onerror();
  await new Promise(setImmediate);
  assert.deepEqual(failures, [-1]);
});
