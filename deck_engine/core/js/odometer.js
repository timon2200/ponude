/**
 * odometer.js — Precision Animated Rolling Counter for Slide Navigation
 */
export function updateOdometer(currentSlide, totalSlides, direction = 'forward') {
  const curNumEl = document.getElementById('slideCurNum');
  if (curNumEl) {
    const newText = currentSlide < 10 ? `0${currentSlide}` : `${currentSlide}`;
    if (curNumEl.textContent !== newText) {
      curNumEl.classList.remove('roll-up', 'roll-down');
      void curNumEl.offsetWidth; // Force reflow
      curNumEl.textContent = newText;
      curNumEl.classList.add(direction === 'forward' ? 'roll-up' : 'roll-down');
    }
  }

  const totNumEl = document.getElementById('slideTotNum');
  if (totNumEl) {
    const totText = totalSlides < 10 ? `0${totalSlides}` : `${totalSlides}`;
    if (totNumEl.textContent !== totText) {
      totNumEl.textContent = totText;
    }
  }
}

window.updateOdometer = updateOdometer;
