import { initScrollAnimations } from './scroll-animations.js';
import { initParallax } from './parallax.js';
import { initComparisonChart } from './comparison-chart.js';
import { initPricingToggle } from './pricing-toggle.js';

/* ---- Nav scroll effect ---- */
function initNav() {
  const nav = document.querySelector('.nav');
  if (!nav) return;

  function onScroll() {
    nav.classList.toggle('is-scrolled', window.scrollY > 10);
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // Hamburger toggle
  const hamburger = document.querySelector('.nav__hamburger');
  const mobileMenu = document.querySelector('.nav__mobile-menu');

  if (hamburger && mobileMenu) {
    hamburger.addEventListener('click', () => {
      hamburger.classList.toggle('is-open');
      mobileMenu.classList.toggle('is-open');
    });

    // Close on link click
    mobileMenu.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        hamburger.classList.remove('is-open');
        mobileMenu.classList.remove('is-open');
      });
    });
  }
}

/* ---- Correlation bar fill ---- */
function initCorrelationBar() {
  const bar = document.querySelector('.correlation-bar__fill');
  if (!bar) return;

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    bar.classList.add('is-visible');
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          bar.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.5 }
  );

  observer.observe(bar);
}

/* ---- Boot ---- */
document.addEventListener('DOMContentLoaded', () => {
  initNav();
  initScrollAnimations();
  initParallax();
  initComparisonChart();
  initPricingToggle();
  initCorrelationBar();
});
