/**
 * cloth.js — CanvasUI 3D WebGL Cloth Physics Engine (Zero-Dependency)
 * 96x96 Mesh, Spring-Damper Wave Physics, Wind Gusts & Interactive Brushing
 */

export function initClothCardPhysics(customRenderers = null) {
  const CLOTH_VERT = `#version 300 es
  precision highp float;
  layout(location = 0) in vec2 aGrid;
  layout(location = 1) in vec4 aData;
  layout(location = 2) in vec2 aOffset;
  uniform vec2 uRes;
  uniform vec2 uOut;
  uniform float uBleed;
  uniform float uFocal;
  out vec2 vUv;
  out vec3 vNormal;
  out float vFold;
  out vec2 vLocal;

  void main () {
    vUv = aGrid;
    float z = aData.x;
    vec2 nxy = aData.yz;
    vNormal = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.04)));
    vFold = aData.w;

    vLocal = aGrid * uRes;
    vec2 px = vLocal + aOffset + vec2(uBleed);
    vec2 ndc = (px / uOut) * 2.0 - 1.0;
    ndc.y = -ndc.y;
    float w = (uFocal - z) / uFocal;
    gl_Position = vec4(ndc, -z / uFocal, w);
  }`;

  const SDF_SNIPPET = `
  float fabricDist (vec2 p, vec2 size, float radius) {
    vec2 half_ = size * 0.5;
    float r = min(radius, min(half_.x, half_.y));
    vec2 q = abs(p - half_) - (half_ - vec2(r));
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
  }`;

  const CLOTH_FRAG = `#version 300 es
  precision highp float;
  in vec2 vUv;
  in vec3 vNormal;
  in float vFold;
  in vec2 vLocal;
  out vec4 outColor;
  uniform sampler2D uContent;
  uniform float uMaxX;
  uniform float uLight;
  uniform float uSheen;
  uniform vec3 uBacking;
  uniform vec2 uRes;
  uniform float uRadius;
  uniform float uDark;
  ${SDF_SNIPPET}

  void main () {
    vec2 uv = clamp(vUv, vec2(0.001), vec2(uMaxX - 0.001, 0.999));
    vec4 tex = texture(uContent, uv);
    vec3 fabric = mix(uBacking, tex.rgb, tex.a);

    vec3 n = normalize(vNormal);
    vec3 lightDir = normalize(vec3(-0.3, 0.42, 0.86));
    float diffFlat = 0.58 + 0.42 * lightDir.z;
    float diff = 0.58 + 0.42 * dot(n, lightDir);
    float shade = mix(1.0, (diff / diffFlat) * vFold, uLight);
    vec3 lit = fabric * shade;

    vec3 halfway = normalize(lightDir + vec3(0.0, 0.0, 1.0));
    float specFlat = pow(halfway.z, 34.0);
    float spec = max(pow(max(dot(n, halfway), 0.0), 34.0) - specFlat, 0.0) / (1.0 - specFlat);
    lit += uSheen * spec * mix(vec3(1.0), fabric, 0.35);

    float broadFlat = pow(halfway.z, 6.0);
    float broad = max(pow(max(dot(n, halfway), 0.0), 6.0) - broadFlat, 0.0) / (1.0 - broadFlat);
    lit += uDark * uLight * 0.3 * broad * vec3(1.0);

    float d = fabricDist(vLocal, uRes, uRadius);
    float hemT = smoothstep(0.0, 6.0, -d);
    lit *= mix(1.0, mix(0.93, 1.0, hemT), uLight * (1.0 - uDark));
    lit += vec3(uDark * uLight * 0.08 * (1.0 - hemT));

    float alpha = clamp(0.5 - d, 0.0, 1.0);
    outColor = vec4(clamp(lit, 0.0, 1.0), 1.0) * alpha;
  }`;

  const SHADOW_VERT = `#version 300 es
  precision highp float;
  layout(location = 0) in vec2 aGrid;
  layout(location = 1) in vec4 aData;
  layout(location = 2) in vec2 aOffset;
  uniform vec2 uRes;
  uniform vec2 uOut;
  uniform float uBleed;
  out vec2 vLocal;
  out float vLift;

  void main () {
    float z = aData.x;
    vLift = z;
    vLocal = aGrid * uRes;
    vec2 px = vLocal + aOffset + vec2(uBleed) + vec2(10.0, 14.0) + vec2(0.3, 0.42) * z;
    vec2 ndc = (px / uOut) * 2.0 - 1.0;
    ndc.y = -ndc.y;
    gl_Position = vec4(ndc, 0.0, 1.0);
  }`;

  const SHADOW_FRAG = `#version 300 es
  precision highp float;
  in vec2 vLocal;
  in float vLift;
  out vec4 outColor;
  uniform float uShadow;
  uniform vec2 uRes;
  uniform float uRadius;
  uniform float uDark;
  ${SDF_SNIPPET}

  void main () {
    float d = fabricDist(vLocal, uRes, uRadius);
    float a = uShadow * smoothstep(0.0, 30.0, -d);
    a *= mix(1.0, 0.55, clamp(vLift / 50.0, 0.0, 1.0));
    a *= mix(1.0, 0.55, uDark);
    vec3 tint = vec3(uDark);
    outColor = vec4(tint * a, a);
  }`;

  const SEG = 96;
  const NODES = SEG + 1;
  const DT = 1 / 120;
  const WAVE_SPEED = 26;
  const STIFFNESS = 0.60;
  const FORCE_GAIN = 3.25;
  const BLEED = 48;

  function createClothInstance(wrapEl, cardEl, outputCanvas, drawTextureFn, backingRgb, config = {}) {
    const opts = {
      pin: 'top',
      wind: 2.1,
      speed: 0.45,
      amplitude: 19,
      drape: 22,
      brush: 1.4,
      brushSize: 145,
      damping: 0.92,
      light: 0.42,
      sheen: 0.12,
      shadow: 0.22,
      cornerRadius: 12,
      perspective: 1350,
      ...config
    };

    const gl = outputCanvas.getContext('webgl2', {
      alpha: true,
      depth: false,
      stencil: false,
      antialias: true,
      premultipliedAlpha: true
    });
    if (!gl) return null;

    function compile(type, text) {
      const s = gl.createShader(type);
      gl.shaderSource(s, text);
      gl.compileShader(s);
      return s;
    }
    function link(vertText, fragText) {
      const vert = compile(gl.VERTEX_SHADER, vertText);
      const frag = compile(gl.FRAGMENT_SHADER, fragText);
      const prog = gl.createProgram();
      gl.attachShader(prog, vert);
      gl.attachShader(prog, frag);
      gl.linkProgram(prog);
      const uniforms = {};
      const count = gl.getProgramParameter(prog, gl.ACTIVE_UNIFORMS);
      for (let i = 0; i < count; i++) {
        const info = gl.getActiveUniform(prog, i);
        uniforms[info.name] = gl.getUniformLocation(prog, info.name);
      }
      return { program: prog, uniforms };
    }

    const cloth = link(CLOTH_VERT, CLOTH_FRAG);
    const shadow = link(SHADOW_VERT, SHADOW_FRAG);

    const gridVerts = new Float32Array(NODES * NODES * 2);
    for (let y = 0; y < NODES; y++) {
      for (let x = 0; x < NODES; x++) {
        const i = (y * NODES + x) * 2;
        gridVerts[i] = x / SEG;
        gridVerts[i + 1] = y / SEG;
      }
    }
    const gridIndices = new Uint32Array(SEG * SEG * 6);
    let off = 0;
    for (let y = 0; y < SEG; y++) {
      for (let x = 0; x < SEG; x++) {
        const a = y * NODES + x;
        const b = a + 1;
        const c = a + NODES;
        const d = c + 1;
        gridIndices[off++] = a; gridIndices[off++] = c; gridIndices[off++] = b;
        gridIndices[off++] = b; gridIndices[off++] = c; gridIndices[off++] = d;
      }
    }

    const clothVao = gl.createVertexArray();
    gl.bindVertexArray(clothVao);
    const gridBuf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, gridBuf);
    gl.bufferData(gl.ARRAY_BUFFER, gridVerts, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

    const dataBuf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, dataBuf);
    gl.bufferData(gl.ARRAY_BUFFER, NODES * NODES * 4 * 4, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 4, gl.FLOAT, false, 0, 0);

    const offsetBuf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, offsetBuf);
    gl.bufferData(gl.ARRAY_BUFFER, NODES * NODES * 2 * 4, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, gl.FLOAT, false, 0, 0);

    const indexBuf = gl.createBuffer();
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuf);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, gridIndices, gl.STATIC_DRAW);
    gl.bindVertexArray(null);

    const texCanvas = document.createElement('canvas');
    const contentTex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, contentTex);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([255, 255, 255, 255]));

    let hasValidTexture = false;

    function updateTexture() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = wrapEl.clientWidth;
      const h = wrapEl.clientHeight;
      if (w < 30 || h < 30) return false;
      if (typeof drawTextureFn === 'function') {
        drawTextureFn(texCanvas, w, h, dpr);
      }
      gl.bindTexture(gl.TEXTURE_2D, contentTex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, texCanvas);
      hasValidTexture = true;
      return true;
    }

    let hCur = new Float32Array(NODES * NODES);
    let hPrev = new Float32Array(NODES * NODES);
    let hNext = new Float32Array(NODES * NODES);
    const vertexData = new Float32Array(NODES * NODES * 4);
    const offsetData = new Float32Array(NODES * NODES * 2);
    const zField = new Float32Array(NODES * NODES);
    const rowForce = new Float32Array(NODES);
    const colForce = new Float32Array(NODES);
    const hangCurve = new Float32Array(NODES);
    for (let a = 0; a < NODES; a++) {
      hangCurve[a] = Math.pow(a / SEG, 1.3);
    }

    let simTime = Math.random() * 60;
    let gust = 0.6;
    const pointer = { x: -1e5, y: -1e5, inside: false };
    const touch = { x: -1e5, y: -1e5, vx: 0, vy: 0, s: 0 };

    function syncSize() {
      if (window.innerWidth <= 768) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const cw = outputCanvas.clientWidth;
      const ch = outputCanvas.clientHeight;
      if (cw < 30 || ch < 30) return;
      const targetW = Math.round(cw * dpr);
      const targetH = Math.round(ch * dpr);
      if (outputCanvas.width !== targetW || outputCanvas.height !== targetH || !hasValidTexture) {
        outputCanvas.width = targetW;
        outputCanvas.height = targetH;
        if (updateTexture()) {
          cardEl.classList.add('cloth-active');
        }
      }
    }

    function stepSim(dt) {
      simTime += dt * opts.speed;
      const t = simTime;
      const windAmp = FORCE_GAIN * opts.wind * gust;
      const kb1 = (Math.PI * 2) / (SEG / 1.5);
      const kb2 = (Math.PI * 2) / (SEG / 3.8);
      const ka = (Math.PI * 2) / (SEG / 2.2);
      const w1 = WAVE_SPEED * kb1;
      const w2 = WAVE_SPEED * kb2;
      const drift = 1.8 * Math.sin(0.23 * t);
      for (let b = 0; b < NODES; b++) {
        rowForce[b] = Math.sin(kb1 * b - w1 * t + drift) + 0.45 * Math.sin(kb2 * b + w2 * t * 0.8 + 3.0);
      }
      for (let a = 0; a < NODES; a++) {
        colForce[a] = (0.7 + 0.3 * Math.sin(ka * a - 1.7 * t)) * hangCurve[a];
      }

      const c2 = WAVE_SPEED * WAVE_SPEED;
      const dt2 = dt * dt;
      const decay = Math.exp(-opts.damping * dt);
      for (let y = 0; y < NODES; y++) {
        const up = Math.max(y - 1, 0) * NODES;
        const down = Math.min(y + 1, SEG) * NODES;
        const row = y * NODES;
        for (let x = 0; x < NODES; x++) {
          const i = row + x;
          const l = row + Math.max(x - 1, 0);
          const r = row + Math.min(x + 1, SEG);
          const h = hCur[i];
          const lap = hCur[l] + hCur[r] + hCur[up + x] + hCur[down + x] - 4 * h;
          const force = windAmp * rowForce[x] * colForce[y];
          const acc = c2 * lap - STIFFNESS * h + force;
          const next = 2 * h - hPrev[i] + dt2 * acc;
          let val = h + (next - h) * decay;
          if (val > 3.5) val = 3.5; else if (val < -3.5) val = -3.5;
          hNext[i] = val;
        }
      }
      for (let b = 0; b < NODES; b++) {
        hNext[b] = 0;
      }
      const spent = hPrev; hPrev = hCur; hCur = hNext; hNext = spent;
    }

    function touchImprint(delta, width, height) {
      if (touch.s < 0.01) return;
      const cellW = Math.max(width, 50) / SEG;
      const cellH = Math.max(height, 50) / SEG;
      const rx = opts.brushSize / cellW;
      const ry = opts.brushSize / cellH;
      const gx = touch.x / cellW;
      const gy = touch.y / cellH;
      const bx0 = Math.max(Math.ceil(gx - 2.5 * rx), 0);
      const bx1 = Math.min(Math.floor(gx + 2.5 * rx), SEG);
      const by0 = Math.max(Math.ceil(gy - 2.5 * ry), 0);
      const by1 = Math.min(Math.floor(gy + 2.5 * ry), SEG);
      const lift = 1.1 * opts.brush * touch.s;
      const rate = Math.min(delta * 4, 1);
      for (let y = by0; y <= by1; y++) {
        const oy = (y - gy) / ry;
        const row = y * NODES;
        for (let x = bx0; x <= bx1; x++) {
          const ox = (x - gx) / rx;
          const g = Math.exp(-(ox * ox + oy * oy));
          if (g < 0.02) continue;
          const i = row + x;
          hCur[i] += (lift * g - hCur[i]) * (rate * g);
          hPrev[i] += (lift * g - hPrev[i]) * (rate * g);
        }
      }
    }

    function foreshorten(axisStride, lineStride, ds, anchor, comp) {
      const ds2 = ds * ds;
      for (let l = 0; l < NODES; l++) {
        const base = l * lineStride;
        offsetData[(base + anchor * axisStride) * 2 + comp] = 0;
        let cum = 0;
        for (let k = anchor + 1; k < NODES; k++) {
          const i = base + k * axisStride;
          const dz = zField[i] - zField[i - axisStride];
          cum += ds - Math.sqrt(Math.max(ds2 - dz * dz, 0));
          offsetData[i * 2 + comp] = -cum;
        }
        cum = 0;
        for (let k = anchor - 1; k >= 0; k--) {
          const i = base + k * axisStride;
          const dz = zField[i] - zField[i + axisStride];
          cum += ds - Math.sqrt(Math.max(ds2 - dz * dz, 0));
          offsetData[i * 2 + comp] = cum;
        }
      }
    }

    function composeOffsets(w, h) {
      const cellW = Math.max(w, 50) / SEG;
      const cellH = Math.max(h, 50) / SEG;
      const mid = SEG >> 1;
      foreshorten(NODES, 1, cellH, 0, 1);
      foreshorten(1, NODES, cellW, mid, 0);
    }

    function composeVertices(w, h) {
      const drape = opts.drape * (0.3 + 0.7 * gust);
      const cellW = Math.max(w, 50) / SEG;
      const cellH = Math.max(h, 50) / SEG;
      for (let y = 0; y < NODES; y++) {
        const row = y * NODES;
        for (let x = 0; x < NODES; x++) {
          const i = row + x;
          zField[i] = opts.amplitude * Math.tanh(hCur[i]) + drape * hangCurve[y];
        }
      }
      for (let y = 0; y < NODES; y++) {
        const up = Math.max(y - 1, 0) * NODES;
        const down = Math.min(y + 1, SEG) * NODES;
        const row = y * NODES;
        for (let x = 0; x < NODES; x++) {
          const i = row + x;
          const l = row + Math.max(x - 1, 0);
          const r = row + Math.min(x + 1, SEG);
          const dzdx = (zField[r] - zField[l]) / (2 * cellW);
          const dzdy = (zField[down + x] - zField[up + x]) / (2 * cellH);
          const inv = 1 / Math.hypot(dzdx, dzdy, 1);
          const curve = zField[l] + zField[r] + zField[up + x] + zField[down + x] - 4 * zField[i];
          let fold = 1 - curve * 0.01;
          if (fold < 0.86) fold = 0.86; else if (fold > 1.06) fold = 1.06;
          const o = i * 4;
          vertexData[o] = zField[i];
          vertexData[o + 1] = -dzdx * inv;
          vertexData[o + 2] = -dzdy * inv;
          vertexData[o + 3] = fold;
        }
      }
      composeOffsets(w, h);
    }

    function render() {
      const resW = Math.max(wrapEl.clientWidth, 50);
      const resH = Math.max(wrapEl.clientHeight, 50);
      const outW = Math.max(outputCanvas.clientWidth, 50);
      const outH = Math.max(outputCanvas.clientHeight, 50);
      const dark = opts.dark || 0;

      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.viewport(0, 0, outputCanvas.width, outputCanvas.height);
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

      gl.bindVertexArray(clothVao);
      gl.bindBuffer(gl.ARRAY_BUFFER, dataBuf);
      gl.bufferSubData(gl.ARRAY_BUFFER, 0, vertexData);
      gl.bindBuffer(gl.ARRAY_BUFFER, offsetBuf);
      gl.bufferSubData(gl.ARRAY_BUFFER, 0, offsetData);

      // Shadow pass
      gl.useProgram(shadow.program);
      gl.uniform2f(shadow.uniforms.uRes, resW, resH);
      gl.uniform2f(shadow.uniforms.uOut, outW, outH);
      gl.uniform1f(shadow.uniforms.uBleed, BLEED);
      gl.uniform1f(shadow.uniforms.uShadow, opts.shadow);
      gl.uniform1f(shadow.uniforms.uRadius, opts.cornerRadius);
      gl.uniform1f(shadow.uniforms.uDark, dark);
      gl.drawElements(gl.TRIANGLES, gridIndices.length, gl.UNSIGNED_INT, 0);

      // Cloth pass
      gl.useProgram(cloth.program);
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, contentTex);
      gl.uniform1i(cloth.uniforms.uContent, 0);
      gl.uniform2f(cloth.uniforms.uRes, resW, resH);
      gl.uniform2f(cloth.uniforms.uOut, outW, outH);
      gl.uniform1f(cloth.uniforms.uBleed, BLEED);
      gl.uniform1f(cloth.uniforms.uFocal, opts.perspective);
      gl.uniform1f(cloth.uniforms.uMaxX, 1.0);
      gl.uniform1f(cloth.uniforms.uLight, opts.light);
      gl.uniform1f(cloth.uniforms.uSheen, opts.sheen);
      gl.uniform1f(cloth.uniforms.uRadius, opts.cornerRadius);
      gl.uniform1f(cloth.uniforms.uDark, dark);
      gl.uniform3f(cloth.uniforms.uBacking, backingRgb[0], backingRgb[1], backingRgb[2]);
      gl.drawElements(gl.TRIANGLES, gridIndices.length, gl.UNSIGNED_INT, 0);
      gl.bindVertexArray(null);
    }

    let lastTime = performance.now();
    let simDebt = 0;
    function loop(now) {
      if (window.innerWidth <= 768) {
        requestAnimationFrame(loop);
        return;
      }

      const delta = Math.min((now - lastTime) / 1000, 1 / 20);
      lastTime = now;
      const w = wrapEl.clientWidth;
      const h = wrapEl.clientHeight;

      if (w < 30 || h < 30) {
        requestAnimationFrame(loop);
        return;
      }

      if (!hasValidTexture || outputCanvas.width === 0) {
        syncSize();
      }

      const target = Math.max(0.55 + 0.35 * Math.sin(simTime * 0.31 + 1.3) + 0.25 * Math.sin(simTime * 0.83), 0.15);
      gust += (target - gust) * Math.min(delta * 2, 1);

      const sTarget = pointer.inside ? 1 : 0;
      touch.s += (sTarget - touch.s) * Math.min(delta * 8, 1);
      const omega = 14;
      touch.vx += ((pointer.x - touch.x) * omega * omega - 2 * omega * touch.vx) * delta;
      touch.vy += ((pointer.y - touch.y) * omega * omega - 2 * omega * touch.vy) * delta;
      touch.x += touch.vx * delta;
      touch.y += touch.vy * delta;
      touchImprint(delta, w, h);

      simDebt = Math.min(simDebt + delta, DT * 5);
      while (simDebt >= DT) {
        stepSim(DT);
        simDebt -= DT;
      }

      composeVertices(w, h);
      render();
      requestAnimationFrame(loop);
    }

    wrapEl.addEventListener('pointermove', (e) => {
      const rect = wrapEl.getBoundingClientRect();
      pointer.x = e.clientX - rect.left;
      pointer.y = e.clientY - rect.top;
      pointer.inside = true;
    });
    wrapEl.addEventListener('pointerleave', () => {
      pointer.inside = false;
    });

    requestAnimationFrame(loop);

    return {
      triggerGust: () => {
        gust = 0.95;
        touch.s = 0.55;
        touch.x = wrapEl.clientWidth * 0.5;
        touch.y = wrapEl.clientHeight * 0.3;
        touch.vx = (Math.random() - 0.5) * 55;
        touch.vy = (Math.random() - 0.5) * 55;
      },
      resize: () => {
        syncSize();
      }
    };
  }

  // Setup instances
  let instanceA = null;
  let instanceB = null;

  function setupInstances() {
    if (window.innerWidth <= 768) return;

    const renderers = customRenderers || window.customClothRenderers || {};
    const rendererA = renderers[0] || window.renderCardTextureA;
    const rendererB = renderers[1] || window.renderCardTextureB;

    const wrapA = document.getElementById("clothWrapOptionA");
    const cardA = document.getElementById("clothCardOptionA");
    const canvasA = document.getElementById("clothCanvasOptionA");

    const wrapB = document.getElementById("clothWrapOptionB");
    const cardB = document.getElementById("clothCardOptionB");
    const canvasB = document.getElementById("clothCanvasOptionB");

    if (wrapA && cardA && canvasA && !instanceA && rendererA) {
      instanceA = createClothInstance(wrapA, cardA, canvasA, rendererA, [1, 1, 1], {
        wind: 2.0,
        light: 0.42,
        sheen: 0.12,
        shadow: 0.22,
        dark: 0
      });
    }

    if (wrapB && cardB && canvasB && !instanceB && rendererB) {
      instanceB = createClothInstance(wrapB, cardB, canvasB, rendererB, [0.05, 0.09, 0.08], {
        wind: 2.2,
        light: 0.48,
        sheen: 0.22,
        shadow: 0.25,
        dark: 1
      });
    }

    // Observe Slide 5 activation
    const slide5 = document.querySelector('.slide[data-slide="5"], .slide[data-index="5"]');
    if (slide5) {
      const obs = new MutationObserver(() => {
        if (slide5.classList.contains('active')) {
          setTimeout(() => {
            if (instanceA) instanceA.resize();
            if (instanceB) instanceB.resize();
          }, 50);
        }
      });
      obs.observe(slide5, { attributes: true, attributeFilter: ['class'] });
    }
  }

  if (document.fonts) {
    document.fonts.ready.then(setupInstances);
  } else {
    setupInstances();
  }

  // Hook global wind trigger for slide transitions
  const origTriggerWind = window.triggerCanvasUiWind;
  window.triggerCanvasUiWind = function(direction) {
    if (origTriggerWind) origTriggerWind(direction);
    if (instanceA) { instanceA.resize(); instanceA.triggerGust(); }
    if (instanceB) { instanceB.resize(); instanceB.triggerGust(); }
  };

  window.addEventListener('resize', () => {
    if (instanceA) instanceA.resize();
    if (instanceB) instanceB.resize();
  });
}

window.initClothCardPhysics = initClothCardPhysics;

