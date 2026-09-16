# CanvasUI 3D WebGL Cloth Engine Blueprint

Dokumentacija i gotov predložak za implementaciju kinematografske 3D simulacije tkanine (viseće kartice paketa, zastave na jarbolu, baneri, platna) unutar prezentacijskih mikrosajtova na `varazdin.studio`.

---

## 1. Zašto ova arhitektura (Zero-Dependency WebGL2)

Originalni React / Three.js paketi (npr. `canvasui.dev/docs/components/cloth`) ovise o teškim bibliotekama i koriste SVG `<foreignObject>` ili `html2canvas` za pretvaranje HTML-a u teksturu. U prezentacijama to stvara 3 kritična problema:
1. **`0px` zamka na neaktivnim slajdovima:** Slajdovi s `display: none` imaju širinu i visinu `0px`. Mreža točaka pri dijeljenju stvara `NaN` koordinate u vertex bufferu i ruši WebGL.
2. **CORS / Tainted Canvas blokada:** Sigurnosna pravila preglednika često blokiraju SVG teksture ako sadrže vanjske fontove ili slike.
3. **Kašnjenje renderiranja:** Fontovi se ne stižu iscrtati prije prvog framea, pa kartica ostaje prazna.

### Rješenje:
- **Direct 2D Canvas Rasterizacija:** Crtanje grafike (tekst, boje, logotipi, zastave) na 2D `OffscreenCanvas` s `devicePixelRatio` skaliranjem (0 ms kašnjenja, 100% oštrina).
- **Hardverski ubrzan WebGL2 Shader:** 96×96 mreža (18.432 trokuta) s fizikom valova, difuznim sjenčanjem, spekularnim svjetlom i SDF kontaktnom sjenom.
- **Životni ciklus s MutationObserverom:** Inicijalizacija i osvježavanje točno u trenutku kad slajd postane vidljiv.

---

## 2. Podržane vrste primjene

### A. Viseće kartice ponude (Pinned Top)
- **Sidrenje:** Gornji rub fiksiran (`hNext[b] = 0` za $y = 0$).
- **Fizika:** Gravitacijski objes prema dolje (`hangCurve = pow(y / SEG, 1.3)`), blagi povjetarac i odziv na prelazak mišem.

### B. Zastava na jarbolu (Pinned Left)
- **Sidrenje:** Lijevi vertikalni rub fiksiran ($x = 0$).
- **Fizika:** Horizontalno vijorenje s rastućom amplitudom prema desnom slobodnom rubu (`hangCurve = pow(x / SEG, 1.2)`).
- **Primjena:** Državne zastave, zastave gradova, brendirani festivalski ili korporativni baneri.

### C. Zategnuto platno / Billboard (Pinned 4 Corners)
- **Sidrenje:** Fiksirana 4 kuta, sredina elastično vibrira na vjetar i pritisak kursora.

---

## 3. Parametri i ugođavanje (Fizikalna matrica)

| Parametar | Optimalno (Paketi) | Zastava (Jarbol) | Opis |
|---|---|---|---|
| `amplitude` | `18` - `20` | `28` - `35` | Dubina nabora u pikselima |
| `drape` | `20` - `24` | `10` - `15` | Gravitacijski progib tkanine |
| `wind` | `1.8` - `2.2` | `3.5` - `4.5` | Bazna jačina vjetra |
| `speed` | `0.40` - `0.46` | `0.65` - `0.85` | Brzina kretanja valova |
| `damping` | `0.92` - `0.94` | `0.88` - `0.90` | Prigušenje oscilacija (veće = mirnije) |
| `STIFFNESS` | `0.60` | `0.45` | Krutost opruga među čvorovima |
| `FORCE_GAIN` | `3.25` | `5.0` | Skaliranje sile valne jednadžbe |
| `brush` | `1.2` - `1.5` | `2.0` | Reakcija na pomicanje miša preko tkanine |
| `light` | `0.40` | `0.55` | Difuzno osvjetljenje nabora |
| `sheen` | `0.12` - `0.20` | `0.30` | Spekularni odsjaj materijala (svila/najlon) |

---

## 4. Arhitekturni kod za ponovnu upotrebu

### A. HTML struktura
```html
<div class="cloth-card-container" id="clothWrapZastava">
  <!-- HTML Fallback element (vidljiv dok se WebGL ne pokrene) -->
  <div class="card-fallback" id="clothCardZastava">
    <!-- Statični sadržaj ili SVG zastave -->
  </div>
  <!-- WebGL platno -->
  <canvas class="cloth-card-canvas" id="clothCanvasZastava"></canvas>
</div>
```

