/**
 * particles.js — CanvasUI Ambient Particle Engine & Retro Dither Lens
 */
export function initCanvasUiParticles() {
  const canvas = document.getElementById("canvasUiParticles");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  let width = (canvas.width = window.innerWidth);
  let height = (canvas.height = window.innerHeight);

  window.addEventListener("resize", () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  });

  let particleWind = 0;
  window.triggerCanvasUiWind = function(direction) {
    particleWind = direction === "forward" ? -8 : 8;
  };

  const particleCount = 55;
  const particles = [];
  for (let i = 0; i < particleCount; i++) {
    particles.push({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.35,
      vy: (Math.random() - 0.5) * 0.35,
      radius: Math.random() * 1.8 + 0.8,
      alpha: Math.random() * 0.35 + 0.15,
      color: Math.random() > 0.3 ? "20, 70, 32" : "180, 150, 100"
    });
  }

  let mouseX = width / 2;
  let mouseY = height / 2;
  let lastMouseX = mouseX;
  let lastMouseY = mouseY;
  let mouseSpeed = 0;

  window.addEventListener("mousemove", (e) => {
    mouseX = e.clientX;
    mouseY = e.clientY;
    const dx = mouseX - lastMouseX;
    const dy = mouseY - lastMouseY;
    mouseSpeed = Math.sqrt(dx * dx + dy * dy);
    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }, { passive: true });

  function animateParticles() {
    ctx.clearRect(0, 0, width, height);

    particleWind *= 0.94;
    mouseSpeed *= 0.95;

    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];

      // Mouse repulsion
      const dx = p.x - mouseX;
      const dy = p.y - mouseY;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 120 && dist > 0) {
        const force = (1 - dist / 120) * (0.8 + mouseSpeed * 0.05);
        p.vx += (dx / dist) * force * 0.6;
        p.vy += (dy / dist) * force * 0.6;
      }

      p.vx += particleWind * 0.08;
      p.x += p.vx;
      p.y += p.vy;

      // Friction & natural upward drift
      p.vx *= 0.97;
      p.vy *= 0.97;
      p.y -= 0.15;

      // Screen wrap
      if (p.x < 0) p.x = width;
      if (p.x > width) p.x = 0;
      if (p.y < 0) p.y = height;
      if (p.y > height) p.y = 0;

      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${p.color}, ${p.alpha})`;
      ctx.fill();
    }

    requestAnimationFrame(animateParticles);
  }
  requestAnimationFrame(animateParticles);
}

export function initRetroDither() {
  const bayerMatrix4x4 = [
    0, 8, 2, 10,
    12, 4, 14, 6,
    3, 11, 1, 9,
    15, 7, 13, 5
  ];

  const mediaTargets = document.querySelectorAll(".media-frame-bold, .video-thumb-crazy");
  mediaTargets.forEach((container) => {
    if (container.querySelector(".dither-canvas-layer")) return;

    const canvas = document.createElement("canvas");
    canvas.className = "dither-canvas-layer";
    canvas.style.cssText = "position:absolute; top:0; left:0; width:100%; height:100%; pointer-events:none; z-index:4; opacity:0; transition:opacity 0.25s ease;";
    container.appendChild(canvas);

    let isHovered = false;
    let mouseX = -999;
    let mouseY = -999;
    let targetImg = container.querySelector("img");

    container.addEventListener("mouseenter", () => {
      isHovered = true;
      canvas.style.opacity = "1";
      canvas.width = container.clientWidth;
      canvas.height = container.clientHeight;
    });

    container.addEventListener("mouseleave", () => {
      isHovered = false;
      canvas.style.opacity = "0";
    });

    container.addEventListener("mousemove", (e) => {
      const rect = container.getBoundingClientRect();
      mouseX = e.clientX - rect.left;
      mouseY = e.clientY - rect.top;
      renderDitherFrame();
    }, { passive: true });

    function renderDitherFrame() {
      if (!isHovered || !targetImg) return;
      const w = canvas.width;
      const h = canvas.height;
      if (w === 0 || h === 0) return;
      const ctx = canvas.getContext("2d");

      const scale = 0.25;
      const sw = Math.floor(w * scale);
      const sh = Math.floor(h * scale);
      if (sw <= 0 || sh <= 0) return;

      const offCanvas = document.createElement("canvas");
      offCanvas.width = sw;
      offCanvas.height = sh;
      const offCtx = offCanvas.getContext("2d");
      try {
        offCtx.drawImage(targetImg, 0, 0, sw, sh);
        const imgData = offCtx.getImageData(0, 0, sw, sh);
        const data = imgData.data;

        ctx.clearRect(0, 0, w, h);
        const lensRadius = 140;

        for (let y = 0; y < sh; y++) {
          for (let x = 0; x < sw; x++) {
            const idx = (y * sw + x) * 4;
            const r = data[idx];
            const g = data[idx + 1];
            const b = data[idx + 2];
            const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

            const screenX = x / scale;
            const screenY = y / scale;
            const dist = Math.sqrt((screenX - mouseX) ** 2 + (screenY - mouseY) ** 2);

            if (dist < lensRadius) {
              const feather = Math.cos((dist / lensRadius) * (Math.PI / 2));
              const bayerVal = (bayerMatrix4x4[(y % 4) * 4 + (x % 4)] + 0.5) / 16;
              const levels = 4;
              const quantized = Math.floor(lum * levels + (lum > bayerVal ? 0.5 : 0)) / levels;
              
              const finalVal = Math.floor(quantized * 255);
              ctx.fillStyle = `rgba(${finalVal}, ${Math.floor(finalVal * 0.95)}, ${Math.floor(finalVal * 0.88)}, ${feather * 0.85})`;
              ctx.fillRect(screenX, screenY, 1 / scale, 1 / scale);
            }
          }
        }
      } catch (err) {}
    }
  });
}

window.initCanvasUiParticles = initCanvasUiParticles;
window.initRetroDither = initRetroDither;
