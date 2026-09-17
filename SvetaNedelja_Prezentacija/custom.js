// Sveta Nedelja Custom Scripts & WebGL Cloth Card Texture Renderers

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
  ctx.strokeStyle = '#111518';
  ctx.lineWidth = 2;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  // Top Badge
  ctx.fillStyle = '#111518';
  roundRect(ctx, 22, 20, 220, 24, 4, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA A • FESTIVALSKI MASTER', 30, 36);

  // Title
  ctx.fillStyle = '#111518';
  ctx.font = '900 20px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('OSNOVNI', 22, 65);
  ctx.fillText('PAKET', 22, 86);

  // Description
  ctx.fillStyle = '#3b454e';
  ctx.font = '500 11.5px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Kinematografski film za Dan grada, 2 snimateljska dana, osnovni FPV preleti, 4x vertikale, licencirana glazba i 4K master.', 22, 105, w - 44, 15);

  // Divider Line
  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const boxH = 72;
  const boxY = h - boxH - 18;

  const features = [
    ['Master film do 4:30 min', ' (16:9, 4K Cinema Master)'],
    ['2 snimateljska dana', ' (Dvorac Erdödy, Rimac Campus, Kipišće)'],
    ['4x vertikalna videa', ' (9:16 za društvene mreže i turizam)'],
    ['Standardni FPV letovi', ' na otvorenim lokacijama'],
    ['Scenarij i naracija', ' sa studijskim snimanjem glasa'],
    ['100% prijenos autorskih prava', ' na Grad i Županiju']
  ];

  const startY = 160;
  const featSpacing = 24.5;

  features.forEach(([bold, norm], idx) => {
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#11421f';
    ctx.font = '800 12px "JetBrains Mono", monospace';
    ctx.fillText('✓', 24, featY);

    ctx.fillStyle = '#111518';
    ctx.font = '700 11.5px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#3b454e';
    ctx.font = '500 11px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  });

  // Price Bottom Row
  ctx.fillStyle = '#f4efe4';
  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#79828a';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('UKUPNA INVESTICIJA (OPCIJA A)', 28, boxY + 20);

  ctx.fillStyle = '#111518';
  ctx.font = '900 26px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('15.000,00 €', 28, boxY + 46);

  ctx.fillStyle = '#79828a';
  ctx.font = '600 9.5px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('Oslobođeno PDV-a temeljem čl. 90. st. 2. Zakona o PDV-u • 0% PDV', 28, boxY + 62);
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
  roundRect(ctx, 22, 20, 260, 24, 4, true, false);
  ctx.fillStyle = '#0d1815';
  ctx.font = '900 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA B • SIGNATURE (PREPORUČENO)', 30, 36);

  // Title
  ctx.fillStyle = '#ffffff';
  ctx.font = '900 20px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('SIGNATURE', 22, 65);
  ctx.fillText('PROŠIRENI PAKET', 22, 86);

  // Description
  ctx.fillStyle = '#9cb1a8';
  ctx.font = '500 11.5px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Puni kinematografski format: 4 snimateljska dana, FPV spektakl kroz interijere kampusa, 60s teaser trailer, autorski sound design i neograničene licence.', 22, 105, w - 44, 15);

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
    ['Master film do 6:00 min + 60s Teaser', ' (16:9, 4K)'],
    ['4 snimateljska dana', ' (zora na dvorcu i noćne vožnje na stazi)'],
    ['4x vertikalna videa montirana zasebno', ' (9:16, 4K)'],
    ['Specijalistički FPV tim', ': letovi kroz atrij kampusa i arkade'],
    ['Integracija arhive obnove dvorca', ' Erdödy (17 mil. €)'],
    ['Autorska glazbena kompozicija', ' & foley sound design'],
    ['Dronelapsi i timelapsi svitanja', ' i sumraka'],
    ['100% sirovi materijal (RAW/ProRes)', ' + trajna prava']
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
  ctx.fillText('UKUPNA INVESTICIJA (OPCIJA B)', 28, boxY + 20);

  ctx.fillStyle = '#ffffff';
  ctx.font = '900 26px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('19.500,00 €', 28, boxY + 46);

  ctx.fillStyle = '#10b981';
  ctx.font = '600 9.5px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('Oslobođeno PDV-a temeljem čl. 90. st. 2. Zakona o PDV-u • 0% PDV', 28, boxY + 62);
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
