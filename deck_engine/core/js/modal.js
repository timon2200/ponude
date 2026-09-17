/**
 * modal.js — Cinema Video Lightbox Modal Controller
 */
export function openVideoModal(videoId, title) {
  const modal = document.getElementById('videoModal');
  const iframe = document.getElementById('videoIframe');
  const titleEl = document.getElementById('videoModalTitle');
  const ytLink = document.getElementById('btnWatchOnYt');
  const shimmer = document.getElementById('videoLoadingShimmer');

  if (!modal || !iframe) return;

  if (titleEl) {
    // Strip hashtags or format gracefully if needed, while keeping full title legible
    titleEl.textContent = title || 'Video Preview';
  }

  if (ytLink) {
    ytLink.href = `https://youtu.be/${videoId}`;
  }
  
  if (shimmer) {
    shimmer.style.opacity = '1';
    shimmer.style.display = 'flex';
  }

  iframe.src = `https://www.youtube.com/embed/${videoId}?autoplay=1&rel=0&modestbranding=1&enablejsapi=1&playsinline=1`;

  iframe.onload = () => {
    if (shimmer) {
      shimmer.style.opacity = '0';
      setTimeout(() => {
        if (shimmer) shimmer.style.display = 'none';
      }, 300);
    }
  };

  modal.classList.add('active');
  document.body.style.overflow = 'hidden';
}

export function closeVideoModal() {
  const modal = document.getElementById('videoModal');
  const iframe = document.getElementById('videoIframe');
  if (!modal || !iframe) return;
  
  iframe.src = "";
  modal.classList.remove('active');
  document.body.style.overflow = '';
}

export function initVideoModal() {
  const modal = document.getElementById('videoModal');
  if (!modal) return;
  
  // Close on Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modal.classList.contains('active')) {
      closeVideoModal();
    }
  });

  // Close on Backdrop click
  modal.addEventListener('click', (e) => {
    if (e.target === modal || e.target.classList.contains('video-modal-backdrop')) {
      closeVideoModal();
    }
  });

  const closeBtn = modal.querySelector('.video-modal-close-btn');
  if (closeBtn) {
    closeBtn.addEventListener('click', closeVideoModal);
  }
}

window.openVideoModal = openVideoModal;
window.closeVideoModal = closeVideoModal;
window.initVideoModal = initVideoModal;

