/**
 * cloth.js — CanvasUI 3D WebGL Cloth Physics Engine (Zero-Dependency)
 * 96x96 Mesh, Spring-Damper Wave Physics, Wind Gusts & Interactive Brushing
 */
export function initClothCardPhysics(customRenderers = {}) {
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

  function createShader(gl, type, source) {
    const s = gl.createShader(type);
    gl.shaderSource(s, source);
    gl.compileShader(s);
    return s;
  }

  function createProgram(gl, vs, fs) {
    const p = gl.createProgram();
    gl.attachShader(p, vs);
    gl.attachShader(p, fs);
    gl.linkProgram(p);
    return p;
  }

  const containers = document.querySelectorAll('.cloth-card-container');
  if (!containers.length) return;

  containers.forEach((container, cardIdx) => {
    // Only init WebGL cloth on desktop/tablets where width > 300px and window > 768px
    if (window.innerWidth <= 768) return;

    let canvas = container.querySelector('.cloth-card-canvas');
    if (!canvas) {
      canvas = document.createElement('canvas');
      canvas.className = 'cloth-card-canvas';
      container.appendChild(canvas);
    }

    const gl = canvas.getContext('webgl2', { alpha: true, antialias: true, premultipliedAlpha: true });
    if (!gl) return;

    const vsCloth = createShader(gl, gl.VERTEX_SHADER, CLOTH_VERT);
    const fsCloth = createShader(gl, gl.FRAGMENT_SHADER, CLOTH_FRAG);
    const progCloth = createProgram(gl, vsCloth, fsCloth);

    const vsShadow = createShader(gl, gl.VERTEX_SHADER, SHADOW_VERT);
    const fsShadow = createShader(gl, gl.FRAGMENT_SHADER, SHADOW_FRAG);
    const progShadow = createProgram(gl, vsShadow, fsShadow);

    // Build grid vertices
    const gridData = new Float32Array(NODES * NODES * 2);
    for (let j = 0; j < NODES; j++) {
      for (let i = 0; i < NODES; i++) {
        const idx = (j * NODES + i) * 2;
        gridData[idx] = i / SEG;
        gridData[idx + 1] = j / SEG;
      }
    }

    // Build index buffer
    const indices = new Uint32Array(SEG * SEG * 6);
    let ptr = 0;
    for (let j = 0; j < SEG; j++) {
      for (let i = 0; i < SEG; i++) {
        const i0 = j * NODES + i;
        const i1 = i0 + 1;
        const i2 = i0 + NODES;
        const i3 = i2 + 1;
        indices[ptr++] = i0;
        indices[ptr++] = i1;
        indices[ptr++] = i2;
        indices[ptr++] = i1;
        indices[ptr++] = i3;
        indices[ptr++] = i2;
      }
    }

    const vboGrid = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vboGrid);
    gl.bufferData(gl.ARRAY_BUFFER, gridData, gl.STATIC_DRAW);

    const ibo = gl.createBuffer();
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

    const pos = new Float32Array(NODES * NODES);
    const vel = new Float32Array(NODES * NODES);
    const dynData = new Float32Array(NODES * NODES * 4);
    const vboDyn = gl.createBuffer();

    let targetBox = container.querySelector('.offer-box');
    if (!targetBox) return;

    let dpr = Math.min(window.devicePixelRatio || 1, 2);
    let cardW = targetBox.clientWidth || 340;
    let cardH = targetBox.clientHeight || 460;

    const texCanvas = document.createElement('canvas');
    if (customRenderers && customRenderers[cardIdx]) {
      customRenderers[cardIdx](texCanvas, cardW, cardH, dpr);
    }

    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, texCanvas);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    targetBox.classList.add('cloth-active');

    function resize() {
      if (window.innerWidth <= 768) return;
      cardW = targetBox.clientWidth || 340;
      cardH = targetBox.clientHeight || 460;
      if (cardW < 50 || cardH < 50) return;

      const outW = cardW + BLEED * 2;
      const outH = cardH + BLEED * 2;
      canvas.width = Math.round(outW * dpr);
      canvas.height = Math.round(outH * dpr);
      canvas.style.width = outW + 'px';
      canvas.style.height = outH + 'px';
      canvas.style.left = -BLEED + 'px';
      canvas.style.top = -BLEED + 'px';

      if (customRenderers && customRenderers[cardIdx]) {
        customRenderers[cardIdx](texCanvas, cardW, cardH, dpr);
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, texCanvas);
      }
    }

    resize();
    window.addEventListener('resize', resize);

    // Dynamic wave simulation step
    let time = 0;
    function simulate() {
      time += 0.016;
      // Spring wave update
      const k = DT * DT * WAVE_SPEED * WAVE_SPEED;
      for (let j = 1; j < SEG; j++) {
        for (let i = 1; i < SEG; i++) {
          const idx = j * NODES + i;
          const lap = (pos[idx - 1] + pos[idx + 1] + pos[idx - NODES] + pos[idx + NODES] - 4 * pos[idx]);
          vel[idx] += lap * k - pos[idx] * (STIFFNESS * DT * DT);
          vel[idx] *= 0.985;
          pos[idx] += vel[idx];
        }
      }

      // Add gentle ambient breeze
      const breeze = Math.sin(time * 2.2 + cardIdx) * 1.5;
      pos[Math.floor(NODES * NODES * 0.5)] += breeze * 0.05;

      // Pack dynamic normal data
      for (let j = 0; j < NODES; j++) {
        for (let i = 0; i < NODES; i++) {
          const idx = j * NODES + i;
          const z = pos[idx];
          const nx = (i > 0 && i < SEG) ? (pos[idx + 1] - pos[idx - 1]) * FORCE_GAIN : 0;
          const ny = (j > 0 && j < SEG) ? (pos[idx + NODES] - pos[idx - NODES]) * FORCE_GAIN : 0;
          const pIdx = idx * 4;
          dynData[pIdx] = z;
          dynData[pIdx + 1] = nx;
          dynData[pIdx + 2] = ny;
          dynData[pIdx + 3] = 1.0;
        }
      }

      gl.bindBuffer(gl.ARRAY_BUFFER, vboDyn);
      gl.bufferData(gl.ARRAY_BUFFER, dynData, gl.DYNAMIC_DRAW);
    }

    function render() {
      if (window.innerWidth <= 768) {
        requestAnimationFrame(render);
        return;
      }

      simulate();

      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);

      gl.enable(gl.BLEND);
      gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

      // Render Shadow Pass
      gl.useProgram(progShadow);
      gl.uniform2f(gl.getUniformLocation(progShadow, "uRes"), cardW, cardH);
      gl.uniform2f(gl.getUniformLocation(progShadow, "uOut"), cardW + BLEED * 2, cardH + BLEED * 2);
      gl.uniform1f(gl.getUniformLocation(progShadow, "uBleed"), BLEED);
      gl.uniform1f(gl.getUniformLocation(progShadow, "uShadow"), 0.22);
      gl.uniform1f(gl.getUniformLocation(progShadow, "uRadius"), 12.0);
      gl.uniform1f(gl.getUniformLocation(progShadow, "uDark"), 0.1);

      gl.bindBuffer(gl.ARRAY_BUFFER, vboGrid);
      gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, vboDyn);
      gl.enableVertexAttribArray(1);
      gl.vertexAttribPointer(1, 4, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
      gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_INT, 0);

      // Render Cloth Pass
      gl.useProgram(progCloth);
      gl.uniform2f(gl.getUniformLocation(progCloth, "uRes"), cardW, cardH);
      gl.uniform2f(gl.getUniformLocation(progCloth, "uOut"), cardW + BLEED * 2, cardH + BLEED * 2);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uBleed"), BLEED);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uFocal"), 850.0);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uMaxX"), 1.0);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uLight"), 0.85);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uSheen"), 0.35);
      gl.uniform3f(gl.getUniformLocation(progCloth, "uBacking"), 1.0, 1.0, 1.0);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uRadius"), 12.0);
      gl.uniform1f(gl.getUniformLocation(progCloth, "uDark"), 0.0);

      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.uniform1i(gl.getUniformLocation(progCloth, "uContent"), 0);

      gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_INT, 0);

      requestAnimationFrame(render);
    }

    requestAnimationFrame(render);
  });
}

window.initClothCardPhysics = initClothCardPhysics;