### B. CSS pravila
```css
.cloth-card-container {
  position: relative;
  width: 100%;
  height: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
}
.cloth-card-canvas {
  position: absolute;
  inset: -48px; /* BLEED margina za sjenu i njihanje */
  width: calc(100% + 96px);
  height: calc(100% + 96px);
  pointer-events: auto;
  z-index: 2;
}
.card-fallback {
  width: 100%;
  height: 100%;
  transition: opacity 0.4s ease;
}
.card-fallback.cloth-active {
  opacity: 0;
  pointer-events: none;
}
```

### C. WebGL2 Shaders & Physics Core
```javascript
const SDF_SNIPPET = `
float fabricDist (vec2 p, vec2 b, float r) {
  vec2 d = abs(p - b * 0.5) - (b * 0.5 - vec2(r));
  return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}
`;

const CLOTH_VERT = `#version 300 es
layout(location = 0) in vec2 aUv;
layout(location = 1) in vec4 aData;   // [z, dzdx, dzdy, fold]
layout(location = 2) in vec2 aOffset; // [offX, offY]

uniform vec2 uRes;
uniform vec2 uOut;
uniform float uBleed;
uniform float uFocal;
uniform float uMaxX;

out vec2 vUv;
out vec3 vNormal;
out float vFold;

void main () {
  vUv = aUv;
  float z = aData.x;
  vNormal = normalize(vec3(aData.y, aData.z, 1.0));
  vFold = aData.w;

  vec2 pixelPos = aUv * uRes + aOffset;
  pixelPos.x = mix(pixelPos.x, uRes.x * 0.5, 0.0);
  vec2 outPos = pixelPos + vec2(uBleed);

  vec2 clip = (outPos / uOut) * 2.0 - 1.0;
  clip.y = -clip.y;

  float pFactor = uFocal / max(uFocal - z, 1.0);
  vec2 ndc = clip * pFactor;
  gl_Position = vec4(ndc, 0.0, 1.0);
}`;

const CLOTH_FRAG = `#version 300 es
precision highp float;
in vec2 vUv;
in vec3 vNormal;
in float vFold;
out vec4 outColor;

uniform sampler2D uContent;
uniform vec2 uRes;
uniform float uLight;
uniform float uSheen;
uniform float uRadius;
uniform float uDark;
uniform vec3 uBacking;
${SDF_SNIPPET}

void main () {
  vec2 pixel = vUv * uRes;
  float d = fabricDist(pixel, uRes, uRadius);
  if (d > 1.0) discard;

  vec4 src = texture(uContent, vUv);
  vec3 base = src.rgb;
  
  // Osvjetljenje i odsjaj nabora
  vec3 lightDir = normalize(vec3(0.35, -0.45, 0.85));
  float diff = max(dot(vNormal, lightDir), 0.0);
  vec3 viewDir = vec3(0.0, 0.0, 1.0);
  vec3 halfDir = normalize(lightDir + viewDir);
  float spec = pow(max(dot(vNormal, halfDir), 0.0), 16.0);

  vec3 lit = base * (1.0 - uLight + diff * uLight * 1.3) * vFold;
  lit += vec3(spec * uSheen);

  float edgeAlpha = clamp(0.5 - d, 0.0, 1.0);
  outColor = vec4(lit * edgeAlpha, src.a * edgeAlpha);
}`;
```

---

## 5. Prilagodba za Zastave (Flag Mode)

Za efekt zastave koja vijori na jarbolu (sidrena s lijeve strane):

1. **U `stepSim`:**
   ```javascript
   // Umjesto fiksiranja gornjeg reda, fiksiraj lijevi stupac (x = 0):
   for (let y = 0; y < NODES; y++) {
     hNext[y * NODES] = 0; // Pinned left
   }
   ```
2. **U `composeVertices`:**
   ```javascript
   // Amplituda raste od jarbola (lijevo) prema slobodnom rubu (desno):
   const flagSpread = Math.pow(x / SEG, 1.2);
   zField[i] = (opts.amplitude * Math.tanh(hCur[i]) + drape) * flagSpread;
   ```
3. **U `renderFlagTexture`:**
   Nacrtaj grb, trobojnicu ili vizual brenda na 2D canvasu i proslijedi u `gl.texImage2D`.

---

## 6. Sigurnosni kontrolni popis (QA Checklist)

- [ ] **Zero-Size Guard:** `if (wrapEl.clientWidth < 30) return;` u petlji.
- [ ] **MutationObserver:** Prati promjenu `.slide.active` i poziva `resize()`.
- [ ] **Fallback element:** Uklanja se tek kad `hasValidTexture === true`.
- [ ] **DPR skaliranje:** Tekstura se generira u `Math.min(devicePixelRatio, 2)` rezoluciji.
- [ ] **Čišćenje resursa:** WebGL kontekst se oslobađa pri uklanjanju komponente.
