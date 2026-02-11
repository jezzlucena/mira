/**
 * Staggered row-by-row reveal for the comparison table.
 */
export function initComparisonChart() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    document.querySelectorAll('.comparison-table tbody tr').forEach((row) => {
      row.classList.add('is-visible');
    });
    return;
  }

  const table = document.querySelector('.comparison-table');
  if (!table) return;

  const rows = table.querySelectorAll('tbody tr');

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          rows.forEach((row, i) => {
            setTimeout(() => row.classList.add('is-visible'), i * 80);
          });
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.2 }
  );

  observer.observe(table);
}
