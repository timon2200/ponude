/**
 * modal.js — YouTube & Video Modal Controller
 */
export function openVideoModal(videoId, title) {
  const modal = document.getElementById('videoModal');
  const iframe = document.getElementById('videoIframe');
  const titleEl = document.getElementById('videoModalTitle');
  const ytLink = document.getElementById('btnWatchOnYt');

  if (!modal || !iframe) return;

  if (titleEl) titleEl.textContent = title || 'Video Preview';
  if (ytLink) ytLink.href = `https://youtu.be/${videoId}`;
  
  iframe.src = `https://www.youtube.com/embed/${videoId}?autoplay=1&rel=0&modestbranding=1&enablejsapi=1`;
  modal.classList.add('active');
}

export function closeVideoModal() {
  const modal = document.getElementById('videoModal');
  const iframe = document.getElementById('videoIframe');
  if (!modal || !iframe) return;
  iframe.src = "";
  modal.classList.remove('active');
}

export function initVideoModal() {
  const modal = document.getElementById('videoModal');
  if (!modal) return;
  
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
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
