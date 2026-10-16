'use strict';
// Canvas ports of the game's procedural painters (lib/game/painting/*,
// road_segment.dart, lto_officer.dart, collectibles, obstacles, animals).
// Everything is drawn in world units: the world is 400 wide, like the game.

const W = 1080, H = 1920, S = W / 400, VH = H / S, PY = VH * 0.76;
const ROADL = 64, LW = 68, ROADR = 336, SH = 10, SEG = 200;
const laneX = (l) => ROADL + LW * (l + 0.5);
const FONT = "'Segoe UI Black','Segoe UI',Arial,sans-serif";

const cv = document.getElementById('c');
const X = cv.getContext('2d');

// ------------------------------------------------------------ colour utils
const _cc = new Map();
function C(v) {
  if (typeof v === 'string') return v;
  let s = _cc.get(v);
  if (!s) {
    const a = ((v >>> 24) & 255) / 255, r = (v >>> 16) & 255, g = (v >>> 8) & 255, b = v & 255;
    s = `rgba(${r},${g},${b},${a.toFixed(3)})`;
    _cc.set(v, s);
  }
  return s;
}
const withA = (v, a) => ((((Math.round(clamp(a, 0, 1) * 255)) & 255) << 24) | (v & 0xFFFFFF)) >>> 0;
const mulA = (v, m) => withA(v, (((v >>> 24) & 255) / 255) * m);
function lerpC(a, b, t) {
  const ch = (s) => Math.round(((a >>> s) & 255) * (1 - t) + ((b >>> s) & 255) * t);
  return ((ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0)) >>> 0;
}

