// Zagrebačka županija Custom Scripts & WebGL Cloth Card Texture Renderers

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

  ctx.fillStyle = '#fbf7ee';
  ctx.strokeStyle = '#111518';
  ctx.lineWidth = 2;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  // Top Badge
  ctx.fillStyle = '#111518';
  roundRect(ctx, 22, 20, 220, 24, 4, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA A • STANDARDNI PAKET', 30, 36);

  // Title
  ctx.fillStyle = '#111518';
  ctx.font = '900 20px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('STANDARDNA', 22, 65);
  ctx.fillText('KRONIKA', 22, 86);

  // Description
  ctx.fillStyle = '#3b454e';
  ctx.font = '500 11px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Filmsko snimanje ključnih lokacija, 4K Master film do 5 minuta, standardni dron i 2 vertikale za društvene mreže.', 22, 105, w - 44, 15);

  // Divider Line
  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 138);
  ctx.lineTo(w - 22, 138);
  ctx.stroke();

  const boxH = 72;
  const boxY = h - boxH - 18;

  const features = [
    ['Master film do 5:00 min', ' (16:9, 4K Cinema Master)'],
    ['2 snimajuća dana', ' (Kosnica, Rugvica, Samobor, V. Gorica)'],
    ['2x Vertikalna videa', ' (LinkedIn i Instagram formati)'],
    ['Standardno zračno snimanje', ' + kino optika na tlu'],
    ['Digitalna animacija arhive', ' (Povelja i grb iz 1759.)'],
    ['Studijski voiceover', ' + licencirani audio miks'],
    ['100% prijenos autorskih prava', ' za sve medije i TV']
  ];

  const startY = 156;
  const availH = boxY - 12 - startY;
  const featSpacing = availH / (features.length - 1);

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
  ctx.fillStyle = '#eae3d2';
  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#79828a';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('UKUPNO ULAGANJE (OPCIJA A)', 28, boxY + 20);

  ctx.fillStyle = '#111518';
  ctx.font = '900 24px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('18.000,00 €', 28, boxY + 45);

  ctx.fillStyle = '#79828a';
  ctx.font = '600 9px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('Oslobođeno PDV-a (Čl. 90. st. 2 Zakona o PDV-u) • 0% PDV', 28, boxY + 61);
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
  roundRect(ctx, 22, 20, 265, 24, 4, true, false);
  ctx.fillStyle = '#0d1815';
  ctx.font = '900 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPCIJA B • FULL VISION (PREPORUKA)', 30, 36);

  // Title
  ctx.fillStyle = '#ffffff';
  ctx.font = '900 20px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('PUNI KINEMATOGRAFSKI', 22, 65);
  ctx.fillText('PRSTEN ★', 22, 86);

  // Description
  ctx.fillStyle = '#9cb1a8';
  ctx.font = '500 11px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Sveobuhvatna kronika: FPV i zračni preleti svih 9 gradova, fizička 16:9 arhivska ploča s pamučnom pređom i 4 vertikale.', 22, 105, w - 44, 15);

  // Divider Line
  ctx.strokeStyle = '#1d362a';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 138);
  ctx.lineTo(w - 22, 138);
  ctx.stroke();

  const boxH = 72;
  const boxY = h - boxH - 18;

  const features = [
    ['Master film 6–7 min + 60s teaser', ' (4K UHD)'],
    ['4 snimajuća dana', ' s velikim formatom optike i rasvjetom'],
    ['FPV i zračni preleti svih 9 gradova', ' i strateških zona'],
    ['Fizička 16:9 arhivska ploča', ' s crvenom pređom & makro'],
    ['4x Namjenske vertikale (9:16)', ' za društvene mreže i TV'],
    ['Studijski glas & autorska glazba', ' skladana za film'],
    ['100% prijenos svih prava', ' + arhivski masteri u punoj rezoluciji']
  ];

  const startY = 156;
  const availH = boxY - 12 - startY;
  const featSpacing = availH / (features.length - 1);

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
  ctx.fillText('22.000,00 €', 28, boxY + 45);

  ctx.fillStyle = '#10b981';
  ctx.font = '600 9px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('Oslobođeno PDV-a (Čl. 90. st. 2 Zakona o PDV-u) • 0% PDV', 28, boxY + 61);
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
