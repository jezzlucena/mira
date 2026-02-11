/**
 * Parallax movement for hero blobs on scroll.
 */
export function initParallax() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const blobs = document.querySelectorAll('.blob');
  if (!blobs.length) return;

  let ticking = false;

  function onScroll() {
    if (ticking) return;
    ticking = true;

    requestAnimationFrame(() => {
      const scrollY = window.scrollY;
      blobs.forEach((blob, i) => {
        const speed = 0.08 + i * 0.04;
        blob.style.transform = `translateY(${scrollY * speed}px)`;
      });
      ticking = false;
    });
  }

  window.addEventListener('scroll', onScroll, { passive: true });
}