// ------------------------------------------------------------- math utils
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const ease = (t) => { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); };
const easeOut = (t) => { t = clamp(t, 0, 1); return 1 - Math.pow(1 - t, 3); };
const easeIn = (t) => { t = clamp(t, 0, 1); return t * t * t; };
const backOut = (t) => { t = clamp(t, 0, 1); const c1 = 2.2, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
function mulberry(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function h01(n) { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
const wrap = (v, lo, hi) => lo + ((((v - lo) % (hi - lo)) + (hi - lo)) % (hi - lo));

// --------------------------------------------------------- draw primitives
function fs(c) { X.fillStyle = C(c); }
function R(x, y, w, h, c) { fs(c); X.fillRect(x, y, w, h); }
function RR(l, t, r, b, rad, c) {
  if (r <= l || b <= t) return;
  fs(c); X.beginPath(); X.roundRect(l, t, r - l, b - t, Math.min(rad, (r - l) / 2, (b - t) / 2)); X.fill();
}
function CI(x, y, r, c) { if (r <= 0) return; fs(c); X.beginPath(); X.arc(x, y, r, 0, Math.PI * 2); X.fill(); }
function OV(x, y, w, h, c) { fs(c); X.beginPath(); X.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, 0, Math.PI * 2); X.fill(); }
function PG(p, c) {
  fs(c); X.beginPath(); X.moveTo(p[0], p[1]);
  for (let i = 2; i < p.length; i += 2) X.lineTo(p[i], p[i + 1]);
  X.closePath(); X.fill();
}
function LN(x1, y1, x2, y2, c, w) {
  X.strokeStyle = C(c); X.lineWidth = w; X.lineCap = 'round';
  X.beginPath(); X.moveTo(x1, y1); X.lineTo(x2, y2); X.stroke();
}
function TXT(s, x, y, size, color, o = {}) {
  X.font = `${o.italic ? 'italic ' : ''}900 ${size}px ${FONT}`;
  X.textAlign = o.align || 'left';
  X.textBaseline = o.base || 'middle';
  X.letterSpacing = (o.ls || 0) + 'px';
  if (o.stroke) {
    X.lineJoin = 'round'; X.lineWidth = o.stroke; X.strokeStyle = C(o.strokeColor ?? 0xFF1A1A1A);
    X.strokeText(s, x, y);
  }
  fs(color); X.fillText(s, x, y);
  X.letterSpacing = '0px';
}

// ===================================================================== BIKES
const TIRE = 0xFF1B1B1B, METAL = 0xFFB0BEC5, DARKMETAL = 0xFF37474F;

function paintBikeBox(o) {
  // Draws in the 40x80 design box (front at the top). Caller sets transform.
  const st = o.style, body = o.body, accent = o.accent, jacket = o.jacket, helmet = o.helmet, anim = o.anim || 0;
  if (o.beam) PG([17, 8, 23, 8, 38, -70, 2, -70], 0x16FFF59D);
  OV(5, 10, 32, 70, 0x40000000);
  if (st === 'sidecar') {
    R(26, 40, 14, 3, DARKMETAL); RR(53, 42, 59, 58, 2, TIRE); OV(36, 22, 20, 40, body); OV(40, 34, 12, 20, accent);
  }
  if (st === 'tricycle') {
    RR(58, 46, 64, 64, 2, TIRE); RR(29, 10, 62, 68, 5, body); RR(32, 14, 59, 64, 4, accent);
    for (let y = 20; y < 62; y += 9) R(32, y, 27, 2, body);
  }
  RR(16, 1, 24, 19, 3, TIRE); RR(14.5, 60, 25.5, 79, 3, TIRE);
  const tread = (anim * 40) % 4;
  for (let y = 1 + tread; y < 19; y += 4) R(17, y, 6, 1.2, 0xFF3A3A3A);
  for (let y = 60 + tread; y < 79; y += 4) R(15.5, y, 9, 1.4, 0xFF3A3A3A);
  RR(27, 52, 31.5, 73, 2, METAL);
  if (st === 'cruiser') RR(8.5, 52, 13, 73, 2, METAL);
  switch (st) {
    case 'underbone': case 'sidecar': case 'tricycle':
      RR(12.5, 15, 27.5, 63, 6, body); RR(15, 20, 25, 26, 2, accent); break;
    case 'scooter':
      RR(10, 14, 30, 64, 9, body); RR(13, 54, 27, 61, 3, accent); break;
    case 'sport':
      PG([20, 5, 30, 20, 29.5, 58, 25, 67, 15, 67, 10.5, 58, 10, 20], body);
      PG([20, 8, 23, 14, 23, 60, 17, 60, 17, 14], accent);
      RR(14, 12, 26, 17, 3, 0xAA1A237E); break;
    case 'naked':
      OV(11.5, 17, 17, 22, body); RR(15, 36, 25, 64, 4, DARKMETAL); OV(15, 21, 10, 12, accent); break;
    case 'adventure':
      RR(2, 46, 11, 66, 2, accent); RR(29, 46, 38, 66, 2, accent); RR(11, 12, 29, 64, 5, body);
      RR(14, 9, 26, 15, 3, 0x88FFFFFF); break;
    case 'cruiser':
      RR(11, 13, 29, 66, 10, body); OV(13.5, 17, 13, 18, accent); RR(17, 13, 23, 16, 1, METAL); break;
  }
  const wide = st === 'cruiser' || st === 'adventure';
  RR(wide ? 3 : 6, 16, wide ? 37 : 34, 19.5, 2, DARKMETAL);
  RR(wide ? 2 : 5, 15, wide ? 7 : 10, 20.5, 2, 0xFF111111);
  RR(wide ? 33 : 30, 15, wide ? 38 : 35, 20.5, 2, 0xFF111111);
  CI(20, 12, 2.6, 0xFFFFF59D);
  LN(13, 36, wide ? 6 : 8.5, 19, jacket, 4.2);
  LN(27, 36, wide ? 34 : 31.5, 19, jacket, 4.2);
  RR(11, 30, 29, 55, 8, jacket);
  RR(13, 33, 20, 52, 5, 0x22FFFFFF);
  const bob = anim === 0 ? 0 : ((anim * 9) % 2 < 1 ? 0.4 : -0.4);
  CI(20 + bob, 33, 7.6, helmet);
  R(18.6 + bob, 25.6, 2.8, 14.8, body);
  CI(17.5 + bob, 30.5, 2.6, 0x55FFFFFF);
  RR(15.5, 62.5, 24.5, 66, 1.5, o.braking ? 0xFFFF1744 : 0xFFC62828);
  if (o.braking) CI(20, 64, 8, 0x55FF1744);
}

function bikeOpts(b, extra = {}) {
  return Object.assign({
    style: b.style, body: b.body, accent: b.accent,
    jacket: lerpC(b.accent, 0xFF263238, 0.55), helmet: b.accent,
  }, extra);
}

// Bike centred at (cx, cy) with size w x h, rotated by `rot`.
function drawBike(b, cx, cy, w, h, extra = {}) {
  X.save();
  X.translate(cx, cy); X.rotate(extra.rot || 0); X.translate(-w / 2, -h / 2);
  X.scale(w / 40, h / 80);
  if (extra.alpha !== undefined) X.globalAlpha *= extra.alpha;
  paintBikeBox(bikeOpts(b, extra));
  X.restore();
}

function drawOfficer(cx, cy, phase, rot = 0) {
  const w = 34, h = 68;
  X.save();
  X.translate(cx, cy); X.rotate(rot); X.translate(-w / 2, -h / 2);
  X.scale(w / 40, h / 80);
  paintBikeBox({ style: 'naked', body: 0xFFECEFF1, accent: 0xFF1565C0, jacket: 0xFF1565C0, helmet: 0xFFFFFFFF, anim: phase / 4 });
  const redOn = Math.floor(phase * 2) % 2 === 0;
  CI(10, 62, redOn ? 5 : 3.5, redOn ? 0xFFFF1744 : 0x55FF1744);
  CI(30, 62, !redOn ? 5 : 3.5, !redOn ? 0xFF2979FF : 0x552979FF);
  if (redOn) CI(10, 62, 14, 0x33FF1744); else CI(30, 62, 14, 0x332979FF);
  X.restore();
}

// ================================================================== VEHICLES
const VSIZE = {
  car: [42, 76], taxi: [42, 76], van: [46, 86], suv: [46, 84], jeepney: [48, 104],
  bus: [56, 132], truck: [54, 122], tricycle: [44, 60], ambulance: [46, 86],
};
const VKMH = { car: 52, taxi: 50, van: 46, suv: 40, jeepney: 38, bus: 42, truck: 36, tricycle: 28, ambulance: 60 };
const CARCOLORS = [0xFFE53935, 0xFF1E88E5, 0xFFFAFAFA, 0xFF424242, 0xFF43A047, 0xFFFDD835, 0xFF8E24AA, 0xFF90A4AE];
function vColor(type, v) {
  switch (type) {
    case 'taxi': return 0xFFF5F5F5;
    case 'jeepney': return [0xFFCFD8DC, 0xFFFFCA28, 0xFFEF5350][v % 3];
    case 'bus': return [0xFF1565C0, 0xFFF4511E, 0xFF00897B][v % 3];
    case 'truck': return [0xFFE53935, 0xFF1E88E5, 0xFFFFB300][v % 3];
    case 'tricycle': return [0xFF1E88E5, 0xFFE53935, 0xFF43A047][v % 3];
    default: return CARCOLORS[v % CARCOLORS.length];
  }
}
const GLASS = 0xFF263850, GLASSHI = 0xFF3E5A7A, VDARK = 0xFF1C1C1C;

function vWheels(w, h) {
  const f = h * 0.14, r = h * 0.76, len = h * 0.12;
  for (const y of [f, r]) { RR(-2, y, 3, y + len, 2, 0xFF111111); RR(w - 3, y, w + 2, y + len, 2, 0xFF111111); }
}
function vMirrors(w, y, c) { RR(-4, y, 2, y + 4, 2, c); RR(w - 2, y, w + 4, y + 4, 2, c); }
function vLights(w, h, inset = 4) {
  RR(inset, 1, inset + 9, 5, 2, 0xFFFFF9C4); RR(w - inset - 9, 1, w - inset, 5, 2, 0xFFFFF9C4);
  RR(inset, h - 5, inset + 8, h - 1.5, 2, 0xFFD50000); RR(w - inset - 8, h - 5, w - inset, h - 1.5, 2, 0xFFD50000);
}
function vCar(w, h, c, taxi) {
  vMirrors(w, h * 0.3, c);
  RR(0, 0, w, h, 10, c);
  PG([5, h * 0.27, w - 5, h * 0.27, w - 8, h * 0.38, 8, h * 0.38], GLASS);
  RR(7, h * 0.75, w - 7, h * 0.84, 3, GLASS);
  RR(6, h * 0.38, w - 6, h * 0.75, 5, lerpC(c, 0xFFFFFFFF, 0.18));
  R(9, h * 0.29, 6, 2, GLASSHI);
  if (taxi) { RR(w * 0.3, h * 0.5, w * 0.7, h * 0.58, 2, 0xFFFFC107); R(0, h * 0.62, w, 3, 0xFF212121); }
  vLights(w, h);
}
function vVan(w, h, c) {
  vMirrors(w, h * 0.18, c);
  RR(0, 0, w, h, 8, c);
  RR(5, h * 0.12, w - 5, h * 0.24, 3, GLASS);
  RR(5, h * 0.26, w - 5, h * 0.95, 4, lerpC(c, 0xFFFFFFFF, 0.15));
  const d = lerpC(c, 0xFF000000, 0.12);
  for (let y = h * 0.35; y < h * 0.9; y += h * 0.14) R(8, y, w - 16, 2, d);
  vLights(w, h);
}
function vJeepney(w, h, c, variant) {
  vMirrors(w, h * 0.2, 0xFFCFD8DC);
  RR(4, 0, w - 4, h * 0.22, 6, 0xFFB0BEC5);
  for (let x = 8; x < w - 8; x += 5) R(x, 2, 2, h * 0.05, 0xFFECEFF1);
  CI(w * 0.35, h * 0.12, 2.5, 0xFFFFD54F); CI(w * 0.65, h * 0.12, 2.5, 0xFFFFD54F);
  R(5, h * 0.21, w - 10, h * 0.06, GLASS);
  RR(0, h * 0.26, w, h, 5, c);
  const stripes = [0xFFE53935, 0xFF1E88E5, 0xFFFFEB3B, 0xFF43A047];
  for (let i = 0; i < 4; i++) R(3, h * (0.33 + i * 0.15), w - 6, 4, stripes[(i + variant) % 4]);
  R(w * 0.25, h - 6, w * 0.5, 6, 0xFF424242);
  R(3, h - 4, 6, 3, 0xFFD50000); R(w - 9, h - 4, 6, 3, 0xFFD50000);
  CI(9, 3, 3, 0xFFFFF9C4); CI(w - 9, 3, 3, 0xFFFFF9C4);
}
function vBus(w, h, c) {
  vMirrors(w, h * 0.06, VDARK);
  RR(0, 0, w, h, 7, c);
  RR(4, 3, w - 4, h * 0.09, 3, GLASS);
  RR(5, h * 0.12, w - 5, h * 0.96, 4, 0xFFF5F5F5);
  RR(w * 0.22, h * 0.3, w * 0.78, h * 0.42, 3, 0xFFB0BEC5);
  RR(w * 0.22, h * 0.6, w * 0.78, h * 0.72, 3, 0xFFB0BEC5);
  R(5, h * 0.5, w - 10, 4, c);
  vLights(w, h, 3);
}
function vTruck(w, h, c) {
  vMirrors(w, h * 0.08, VDARK);
  RR(2, 0, w - 2, h * 0.24, 7, c);
  R(6, h * 0.04, w - 12, h * 0.07, GLASS);
  R(w * 0.3, h * 0.23, w * 0.4, h * 0.04, 0xFF616161);
  RR(0, h * 0.26, w, h, 3, 0xFFE0E0E0);
  for (let y = h * 0.3; y < h; y += 9) R(3, y, w - 6, 2, 0xFFBDBDBD);
  R(0, h - 4, w, 4, 0xFFFF6F00);
  RR(5, 1, 13, 4, 2, 0xFFFFF9C4); RR(w - 13, 1, w - 5, 4, 2, 0xFFFFF9C4);
}
function vTricycle(w, h, c) {
  RR(w * 0.17, 0, w * 0.31, h * 0.22, 2, VDARK);
  RR(w * 0.16, h * 0.74, w * 0.32, h, 2, VDARK);
  RR(w * 0.12, h * 0.15, w * 0.36, h * 0.85, 4, c);
  CI(w * 0.24, h * 0.5, w * 0.11, 0xFF37474F);
  RR(w * 0.88, h * 0.6, w, h * 0.86, 2, VDARK);
  RR(w * 0.38, h * 0.05, w * 0.96, h * 0.95, 5, c);
  RR(w * 0.44, h * 0.12, w * 0.9, h * 0.88, 4, 0xFFFFF8E1);
  R(w * 0.44, h * 0.4, w * 0.46, 3, c);
  R(w * 0.42, h - 3, 5, 2.5, 0xFFD50000);
}
function vSuv(w, h, c, blink) {
  vMirrors(w, h * 0.24, c);
  RR(0, 0, w, h, 9, c);
  RR(5, h * 0.2, w - 5, h * 0.33, 3, 0xFF0D0D0D);
  RR(6, h * 0.82, w - 6, h * 0.9, 3, 0xFF0D0D0D);
  RR(5, h * 0.34, w - 5, h * 0.8, 4, lerpC(c, 0xFFFFFFFF, 0.12));
  R(7, h * 0.38, 2, h * 0.38, 0xFF9E9E9E); R(w - 9, h * 0.38, 2, h * 0.38, 0xFF9E9E9E);
  const on = Math.floor(blink * 6) % 2 === 0;
  R(w * 0.3, h * 0.21, w * 0.15, 3, on ? 0xFF2979FF : 0xFFFF1744);
  R(w * 0.55, h * 0.21, w * 0.15, 3, on ? 0xFFFF1744 : 0xFF2979FF);
  CI(w * 0.37, h * 0.22, 7, withA(0xFF2979FF, on ? 0.22 : 0.08));
  CI(w * 0.63, h * 0.22, 7, withA(0xFFFF1744, on ? 0.08 : 0.22));
  vLights(w, h);
}

function drawVehicle(cx, cy, type, color, o = {}) {
  const [w, h] = VSIZE[type];
  X.save();
  X.translate(cx - w / 2, cy - h / 2);
  if (o.rot) { X.translate(w / 2, h / 2); X.rotate(o.rot); X.translate(-w / 2, -h / 2); }
  RR(4, 7, w + 5, h + 7, 11, 0x22000000);
  RR(2, 3, w + 2, h + 3, 9, 0x33000000);
  X.save();
  if (o.down) { X.translate(w, h); X.rotate(Math.PI); }
  if (type !== 'tricycle') {
    fs(o.beamStrong ? 0x30FFF9C4 : 0x12FFF9C4);
    X.beginPath();
    X.moveTo(w * 0.15, 2); X.lineTo(w * 0.3, 2); X.lineTo(w * 0.42, -h * 0.32); X.lineTo(-w * 0.05, -h * 0.32); X.closePath();
    X.moveTo(w * 0.7, 2); X.lineTo(w * 0.85, 2); X.lineTo(w * 1.05, -h * 0.32); X.lineTo(w * 0.58, -h * 0.32); X.closePath();
    X.fill();
    vWheels(w, h);
  }
  switch (type) {
    case 'car': case 'taxi': vCar(w, h, color, type === 'taxi'); break;
    case 'van': vVan(w, h, color); break;
    case 'jeepney': vJeepney(w, h, color, o.variant || 0); break;
    case 'bus': vBus(w, h, color); break;
    case 'truck': vTruck(w, h, color); break;
    case 'tricycle': vTricycle(w, h, color); break;
    case 'suv': vSuv(w, h, color, o.blink || 0); break;
    case 'ambulance': {
      vVan(w, h, 0xFFFAFAFA);
      R(w * 0.42, h * 0.45, w * 0.16, h * 0.3, 0xFFD32F2F);
      R(w * 0.25, h * 0.54, w * 0.5, h * 0.12, 0xFFD32F2F);
      R(0, h * 0.85, w, 3, 0xFFFF6F00);
      const on = Math.floor((o.blink || 0) * 2) % 2 === 0;
      RR(5, h * 0.27, w * 0.45, h * 0.32, 2, on ? 0xFFFF1744 : 0xFF2979FF);
      RR(w * 0.55, h * 0.27, w - 5, h * 0.32, 2, on ? 0xFF2979FF : 0xFFFF1744);
      CI(w / 2, h * 0.3, w * 0.9, on ? 0x33FF1744 : 0x332979FF);
      break;
    }
  }
  if (o.braking) {
    RR(3, h - 6, 13, h - 1, 2, 0xFFFF1744); RR(w - 13, h - 6, w - 3, h - 1, 2, 0xFFFF1744);
    CI(8, h, 11, 0x55FF1744); CI(w - 8, h, 11, 0x55FF1744);
  }
  if (o.signal && Math.floor((o.blink || 0) * 2.5) % 2 === 0) {
    const sx = o.signal < 0 ? 2 : w - 8;
    RR(sx, 1, sx + 6, 6, 2, 0xFFFFAB00); RR(sx, h - 7, sx + 6, h - 2, 2, 0xFFFFAB00);
    CI(sx + 3, 3, 9, 0x44FFAB00); CI(sx + 3, h - 4, 9, 0x44FFAB00);
  }
  X.restore();
  X.restore();
}

// ===================================================================== PROPS
const PSIZE = {
  building: [56, 74], tower: [60, 96], nipaHut: [46, 42], sariSari: [44, 40], tree: [44, 44], palm: [48, 48],
  pine: [36, 36], streetlight: [34, 14], roadSign: [34, 14], warningSign: [22, 22], rock: [36, 30],
  billboard: [50, 18], boat: [22, 56], bush: [30, 24], flyover: [1200, 64],
};
const ROOFS = [0xFF90A4AE, 0xFFB0BEC5, 0xFF8D6E63, 0xFF78909C, 0xFFBCAAA4, 0xFF607D8B];

function drawProp(type, x, y, variant, onLeft) {
  const [w, h] = PSIZE[type];
  X.save(); X.translate(x, y);
  switch (type) {
    case 'building': case 'tower':
      R(5, 6, w, h, 0x40000000);
      R(0, 0, w, h, ROOFS[variant % ROOFS.length]);
      R(0, 0, w, 3, 0x33000000); R(0, 0, 3, h, 0x33000000);
      R(w - 3, 0, 3, h, 0x22FFFFFF); R(0, h - 3, w, 3, 0x22FFFFFF);
      CI(w * 0.3, h * 0.28, 6, 0xFF1976D2);
      R(w * 0.55, h * 0.55, 10, 8, 0xFFECEFF1); R(w * 0.2, h * 0.68, 10, 8, 0xFFECEFF1);
      if (type === 'tower') {
        X.strokeStyle = C(0x55FFFFFF); X.lineWidth = 2; X.beginPath(); X.arc(w * 0.62, h * 0.24, 10, 0, 7); X.stroke();
        CI(w - 6, 6, 2.5, 0xFFFF1744);
      }
      break;
    case 'nipaHut':
      R(5, 6, w, h, 0x40000000);
      R(0, 0, w, h, 0xFFC8A165); R(0, h / 2 - 1.5, w, 3, 0xFFA67C42);
      for (let xx = 4; xx < w; xx += 5) LN(xx, 2, xx, h - 2, 0x55704A1E, 1.2);
      break;
    case 'sariSari':
      R(5, 6, w, h, 0x40000000);
      R(0, 0, w, h * 0.75, variant % 2 === 0 ? 0xFFD32F2F : 0xFF1976D2);
      for (let xx = 4; xx < w; xx += 6) LN(xx, 1, xx, h * 0.75 - 1, 0x44FFFFFF, 1.5);
      for (let i = 0; i < 6; i++) R(w * i / 6, h * 0.75, w / 6, h * 0.25, i % 2 === 0 ? 0xFFFFFFFF : 0xFFFFC107);
      break;
    case 'tree':
      CI(w * 0.55, h * 0.58, w * 0.45, 0x33000000); CI(w * 0.5, h * 0.5, w * 0.42, 0xFF2E7D32);
      CI(w * 0.38, h * 0.4, w * 0.24, 0xFF43A047); CI(w * 0.62, h * 0.55, w * 0.2, 0xFF43A047);
      break;
    case 'palm': {
      CI(w * 0.56, h * 0.58, w * 0.4, 0x33000000);
      const cx = w / 2, cy = h / 2;
      for (let i = 0; i < 7; i++) { const a = i * Math.PI * 2 / 7 + variant; LN(cx, cy, cx + Math.cos(a) * w * 0.46, cy + Math.sin(a) * w * 0.46, 0xFF388E3C, 6); }
      for (let i = 0; i < 7; i++) { const a = i * Math.PI * 2 / 7 + variant; LN(cx, cy, cx + Math.cos(a) * w * 0.4, cy + Math.sin(a) * w * 0.4, 0xFF66BB6A, 2); }
      CI(cx, cy, 4.5, 0xFF795548);
      break;
    }
    case 'pine':
      CI(w * 0.56, h * 0.58, w * 0.45, 0x33000000); CI(w / 2, h / 2, w * 0.48, 0xFF1B5E20);
      CI(w / 2, h / 2, w * 0.32, 0xFF2E7D32); CI(w / 2, h / 2, w * 0.16, 0xFF388E3C);
      break;
    case 'streetlight':
      if (onLeft) { X.translate(w, 0); X.scale(-1, 1); }
      RR(0, h / 2 - 2, w - 6, h / 2 + 2, 2, 0xFF546E7A);
      CI(4, h / 2, 13, 0x44FFF59D);
      RR(0, h / 2 - 4, 10, h / 2 + 4, 3, 0xFFFFF59D);
      CI(w - 5, h / 2, 4, 0xFF37474F);
      break;
    case 'roadSign':
      R(w * 0.2, h - 3, 2, 3, 0xFF616161); R(w * 0.8 - 2, h - 3, 2, 3, 0xFF616161);
      RR(0, 0, w, h - 3, 2, 0xFF2E7D32); R(4, 3, w * 0.5, 2, 0xFFFFFFFF); R(4, 7, w * 0.7, 2, 0xFFFFFFFF);
      break;
    case 'warningSign':
      R(w / 2 - 1, h * 0.6, 2, h * 0.4, 0xFF424242);
      PG([w / 2, 0, w, h * 0.42, w / 2, h * 0.84, 0, h * 0.42], 0xFFFFD600);
      R(w / 2 - 1.2, h * 0.18, 2.4, h * 0.3, 0xFF212121); CI(w / 2, h * 0.6, 1.5, 0xFF212121);
      break;
    case 'rock':
      OV(3, 4, w, h, 0x33000000);
      PG([w * 0.2, 0, w * 0.75, h * 0.08, w, h * 0.55, w * 0.7, h, w * 0.15, h * 0.9, 0, h * 0.4], 0xFF757575);
      CI(w * 0.4, h * 0.35, w * 0.15, 0xFF9E9E9E);
      break;
    case 'billboard': {
      R(w * 0.25, h - 4, 3, 4, 0xFF455A64); R(w * 0.75 - 3, h - 4, 3, 4, 0xFF455A64);
      const ads = [0xFFFF7043, 0xFFAB47BC, 0xFF26A69A, 0xFFFFCA28];
      RR(0, 0, w, h - 4, 2, ads[variant % 4]);
      R(4, 3, w * 0.45, 3, 0xCCFFFFFF); R(4, 8, w * 0.3, 3, 0xCCFFFFFF); CI(w * 0.78, (h - 4) / 2, 4, 0xCCFFFFFF);
      break;
    }
    case 'boat':
      LN(-6, h * 0.35, w + 6, h * 0.35, 0xFFD7CCC8, 2); LN(-6, h * 0.65, w + 6, h * 0.65, 0xFFD7CCC8, 2);
      LN(-8, h * 0.25, -8, h * 0.75, 0xFFD7CCC8, 2); LN(w + 8, h * 0.25, w + 8, h * 0.75, 0xFFD7CCC8, 2);
      fs(variant % 2 === 0 ? 0xFFFFFFFF : 0xFFFFEB3B);
      X.beginPath(); X.moveTo(w / 2, 0); X.quadraticCurveTo(w, h * 0.3, w * 0.8, h); X.lineTo(w * 0.2, h);
      X.quadraticCurveTo(0, h * 0.3, w / 2, 0); X.closePath(); X.fill();
      R(w * 0.3, h * 0.4, w * 0.4, h * 0.3, 0xFF1E88E5);
      break;
    case 'bush':
      OV(0, 0, w, h, 0xFF558B2F); OV(w * 0.2, h * 0.15, w * 0.5, h * 0.5, 0xFF7CB342);
      break;
    case 'flyover':
      R(0, h * 0.2 + 18, w, h, 0x44000000);
      R(0, 0, w, h, 0xFFB0BEC5); R(0, 0, w, 5, 0xFF90A4AE); R(0, h - 5, w, 5, 0xFF90A4AE);
      for (let xx = 10; xx < w; xx += 46) R(xx, h / 2 - 1.5, 24, 3, 0xFFECEFF1);
      break;
  }
  X.restore();
}

// ============================================================== ENVIRONMENTS
const ENVS = [
  { name: 'City Highway', tagline: 'Flyovers, streetlights, and traffic', lg: 'sidewalk', rg: 'sidewalk',
    lc: 0xFF8D9AA3, rc: 0xFF8D9AA3, dc: 0xFF7A8790, asphalt: 0xFF3C4043, shoulder: 0xFF5F6368,
    rails: false, cross: false, lp: ['building', 'streetlight', 'building', 'roadSign'],
    rp: ['building', 'streetlight', 'billboard', 'building'], sp: 120, accent: 0xFF42A5F5 },
  { name: 'Provincial Road', tagline: 'Rice fields and sari-sari stores', lg: 'ricefield', rg: 'ricefield',
    lc: 0xFF7CB342, rc: 0xFF8BC34A, dc: 0xFF558B2F, asphalt: 0xFF4A4A48, shoulder: 0xFFA1887F,
    rails: false, cross: false, lp: ['nipaHut', 'palm', 'tree', 'bush'], rp: ['sariSari', 'palm', 'tree', 'nipaHut'],
    sp: 150, accent: 0xFF9CCC65 },
  { name: 'Mountain Road', tagline: 'Cliffs, pines, and sharp curves', lg: 'cliff', rg: 'forest',
    lc: 0xFF795548, rc: 0xFF2E7D32, dc: 0xFF5D4037, asphalt: 0xFF424242, shoulder: 0xFF6D6D6D,
    rails: true, cross: false, lp: ['rock', 'warningSign', 'rock'], rp: ['pine', 'pine', 'warningSign', 'pine'],
    sp: 110, accent: 0xFF8D6E63 },
  { name: 'Coastal Highway', tagline: 'Ocean breeze and palm trees', lg: 'sea', rg: 'sand',
    lc: 0xFF29B6F6, rc: 0xFFFFE082, dc: 0xFF81D4FA, asphalt: 0xFF455A64, shoulder: 0xFFFFECB3,
    rails: true, cross: false, lp: ['boat', 'boat'], rp: ['palm', 'palm', 'sariSari', 'bush'], sp: 140, accent: 0xFF26C6DA },
  { name: 'Urban Road', tagline: 'Jeepneys, crosswalks, and chaos', lg: 'concrete', rg: 'concrete',
    lc: 0xFF9E9E9E, rc: 0xFFA5A5A5, dc: 0xFF888888, asphalt: 0xFF353535, shoulder: 0xFFBDBDBD,
    rails: false, cross: true, lp: ['tower', 'building', 'billboard', 'tower'], rp: ['tower', 'streetlight', 'building', 'tower'],
    sp: 100, accent: 0xFFFF7043 },
];

// ====================================================================== ROAD
const _decor = new Map();
function decorFor(k, env) {
  const key = k * 8 + env;
  let d = _decor.get(key);
  if (d) return d;
  const rnd = mulberry(k * 7919 + 17);
  const patches = [];
  const np = 2 + Math.floor(rnd() * 2);
  for (let i = 0; i < np; i++) patches.push([ROADL + 4 + rnd() * 230, rnd() * 170, 18 + rnd() * 34, 10 + rnd() * 22]);
  const cracks = [];
  for (let i = 0; i < 2; i++) {
    let x = ROADL + 10 + rnd() * 250, y = rnd() * 180;
    const pts = [x, y];
    for (let j = 0; j < 4; j++) { x += -8 + rnd() * 16; y += 4 + rnd() * 8; pts.push(x, y); }
    cracks.push(pts);
  }
  const stains = rnd() < 0.5 ? [[laneX(Math.floor(rnd() * 4)) + (rnd() - 0.5) * 20, rnd() * 180]] : [];
  const e = ENVS[env];
  const urban = e.lg === 'sidewalk' || e.lg === 'concrete';
  const manhole = urban && rnd() < 0.35 ? [laneX(Math.floor(rnd() * 4)) + 18, 30 + rnd() * 140] : null;
  d = { patches, cracks, stains, manhole };
  _decor.set(key, d);
  return d;
}

function drawGround(style, base, detail, left, right, top, h, k, isLeft, time) {
  R(left, top, right - left, h, base);
  const near = isLeft ? right : left;
  const rnd = mulberry(k * 31 + (isLeft ? 1 : 2));
  switch (style) {
    case 'sidewalk': case 'concrete': {
      const step = style === 'sidewalk' ? 20 : 32;
      for (let y = 0; y < h; y += step) R(left, top + y, right - left, 1.5, detail);
      for (let x = near; isLeft ? x > left : x < right; x += isLeft ? -step : step) R(x, top, 1.5, h, detail);
      R(isLeft ? right - 4 : left, top, 4, h, 0xFFCFD8DC);
      break;
    }
    case 'ricefield':
      for (let x = near + (isLeft ? -10 : 10); isLeft ? x > left : x < right; x += isLeft ? -7 : 7) R(x, top, 2, h, detail);
      R(left, top + 96, right - left, 4, 0xFF8D6E63);
      R(isLeft ? right - 6 : left, top, 6, h, 0xFF8D6E63);
      break;
    case 'forest':
      for (let i = 0; i < 6; i++) { const dx = rnd() * 300; CI(isLeft ? near - 8 - dx : near + 8 + dx, top + rnd() * h, 8, mulA(detail, 0.5)); }
      for (let i = 0; i < 5; i++) { const dx = rnd() * 300; CI(isLeft ? near - 10 - dx : near + 10 + dx, top + rnd() * h, 6, 0xFF1B5E20); }
      break;
    case 'cliff':
      for (let y = 0; y < h; y += 26) PG([left, top + y, right - 6, top + y + 14, right - 6, top + y + 20, left, top + y + 8], detail);
      R(isLeft ? right - 6 : left, top, 6, h, 0xFF9E9E9E);
      break;
    case 'sea':
      X.strokeStyle = C(detail); X.lineWidth = 2; X.lineCap = 'round';
      for (let i = 0; i < 7; i++) {
        const x = near - 24 - rnd() * 280, y = top + rnd() * h, drift = Math.sin(time * 2 + i) * 4;
        X.beginPath(); X.ellipse(x + drift + 9, y + 4, 9, 4, 0, Math.PI, Math.PI * 2); X.stroke();
      }
      R(isLeft ? right - 14 : left, top, 14, h, 0xFFFFE082);
      R(isLeft ? right - 16 : left + 14, top, 2, h, 0xAAFFFFFF);
      break;
    case 'sand':
      for (let i = 0; i < 14; i++) { const dx = rnd() * 300; CI(isLeft ? near - dx : near + dx, top + rnd() * h, 1.5, 0xFFFFD54F); }
      break;
  }
}

function drawSegment(envIdx, k, top, time) {
  const env = ENVS[envIdx];
  const rt = top - 1, rh = SEG + 2;
  drawGround(env.lg, env.lc, env.dc, -900, ROADL - SH, rt, rh, k, true, time);
  drawGround(env.rg, env.rc, env.dc, ROADR + SH, 1300, rt, rh, k, false, time);
  R(ROADL - SH, rt, SH, rh, env.shoulder); R(ROADR, rt, SH, rh, env.shoulder);
  R(ROADL, rt, ROADR - ROADL, rh, env.asphalt);
  // Wear.
  const d = decorFor(k, envIdx);
  for (let lane = 0; lane < 4; lane++) {
    const cx = laneX(lane);
    R(cx - 20, top - 1, 9, rh, 0x12000000); R(cx + 11, top - 1, 9, rh, 0x12000000);
  }
  R(ROADL, top - 1, 8, rh, 0x1A000000); R(ROADR - 8, top - 1, 8, rh, 0x1A000000);
  for (const p of d.patches) { R(p[0], p[1] + top, p[2], p[3], 0x1C000000); R(p[0], p[1] + top, p[2], 1.2, 0x10FFFFFF); }
  for (const s of d.stains) OV(s[0] - 11, s[1] + top - 6.5, 22, 13, 0x22000000);
  if (d.manhole) {
    const mx = d.manhole[0], my = d.manhole[1] + top;
    CI(mx, my, 9, 0xFF55595D); CI(mx, my, 7, 0xFF3F4347);
    R(mx - 6, my - 0.75, 12, 1.5, 0x22FFFFFF); R(mx - 0.75, my - 6, 1.5, 12, 0x22FFFFFF);
  }
  X.strokeStyle = C(0x40000000); X.lineWidth = 1.1; X.lineCap = 'butt';
  for (const c of d.cracks) {
    X.beginPath(); X.moveTo(c[0], c[1] + top);
    for (let i = 2; i < c.length; i += 2) X.lineTo(c[i], c[i + 1] + top);
    X.stroke();
  }
  if (env.cross && ((k % 6) + 6) % 6 === 3) for (let x = ROADL + 6; x < ROADR - 10; x += 16) R(x, top + 80, 9, 40, 0xDDFFFFFF);
  if (env.rails) {
    for (const rx of [ROADL - SH - 2, ROADR + SH - 2]) {
      R(rx, rt, 4, rh, 0xFF90A4AE);
      for (let y = 0; y < SEG; y += 25) R(rx - 1, top + y, 6, 4, 0xFF546E7A);
    }
  }
}

const _props = new Map();
function propsFor(k, envIdx) {
  const key = k * 8 + envIdx;
  let list = _props.get(key);
  if (list) return list;
  const env = ENVS[envIdx];
  const rnd = mulberry(k * 977 + envIdx * 131 + 5);
  list = [];
  for (const left of [true, false]) {
    const types = left ? env.lp : env.rp;
    const n = Math.max(1, Math.round(SEG / env.sp + rnd() * 0.6));
    for (let i = 0; i < n; i++) {
      const type = types[Math.floor(rnd() * types.length)];
      const [pw, ph] = PSIZE[type];
      const y = (i + rnd() * 0.6) * SEG / n - ph / 2 + 20;
      let x;
      if (type === 'streetlight') x = left ? ROADL - SH - pw + 9 : ROADR + SH - 9;
      else if (type === 'boat') x = 4 + rnd() * 26;
      else x = left ? ROADL - SH - pw - 3 - rnd() * 6 : ROADR + SH + 3 + rnd() * 6;
      list.push({ type, x, y, v: Math.floor(rnd() * 6), left });
      // Second row further out, for the wide shots.
      const far = left ? env.lp : env.rp;
      const t2 = far[Math.floor(rnd() * far.length)];
      if (t2 !== 'streetlight' && t2 !== 'roadSign' && t2 !== 'billboard') {
        const [pw2] = PSIZE[t2];
        const x2 = t2 === 'boat' ? -70 - rnd() * 60 : left ? x - pw2 - 14 - rnd() * 16 : x + PSIZE[type][0] + 14 + rnd() * 16;
        list.push({ type: t2, x: x2, y: y + rnd() * 40 - 20, v: Math.floor(rnd() * 6), left });
      }
    }
  }
  _props.set(key, list);
  return list;
}

// envAt(k) -> environment index for road segment k.
function drawRoad(scroll, envAt, vy0, vy1, time) {
  const dmin = scroll + VH - vy1, dmax = scroll + VH - vy0;
  const k0 = Math.floor(dmin / SEG) - 1, k1 = Math.floor(dmax / SEG) + 1;
  const tops = [];
  for (let k = k0; k <= k1; k++) {
    const top = VH - ((k + 1) * SEG - scroll);
    tops.push([k, top]);
    drawSegment(envAt(k), k, top, time);
  }
  // Lane markings.
  const period = 56, dash = 26, phase = ((scroll % period) + period) % period;
  for (const lane of [1, 3]) {
    const x = ROADL + LW * lane - 2;
    for (let y = phase - period + Math.floor(vy0 / period) * period; y < vy1; y += period) {
      const idx = Math.round((scroll + VH - y) / period) + lane * 7;
      const wear = ((((idx * 2654435761) % 1000) + 1000) % 1000) / 1000;
      R(x, y, 4, dash, withA(0xFFFFFFFF, 0.62 + 0.33 * wear));
    }
  }
  const cx = ROADL + LW * 2;
  R(cx - 5, vy0, 3, vy1 - vy0, 0xFFFFC400); R(cx + 2, vy0, 3, vy1 - vy0, 0xFFFFC400);
  R(ROADL + 2, vy0, 3, vy1 - vy0, 0xCCFFFFFF); R(ROADR - 5, vy0, 3, vy1 - vy0, 0xCCFFFFFF);
  // Props on top of the ground.
  for (const [k, top] of tops) {
    for (const p of propsFor(k, envAt(k))) drawProp(p.type, p.x, top + p.y, p.v, p.left);
  }
}

// ===================================================== COLLECTIBLES & HAZARDS
const CASHC = { 20: 0xFFFF9800, 50: 0xFFE53935, 100: 0xFF7E57C2 };
function drawCash(cx, cy, value, phase, alpha = 1, scale = 1) {
  const w = 34, h = 18, color = CASHC[value];
  const flip = Math.abs(Math.cos(phase)) * 0.6 + 0.4;
  X.save(); X.translate(cx, cy); X.scale(flip * scale, scale); X.translate(-w / 2, -h / 2);
  X.globalAlpha *= alpha;
  RR(2, 3, w + 2, h + 3, 2, 0x40000000);
  RR(0, 0, w, h, 2, color);
  RR(2, 2, w - 2, h - 2, 1.5, 0x8CFFFFFF);
  RR(3.5, 3.5, w - 3.5, h - 3.5, 1, color);
  CI(w * 0.27, h / 2, 4.2, 0x59FFFFFF);
  TXT(String(value), w * 0.66, h / 2 + 0.5, 9, 0xFFFFFFFF, { align: 'center' });
  X.restore();
}

function drawFuel(cx, cy, time, alpha = 1, scale = 1) {
  const w = 26, h = 32;
  X.save(); X.translate(cx, cy); X.scale(scale, scale); X.translate(-w / 2, -h / 2);
  X.globalAlpha *= alpha;
  const pulse = 0.5 + 0.5 * Math.sin(time * 6);
  CI(w / 2, h / 2, w * (0.9 + 0.15 * pulse), withA(0xFFFFEB3B, 0.25 + 0.25 * pulse));
  RR(3, 4, w + 3, h + 3, 4, 0x4D000000);
  RR(0, 4, w, h, 4, 0xFFD32F2F);
  X.strokeStyle = C(0xFFB71C1C); X.lineWidth = 2.5; X.beginPath(); X.roundRect(5, 0, w - 14, 8, 3); X.stroke();
  R(w - 8, 1, 5, 6, 0xFFFFD600);
  LN(6, 11, w - 6, h - 4, 0x99FFFFFF, 2.5); LN(w - 6, 11, 6, h - 4, 0x99FFFFFF, 2.5);
  X.restore();
}

function drawObstacle(type, cx, cy) {
  const sz = { pothole: [40, 28], cone: [20, 20], barrier: [56, 22], box: [26, 22] }[type];
  const w = sz[0], h = sz[1];
  X.save(); X.translate(cx - w / 2, cy - h / 2);
  switch (type) {
    case 'pothole':
      OV(0, 0, w, h, 0xFF5D5D5D); OV(4, 3, w - 8, h - 6, 0xFF1E1E1E); OV(w * 0.3, h * 0.35, w * 0.35, h * 0.3, 0xFF2F3A44);
      break;
    case 'cone':
      CI(w / 2 + 2, h / 2 + 3, w / 2, 0x44000000); R(1, 1, w - 2, h - 2, 0xFFFF6D00);
      CI(w / 2, h / 2, w * 0.38, 0xFFFF9100); CI(w / 2, h / 2, w * 0.25, 0xFFFFFFFF); CI(w / 2, h / 2, w * 0.13, 0xFFFF6D00);
      break;
    case 'barrier': {
      R(3, 4, w, h, 0x44000000);
      RR(0, 0, w, h, 3, 0xFFF5F5F5);
      X.save(); X.beginPath(); X.roundRect(0, 0, w, h, 3); X.clip();
      const n = Math.max(3, Math.floor(w / 12));
      for (let i = 0; i < n; i += 2) { const x0 = w * i / n; PG([x0, 0, x0 + w / n, 0, x0 + w / n - 6, h, x0 - 6, h], 0xFFFF3D00); }
      X.restore();
      CI(5, h / 2, 2.5, 0xFFFFEB3B); CI(w - 5, h / 2, 2.5, 0xFFFFEB3B);
      break;
    }
  }
  X.restore();
}

// ==================================================================== ANIMALS
function drawAnimal(kind, cx, cy, variant, anim, facingRight, alert) {
  const sz = { dog: [46, 28], cat: [38, 22], chicken: [50, 33] }[kind];
  const w = sz[0], h = sz[1];
  X.save(); X.translate(cx - w / 2, cy - h / 2);
  X.save();
  if (!facingRight) { X.translate(w, 0); X.scale(-1, 1); }
  const shadow = () => OV(w * 0.1, h * 0.55, w * 0.8, h * 0.5, 0x33000000);
  const legs = (c, l, r, t, b) => {
    const sw = Math.sin(anim) * 3;
    for (const lx of [l + 4, r - 6]) { OV(lx + sw, t - 3, 4, 5, c); OV(lx - sw, b - 2, 4, 5, c); }
  };
  if (kind === 'dog') {
    const fur = [0xFFB57A45, 0xFF8D6E63, 0xFFE0C097][variant % 3];
    shadow();
    legs(lerpC(fur, 0xFF000000, 0.3), w * 0.18, w * 0.72, h * 0.22, h * 0.78);
    const wag = Math.sin(anim * 1.5) * 4;
    OV(1, h * 0.38 + wag, 10, 5, fur);
    OV(w * 0.15, h * 0.22, w * 0.6, h * 0.56, fur);
    OV(w * 0.3, h * 0.32, w * 0.3, h * 0.2, 0x33FFFFFF);
    CI(w * 0.8, h * 0.5, h * 0.3, fur);
    const ear = lerpC(fur, 0xFF000000, 0.35);
    OV(w * 0.7, h * 0.12, 6, 5, ear); OV(w * 0.7, h * 0.72, 6, 5, ear);
    CI(w * 0.97, h * 0.5, 2.2, 0xFF3E2723);
  } else if (kind === 'cat') {
    const fur = [0xFF9E9E9E, 0xFFFFA726, 0xFF424242][variant % 3];
    shadow();
    legs(lerpC(fur, 0xFF000000, 0.3), w * 0.2, w * 0.7, h * 0.2, h * 0.8);
    X.strokeStyle = C(fur); X.lineWidth = 3; X.lineCap = 'round';
    X.beginPath(); X.moveTo(w * 0.2, h * 0.5); X.quadraticCurveTo(0, h * 0.5 + Math.sin(anim) * 5, 3, h * 0.15); X.stroke();
    OV(w * 0.18, h * 0.25, w * 0.55, h * 0.5, fur);
    CI(w * 0.8, h * 0.5, h * 0.3, fur);
    PG([w * 0.74, h * 0.3, w * 0.8, h * 0.05, w * 0.86, h * 0.3], fur);
    PG([w * 0.74, h * 0.7, w * 0.8, h * 0.95, w * 0.86, h * 0.7], fur);
    CI(w * 0.86, h * 0.38, 1.6, 0xFF1B5E20); CI(w * 0.86, h * 0.62, 1.6, 0xFF1B5E20);
  } else {
    const offs = [[4, 3], [17, 14], [28, 2]];
    shadow();
    for (let i = 0; i < 3; i++) {
      const [ox, oy] = offs[i];
      const bob = Math.sin(anim + i * 1.7) * 1.5;
      R(ox + 4 + bob, oy + 11, 2, 3, 0xFFFFA000); R(ox + 8 - bob, oy + 11, 2, 3, 0xFFFFA000);
      OV(ox, oy + bob * 0.3, 14, 12, i === 1 ? 0xFFD7A86E : 0xFFFAFAFA);
      CI(ox + 13, oy + 2 + bob * 0.3, 2.5, 0xFFE53935);
      R(ox + 15, oy + 5 + bob * 0.3, 3, 2, 0xFFFFB300);
    }
  }
  X.restore();
  if (alert) {
    const cx2 = w / 2;
    RR(cx2 - 9, -22, cx2 + 9, -6, 5, 0xFFFFFFFF);
    PG([cx2 - 3, -7, cx2 + 3, -7, cx2, -2], 0xFFFFFFFF);
    if (alert === '!!') {
      R(cx2 - 5, -19, 3, 7, 0xFFD50000); R(cx2 + 2, -19, 3, 7, 0xFFD50000);
      R(cx2 - 5, -11, 3, 2.5, 0xFFD50000); R(cx2 + 2, -11, 3, 2.5, 0xFFD50000);
    } else {
      R(cx2 - 1.5, -19, 3, 7, 0xFFD50000); R(cx2 - 1.5, -11, 3, 2.5, 0xFFD50000);
    }
  }
  X.restore();
}

// ================================================================= CHECKPOINT
function drawCheckpoint(cy, time) {
  const h = 90;
  X.save(); X.translate(0, cy - h / 2);
  for (let i = 0; i < 4; i++) { const y = 8 + i * 22; CI(ROADR - 10, y, 5, 0xFFFF6D00); CI(ROADR - 10, y, 2.4, 0xFFFFFFFF); }
  R(ROADR + 18, h * 0.3 + 4, 44, 40, 0x44000000);
  R(ROADR + 14, h * 0.3, 44, 40, 0xFF1565C0);
  R(ROADR + 14, h * 0.3 + 16, 44, 8, 0xFFFFFFFF);
  TXT('LTO', ROADR + 36, h * 0.3 + 20.5, 10, 0xFF0D47A1, { align: 'center', ls: 1.2 });
  const on = Math.floor(time * 3) % 2 === 0;
  CI(ROADR + 50, h * 0.3 + 6, 4, on ? 0xFFFFAB00 : 0xFF8D6E00);
  if (on) CI(ROADR + 50, h * 0.3 + 6, 14, 0x44FFAB00);
  R(ROADR + 2, h * 0.86, 8, 8, 0xFF37474F);
  for (let i = 0; i < 6; i++) R(ROADR + 4, h * 0.86 - (i + 1) * 9, 4, 9, i % 2 === 0 ? 0xFFD50000 : 0xFFFFFFFF);
  for (let lane = 0; lane < 4; lane++) {
    const cx = laneX(lane);
    PG([cx - 14, h - 4, cx, h - 14, cx + 14, h - 4, cx + 14, h, cx, h - 10, cx - 14, h], 0x99FFFFFF);
  }
  const wave = Math.sin(time * 10) * 4;
  CI(ROADR + 4, h * 0.75, 7, 0xFF0D47A1); CI(ROADR + 4, h * 0.75, 4.5, 0xFFFFFFFF);
  CI(ROADR - 6 + wave, h * 0.6, 5, 0xFFD50000);
  R(ROADL - 8, 10, ROADR - ROADL + 16, 22, 0x55000000);
  R(ROADL - 12, 2, 8, 26, 0xFF37474F); R(ROADR + 4, 2, 8, 26, 0xFF37474F);
  RR(ROADL + 30, 2, ROADR - 30, 26, 4, 0xFF0D47A1);
  R(ROADL + 30, 22, ROADR - ROADL - 60, 3, 0xFFFFD600);
  TXT('LTO CHECKPOINT', 200, 13, 13, 0xFFFFFFFF, { align: 'center', ls: 1.2 });
  X.restore();
}

// Red ▼ warning at the top of an oncoming lane.
function drawWarning(lane, y, time) {
  const on = Math.floor(time * 8) % 2 === 0;
  const cx = laneX(lane);
  CI(cx, y, 20, on ? 0x55FF1744 : 0x22FF1744);
  PG([cx - 13, y - 9, cx + 13, y - 9, cx, y + 12], on ? 0xFFFF1744 : 0xFFB71C1C);
  PG([cx - 6, y - 5, cx + 6, y - 5, cx, y + 4], 0x88FFFFFF);
}
