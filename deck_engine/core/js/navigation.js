/**
 * navigation.js — Core Presentation Deck Navigation & Lifecycle Engine
 */
import { playTick, toggleSound } from './audio.js';
import { updateOdometer } from './odometer.js';
import { closeVideoModal } from './modal.js';

export class DeckNavigator {
  constructor(config = {}) {
    this.currentSlide = 1;
    this.totalSlides = config.totalSlides || 6;
    this.slideTitles = config.slideTitles || [];
    this.isTransitioning = false;
    this.autoplayInterval = null;
    this.buttonPressState = {
      btnPrev: { isKeyDown: false, pressStartTime: 0, timer: null },
      btnNext: { isKeyDown: false, pressStartTime: 0, timer: null }
    };

    this.init();
  }

  init() {
    this.setupUrlRouting();
    this.setupKeyboard();
    this.setupWheel();
    this.setupTouch();
    this.updateUI();
  }

  setupUrlRouting() {
    const urlParams = new URLSearchParams(window.location.search);
    const hashSlide = parseInt(window.location.hash.replace('#', ''));
    const initialSlide = parseInt(urlParams.get('slide')) || hashSlide || 1;

    if (initialSlide >= 1 && initialSlide <= this.totalSlides) {
      this.currentSlide = initialSlide;
    }

    if (urlParams.get('scroll') === 'bottom') {
      setTimeout(() => {
        const activeEl = document.querySelector('.slide.active');
        if (activeEl) activeEl.scrollTop = activeEl.scrollHeight;
      }, 50);
    }
  }

  updateUI(direction = 'forward') {
    // 1. Update Slides
    const slides = document.querySelectorAll('.slide');
    slides.forEach((s) => {
      const slideNum = parseInt(s.getAttribute('data-slide') || s.getAttribute('data-index'));
      if (slideNum === this.currentSlide) {
        s.classList.add('active');
        s.scrollTop = 0;
      } else {
        s.classList.remove('active');
      }
    });

    // 2. Update Dots / Pills
    const dots = document.querySelectorAll('.slide-dot');
    dots.forEach((d) => {
      const idx = parseInt(d.getAttribute('data-slide-index') || d.getAttribute('data-index'));
      d.classList.remove('morph-forward', 'morph-backward');
      if (idx === this.currentSlide) {
        d.classList.add('active');
        d.classList.remove('completed');
        void d.offsetWidth; // Force reflow for animation
        if (direction === 'forward') {
          d.classList.add('morph-forward');
        } else if (direction === 'backward') {
          d.classList.add('morph-backward');
        }
      } else {
        d.classList.remove('active');
        if (idx < this.currentSlide) {
          d.classList.add('completed');
        } else {
          d.classList.remove('completed');
        }
      }
    });

    // 3. Update Rolling Odometer
    updateOdometer(this.currentSlide, this.totalSlides, direction);

    // 4. Update Footer Slide Title
    const titleEl = document.getElementById('slideTitleText');
    if (titleEl && this.slideTitles.length >= this.currentSlide) {
      titleEl.classList.add('fade-change');
      setTimeout(() => {
        titleEl.textContent = this.slideTitles[this.currentSlide - 1];
        titleEl.classList.remove('fade-change');
      }, 120);
    }

    // 5. Update Nav Buttons
    const btnPrev = document.getElementById('btnPrev');
    const btnNext = document.getElementById('btnNext');
    if (btnPrev) btnPrev.disabled = (this.currentSlide === 1);
    if (btnNext) btnNext.disabled = (this.currentSlide === this.totalSlides);
  }

  navigate(direction) {
    if (this.isTransitioning) return;
    const prevSlideNum = this.currentSlide;

    if (direction === 'forward' && this.currentSlide < this.totalSlides) {
      this.currentSlide++;
    } else if (direction === 'backward' && this.currentSlide > 1) {
      this.currentSlide--;
    }

    if (prevSlideNum === this.currentSlide) return;

    playTick(direction);
    if (window.triggerCanvasUiWind) window.triggerCanvasUiWind(direction);

    if (!document.startViewTransition) {
      this.updateUI(direction);
      return;
    }

    this.isTransitioning = true;
    const transition = document.startViewTransition({
      update: () => {
        this.updateUI(direction);
      },
      types: [direction]
    });

    transition.finished.finally(() => {
      this.isTransitioning = false;
    });
  }

  nextSlide() {
    this.navigate('forward');
  }

  prevSlide() {
    this.navigate('backward');
  }

  goToSlide(target) {
    if (target === this.currentSlide || this.isTransitioning) return;
    const direction = target > this.currentSlide ? 'forward' : 'backward';
    this.currentSlide = target;
    playTick(direction);
    if (window.triggerCanvasUiWind) window.triggerCanvasUiWind(direction);

    if (!document.startViewTransition) {
      this.updateUI(direction);
      return;
    }

    this.isTransitioning = true;
    const transition = document.startViewTransition({
      update: () => {
        this.updateUI(direction);
      },
      types: [direction]
    });

    transition.finished.finally(() => {
      this.isTransitioning = false;
    });
  }

