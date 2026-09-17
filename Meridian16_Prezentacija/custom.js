// Meridian 16 Custom Scripts & WebGL Cloth Card Texture Renderers

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

  ctx.fillStyle = '#111518';
  roundRect(ctx, 22, 20, 185, 24, 4, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 10.5px "JetBrains Mono", monospace';
  ctx.fillText('OPTION A • QUOTE NO. 9', 30, 36);

  ctx.fillStyle = '#111518';
  ctx.font = '900 20px "Syne", sans-serif';
  ctx.fillText('EXPANDED', 22, 65);
  ctx.fillText('PRODUCTION', 22, 86);

  ctx.fillStyle = '#3b454e';
  ctx.font = '500 12px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Cinema equipment, multiple setups, director interview, up to 10 FPV flights, hero film & 4 verticals.', 22, 105, w - 44, 16);

  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const features = [
    ['Hero Film up to 2:30', ' (16:9, 4K Cinema Master)'],
    ['Interview with Director (17 Sep)', ' (2 Cams, Gimbal, Lighting)'],
    ['4x Vertical Video Reels', ' (LinkedIn & Social Media)'],
    ['Up to 10 FPV Flights', ' + Peak-Traffic Timelapses & Dronelapses'],
    ['Pre-production', ' (Concept, Script, Moodboard, Site Scout)'],
    ['100% Source Footage & Full Rights Transfer', ' to Client']
  ];

  const startY = 160;
  const featSpacing = 24.5;

  features.forEach(([bold, norm], idx) => {
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#11421f';
    ctx.font = '800 13px "JetBrains Mono", monospace';
    ctx.fillText('✓', 24, featY);

    ctx.fillStyle = '#111518';
    ctx.font = '700 12px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#3b454e';
    ctx.font = '500 12px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  });

  const boxH = 72;
  const boxY = h - boxH - 18;

  ctx.fillStyle = '#f4efe4';
  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#79828a';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('TOTAL INVESTMENT (QUOTE NO. 9)', 28, boxY + 20);

  ctx.fillStyle = '#111518';
  ctx.font = '900 26px "Syne", sans-serif';
  ctx.fillText('€ 13,000', 28, boxY + 46);

  ctx.fillStyle = '#79828a';
  ctx.font = '600 9.5px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('VAT exempt (Article 90(2) Croatian VAT Act) • 0% PDV', 28, boxY + 62);
}

function renderCardTextureB(canvas, w, h, dpr) {
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);

  ctx.fillStyle = '#fdfbf7';
  ctx.strokeStyle = '#11421f';
  ctx.lineWidth = 2.5;
  roundRect(ctx, 1, 1, w - 2, h - 2, 12, true, true);

  ctx.fillStyle = '#11421f';
  roundRect(ctx, 22, 20, 260, 24, 4, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 10px "JetBrains Mono", monospace';
  ctx.fillText('OPTION B • QUOTE NO. 15 (RECOMMENDED)', 30, 36);

  ctx.fillStyle = '#111518';
  ctx.font = '900 20px "Syne", sans-serif';
  ctx.fillText('FULL VISION', 22, 65);
  ctx.fillText('CAMPAIGN', 22, 86);

  ctx.fillStyle = '#3b454e';
  ctx.font = '500 12px "Plus Jakarta Sans", sans-serif';
  wrapText(ctx, 'Full cinematic rollout: dedicated storyboard, indoor FPV route test, teleprompter, sound designer score & teaser.', 22, 105, w - 44, 16);

  ctx.strokeStyle = '#d5ccba';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(22, 140);
  ctx.lineTo(w - 22, 140);
  ctx.stroke();

  const features = [
    ['Hero Film up to 2:30 + 60s Teaser Trailer', ' (16:9, 4K)'],
    ['Director Interview + Teleprompter', ' (2 Cams, Gimbal, Lighting)'],
    ['4x Vertical Video Reels', ' (LinkedIn, Web & Social)'],
    ['Full FPV Package with Spotter & Route Test', ' + Corridors'],
    ['Deep Pre-production', ' (Storyboard, Concept, Scout & FPV Test)'],
    ['Custom Sound Designer Score & SFX', ' + Master Color Grade'],
    ['100% Source Footage & Full Rights Transfer', ' to Client']
  ];

  const startY = 160;
  const featSpacing = 22;

  features.forEach(([bold, norm], idx) => {
    const featY = startY + idx * featSpacing;
    ctx.fillStyle = '#177331';
    ctx.font = '800 13px "JetBrains Mono", monospace';
    ctx.fillText('★', 24, featY);

    ctx.fillStyle = '#111518';
    ctx.font = '700 11.5px "Plus Jakarta Sans", sans-serif';
    const boldW = ctx.measureText(bold).width;
    ctx.fillText(bold, 44, featY);

    ctx.fillStyle = '#3b454e';
    ctx.font = '500 11.5px "Plus Jakarta Sans", sans-serif';
    ctx.fillText(norm, 44 + boldW, featY);
  });

  const boxH = 72;
  const boxY = h - boxH - 18;

  ctx.fillStyle = '#e1ede4';
  ctx.strokeStyle = '#a6cbb4';
  ctx.lineWidth = 1.5;
  roundRect(ctx, 16, boxY, w - 32, boxH, 8, true, true);

  ctx.fillStyle = '#11421f';
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.fillText('TOTAL INVESTMENT (QUOTE NO. 15)', 28, boxY + 20);

  ctx.fillStyle = '#11421f';
  ctx.font = '900 26px "Syne", sans-serif';
  ctx.fillText('€ 17,000', 28, boxY + 46);

  ctx.fillStyle = '#177331';
  ctx.font = '600 9.5px "Plus Jakarta Sans", sans-serif';
  ctx.fillText('VAT exempt (Article 90(2) Croatian VAT Act) • 0% PDV', 28, boxY + 62);
}

// Initialize Cloth Cards with Meridian 16 custom renderers
if (window.initClothCardPhysics) {
  initClothCardPhysics({
    0: renderCardTextureA,
    1: renderCardTextureB
  });
}
