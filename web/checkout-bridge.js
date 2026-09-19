(function (scope) {
  'use strict';
  let sdkPromise;
  let active;
  function loadSdk() {
    if (typeof scope.Razorpay === 'function') return Promise.resolve();
    if (sdkPromise) return sdkPromise;
    sdkPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.async = true;
      const timer = setTimeout(() => fail(), 15000);
      function fail() { clearTimeout(timer); script.remove(); sdkPromise = undefined; reject(new Error('Checkout unavailable')); }
      script.onerror = fail;
      script.onload = () => { clearTimeout(timer); if (typeof scope.Razorpay === 'function') resolve(); else fail(); };
      document.head.appendChild(script);
    });
    return sdkPromise;
  }
  scope.bakalooCheckoutOpen = function (json, onSuccess, onFailure) {
    if (active) throw new Error('Checkout already active');
    const options = JSON.parse(json);
    if (!options.key || !options.order_id || !Number.isInteger(options.amount) || options.amount <= 0) throw new Error('Invalid checkout details');
    const attempt = { done: false, instance: null };
    active = attempt;
    function finish(callback, value) {
      if (attempt.done || active !== attempt) return;
      attempt.done = true;
      active = undefined;
      callback(value);
    }
    // Closing the Web modal does not prove the bank transaction was cancelled.
    // The shared Dart flow reconciles ambiguous results with the backend.
    options.modal = { confirm_close: true, ondismiss: () => finish(onFailure, -1) };
    options.retry = { enabled: false };
    options.handler = response => {
      if (response.razorpay_order_id !== options.order_id || !response.razorpay_payment_id || !response.razorpay_signature) return finish(onFailure, -1);
      finish(onSuccess, JSON.stringify({ paymentId: response.razorpay_payment_id, signature: response.razorpay_signature }));
    };
    loadSdk().then(() => {
      if (attempt.done) return;
      attempt.instance = new scope.Razorpay(options);
      attempt.instance.on('payment.failed', () => finish(onFailure, -1));
      attempt.instance.open();
    }).catch(() => finish(onFailure, -1));
  };
  scope.bakalooCheckoutDispose = function () {
    if (!active) return;
    active.done = true;
    active.instance?.close();
    active = undefined;
  };
})(globalThis);