  triggerButtonPress(buttonId) {
    const btn = document.getElementById(buttonId);
    if (!btn) return;
    const state = this.buttonPressState[buttonId];
    if (!state) return;

    state.isKeyDown = true;
    state.pressStartTime = Date.now();
    btn.classList.add('pressed');

    if (state.timer) {
      clearTimeout(state.timer);
      state.timer = null;
    }
  }

  triggerButtonRelease(buttonId) {
    const btn = document.getElementById(buttonId);
    if (!btn) return;
    const state = this.buttonPressState[buttonId];
    if (!state) return;

    state.isKeyDown = false;
    const elapsed = Date.now() - state.pressStartTime;
    const minDuration = 140;

    if (elapsed < minDuration) {
      state.timer = setTimeout(() => {
        if (!state.isKeyDown) {
          btn.classList.remove('pressed');
        }
      }, minDuration - elapsed);
    } else {
      btn.classList.remove('pressed');
    }
  }

  clearAllButtonPresses() {
    ['btnPrev', 'btnNext'].forEach(id => {
      const btn = document.getElementById(id);
      const state = this.buttonPressState[id];
      if (state) {
        state.isKeyDown = false;
        if (state.timer) clearTimeout(state.timer);
      }
      if (btn) btn.classList.remove('pressed');
    });
  }

  setupKeyboard() {
    window.addEventListener('keydown', (e) => {
      const modal = document.getElementById('videoModal');
      if (modal && modal.classList.contains('active')) {
        if (e.key === 'Escape') closeVideoModal();
        return;
      }

      if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown' || e.key === 'Enter') {
        e.preventDefault();
        this.triggerButtonPress('btnNext');
        this.nextSlide();
      } else if (e.key === 'ArrowLeft' || e.key === 'PageUp' || e.key === 'Backspace') {
        e.preventDefault();
        this.triggerButtonPress('btnPrev');
        this.prevSlide();
      } else if (e.key === 'f' || e.key === 'F') {
        if (!document.fullscreenElement) {
          document.documentElement.requestFullscreen().catch(() => {});
        } else {
          document.exitFullscreen().catch(() => {});
        }
      } else if (e.key === 'm' || e.key === 'M') {
        toggleSound();
      } else if (e.key >= '1' && e.key <= String(this.totalSlides)) {
        this.goToSlide(parseInt(e.key));
      }
    });

    window.addEventListener('keyup', (e) => {
      if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown' || e.key === 'Enter') {
        this.triggerButtonRelease('btnNext');
      } else if (e.key === 'ArrowLeft' || e.key === 'PageUp' || e.key === 'Backspace') {
        this.triggerButtonRelease('btnPrev');
      }
    });

    window.addEventListener('blur', () => this.clearAllButtonPresses());
  }

  setupWheel() {
    let wheelDebounceTimer = null;
    let isWheelLocked = false;
    window.addEventListener('wheel', (e) => {
      const modal = document.getElementById('videoModal');
      if (modal && modal.classList.contains('active')) return;
      if (isWheelLocked) return;

      if (window.innerWidth <= 768) return;

      const activeSlideEl = document.querySelector('.slide.active');
      if (activeSlideEl) {
        const isScrollable = activeSlideEl.scrollHeight > (activeSlideEl.clientHeight + 8);
        if (isScrollable) {
          const atTop = activeSlideEl.scrollTop <= 5;
          const atBottom = activeSlideEl.scrollTop + activeSlideEl.clientHeight >= (activeSlideEl.scrollHeight - 6);
          if (e.deltaY > 0 && !atBottom) return;
          if (e.deltaY < 0 && !atTop) return;
        }
      }

      const delta = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
      if (Math.abs(delta) > 45) {
        isWheelLocked = true;
        if (delta > 0) {
          this.nextSlide();
        } else {
          this.prevSlide();
        }
        clearTimeout(wheelDebounceTimer);
        wheelDebounceTimer = setTimeout(() => {
          isWheelLocked = false;
        }, 500);
      }
    }, { passive: true });
  }

  setupTouch() {
    let touchStartX = 0;
    let touchStartY = 0;
    window.addEventListener('touchstart', (e) => {
      touchStartX = e.touches[0].clientX;
      touchStartY = e.touches[0].clientY;
    }, { passive: true });

    window.addEventListener('touchend', (e) => {
      const diffX = e.changedTouches[0].clientX - touchStartX;
      const diffY = e.changedTouches[0].clientY - touchStartY;
      if (Math.abs(diffX) > 50 && Math.abs(diffX) > Math.abs(diffY)) {
        if (diffX < 0) {
          this.nextSlide();
        } else {
          this.prevSlide();
        }
      }
    }, { passive: true });
  }
}
