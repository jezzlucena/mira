/**
 * Monthly/Yearly pricing toggle with animated number swap.
 */
export function initPricingToggle() {
  const toggle = document.querySelector('.pricing-toggle__switch');
  const monthlyLabel = document.querySelector('[data-toggle="monthly"]');
  const yearlyLabel = document.querySelector('[data-toggle="yearly"]');
  const priceEl = document.querySelector('[data-price]');
  const periodEl = document.querySelector('[data-period]');
  const saveBadge = document.querySelector('[data-save-badge]');

  if (!toggle || !priceEl) return;

  let isYearly = false;

  function update() {
    const price = isYearly ? '$17.99' : '$1.99';
    const period = isYearly ? '/year' : '/month';

    priceEl.classList.add('is-changing');

    setTimeout(() => {
      priceEl.textContent = price;
      if (periodEl) periodEl.textContent = period;
      priceEl.classList.remove('is-changing');
    }, 150);

    toggle.classList.toggle('is-yearly', isYearly);
    monthlyLabel?.classList.toggle('is-active', !isYearly);
    yearlyLabel?.classList.toggle('is-active', isYearly);
    if (saveBadge) saveBadge.style.opacity = isYearly ? '1' : '0';
  }

  toggle.addEventListener('click', () => {
    isYearly = !isYearly;
    update();
  });

  monthlyLabel?.addEventListener('click', () => {
    isYearly = false;
    update();
  });

  yearlyLabel?.addEventListener('click', () => {
    isYearly = true;
    update();
  });

  // Set initial state
  update();
}
