// Bjelovar Custom Scripts & WebGL Cloth Card Texture Renderers

function roundRect(ctx, x, y, width, height, radius, fill, stroke) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + width - radius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
  ctx.lineTo(x + width, y + height - radius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  ctx.lineTo(x + radius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
  if (fill) ctx.fill();
  if (stroke) ctx.stroke();
}

function wrapText(ctx, text, x, y, maxWidth, lineHeight) {
  const words = text.split(' ');
  let line = '';
  for (let n = 0; n < words.length; n++) {
    const testLine = line + words[n] + ' ';
    const metrics = ctx.measureText(testLine);
    if (metrics.width > maxWidth && n > 0) {
      ctx.fillText(line, x, y);
      line = words[n] + ' ';
      y += lineHeight;
    } else {
      line = testLine;
    }
  }
  ctx.fillText(line, x, y);
}

function renderCardTextureA(canvas, w, h, dpr) {
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  ctx.fillStyle = '#ffffff';
  ctx.strokeStyle = '#0d1815';
  ctx.lineWidth = 2;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  // Top Badge
  ctx.fillStyle = '#0d1815';
  roundRect(ctx, 22, 20, 180, 24, 4, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA A • STANDARD', 30, 36);

  // Title
  ctx.fillStyle = '#0d1815';
  ctx.font = '900 20px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('STANDARDNA', 22, 65);
  ctx.fillText('PRODUKCIJA', 22, 86);

  // Description
  ctx.fillStyle = '#2d3f3a';
  ctx.font = '500 11.5px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Cinema oprema, 3 snimajuća dana, snimanje bušotine i gradilišta, 4K master film & 3 vertikale.', 22, 105, w - 44, 15);

  // Divider Line
  ctx.strokeStyle = '#c4d7cf';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const boxH = 72;
  const boxY = h - boxH - 18;

  const features = [
    ['4K Master film do 6 min', ' (16:9 Cinema Master)'],
    ['Snimanje bušotine i Termi', ' (Veliko Korenovo)'],
    ['3x Vertikalna video formata', ' (9:16 za mreže)'],
    ['3 snimajuća dana', ' s cinema kamerama i dronom'],
    ['Scenarij i knjiga snimanja', ' usklađeni s protokolom'],
    ['100% prijenos autorskih prava', ' za Grad i Županiju']
  ];

  const startY = 160;
  const featSpacing = 24.5;

  features.forEach(([bold, norm], idx) => {
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#0d5c3a';
    ctx.font = '800 12px "JetBrains Mono", monospace';
    ctx.fillText('✓', 24, featY);

    ctx.fillStyle = '#0d1815';
    ctx.font = '700 11.5px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#2d3f3a';
    ctx.font = '500 11px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  });

  // Price Bottom Row
  ctx.fillStyle = '#e6f1ec';
  ctx.strokeStyle = '#c4d7cf';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#647a74';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('UKUPNO ULAGANJE (OPCIJA A)', 28, boxY + 20);

  ctx.fillStyle = '#0d1815';
  ctx.font = '900 24px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('14.000,00 €', 28, boxY + 46);

  ctx.fillStyle = '#647a74';
  ctx.font = '600 9px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('PDV nije obračunat (čl. 90 st. 2 Zakona o PDV-u) • 0% PDV', 28, boxY + 62);
}

function renderCardTextureB(canvas, w, h, dpr) {
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  // Card Background
  ctx.fillStyle = '#0d1815';
  ctx.strokeStyle = '#10b981';
  ctx.lineWidth = 2.5;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  // Emerald Radial Glow
  const grad = ctx.createRadialGradient(w - 60, 40, 10, w - 60, 40, 260);
  grad.addColorStop(0, 'rgba(16, 185, 129, 0.16)');
  grad.addColorStop(1, 'rgba(13, 24, 21, 0)');
  ctx.fillStyle = grad;
  roundRect(ctx, 2, 2, w - 4, h - 4, 11, true, false);

  // Top Badge
  ctx.fillStyle = '#10b981';
  roundRect(ctx, 22, 20, 275, 24, 4, true, false);
  ctx.fillStyle = '#0d1815';
  ctx.font = '900 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA B • SIGNATURE (PREPORUČENO)', 30, 36);

  // Title
  ctx.fillStyle = '#ffffff';
  ctx.font = '900 20px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('SIGNATURE GEOTERMALNI', 22, 65);
  ctx.fillText('PAKET', 22, 86);

  // Description
  ctx.fillStyle = '#9cb1a8';
  ctx.font = '500 11.5px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Potpuni kinematografski doseg: 3D presjek slojeva zemlje (1500 m), FPV dron i 60s teaser najava.', 22, 105, w - 44, 15);

  // Divider Line
  ctx.strokeStyle = '#1d362a';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const boxH = 72;
  const boxY = h - boxH - 18;

  const features = [
    ['4K Master film (6 min) + 60s najava', ' (Teaser)'],
    ['3D geološki presjek slojeva', ' (1500 m Korenovo)'],
    ['Licencirani brzi FPV dron', ' (preleti kroz bazene)'],
    ['3x Modularne vertikale', ' s kinetičkom infografikom'],
    ['4 snimajuća dana', ' (snimanje u zoru i u sumrak)'],
    ['Autorski zvučni dizajn', ' i simfonijski aranžman']
  ];

  const startY = 160;
  const featSpacing = 24.5;

  features.forEach(([bold, norm], idx) => {
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#10b981';
    ctx.font = '800 12px "JetBrains Mono", monospace';
    ctx.fillText('★', 24, featY);

    ctx.fillStyle = '#ffffff';
    ctx.font = '700 11.5px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#9cb1a8';
    ctx.font = '500 11px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  });

  // Price Bottom Row
  ctx.fillStyle = '#13231e';
  ctx.strokeStyle = '#10b981';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#10b981';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('UKUPNO ULAGANJE (OPCIJA B)', 28, boxY + 20);

  ctx.fillStyle = '#ffffff';
  ctx.font = '900 24px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('18.000,00 €', 28, boxY + 46);

  ctx.fillStyle = '#10b981';
  ctx.font = '600 9px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('PDV nije obračunat (čl. 90 st. 2 Zakona o PDV-u) • 0% PDV', 28, boxY + 62);
}

// Attach custom renderers for cloth engine
window.customClothRenderers = {
  0: renderCardTextureA,
  1: renderCardTextureB
};
window.renderCardTextureA = renderCardTextureA;
window.renderCardTextureB = renderCardTextureB;

if (window.initClothCardPhysics) {
  window.initClothCardPhysics(window.customClothRenderers);
}
