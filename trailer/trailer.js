'use strict';
// Kamote Rider: Highway Escape — trailer timeline.
// renderFrame(t) draws the frame at time t (seconds). CUES lists audio events
// for render.py. 150 BPM: one beat = 0.4 s, one bar = 1.6 s.

const DUR = 51.2;
const CUES = [];
const FLASHES = [];
const cue = (t, name, vol = 1) => CUES.push({ t: +t.toFixed(4), name, vol });

// ===================================================================== DATA
const BIKES = [
  ['Kamote 110', 'underbone', 0xFFE53935, 0xFFFFFFFF, 0, 1, 1, 6, 8],
  ['Barangay 125', 'scooter', 0xFF1E88E5, 0xFFFFEB3B, 1000, 1, 2, 5, 9],
  ['Sidecar Sprint', 'sidecar', 0xFF43A047, 0xFFFFFFFF, 2000, 1, 3, 3, 9],
  ['Tricycle Escape', 'tricycle', 0xFFFFB300, 0xFF6D4C41, 3500, 2, 4, 2, 10],
  ['Highway Cub', 'underbone', 0xFF00897B, 0xFFFFFFFF, 5000, 2, 5, 7, 6],
  ['Provincial Flash', 'scooter', 0xFFF4511E, 0xFF212121, 7000, 2, 6, 6, 5],
  ['Road Rebel 150', 'naked', 0xFF263238, 0xFFFF5252, 10000, 3, 7, 7, 5],
  ['Falcon Street 200', 'sport', 0xFFFDD835, 0xFF212121, 14000, 3, 8, 8, 4],
  ['Midnight Racer', 'sport', 0xFF311B92, 0xFF00E5FF, 18000, 3, 9, 6, 6],
  ['Thunder 250', 'naked', 0xFF1565C0, 0xFFFFFFFF, 24000, 4, 10, 7, 3],
  ['Asphalt Phantom', 'sport', 0xFF212121, 0xFF76FF03, 32000, 4, 11, 9, 3],
  ['Mountain Stalker', 'adventure', 0xFF558B2F, 0xFFFF6F00, 42000, 4, 12, 8, 5],
  ['Highway King 400', 'cruiser', 0xFF8D6E63, 0xFFFFD54F, 55000, 5, 13, 6, 4],
  ['Impound Legend', 'sport', 0xFFC62828, 0xFFFFD600, 75000, 5, 14, 9, 2],
  ['Kamote Xtreme', 'sport', 0xFFFF6F00, 0xFF6A1B9A, 100000, 5, 15, 10, 1],
].map(([name, style, body, accent, price, tier, spd, hnd, fuel]) => ({ name, style, body, accent, price, tier, spd, hnd, fuel }));
const BK = (n) => BIKES.find((b) => b.name === n);
const RARITY = [null, ['COMMON', 0xFF9E9E9E], ['UNCOMMON', 0xFF4CAF50], ['RARE', 0xFF2196F3], ['EPIC', 0xFF9C27B0], ['LEGENDARY', 0xFFFFA000]];

const YELLOW = 0xFFFFC400, KRED = 0xFFE53935, MUTED = 0xFF9AA4B8, INK = 0xFF1A1A1A;
const peso = (v) => '₱' + Math.round(v).toLocaleString('en-US');
const fmtDist = (m) => (m < 1000 ? `${Math.round(m)} m` : `${(m / 1000).toFixed(2)} km`);
const kmh2u = (k) => k / 3.6 * 14;

// ============================================================ ENTITY HELPERS
function laneTrack(keys, dur = 0.2) {
  return (t) => {
    let x = laneX(keys[0][1]);
    for (let i = 1; i < keys.length; i++) {
      const [kt, l] = keys[i];
      if (t < kt) break;
      x = lerp(x, laneX(l), ease((t - kt) / dur));
    }
    return x;
  };
}
const leanOf = (fx, t) => clamp((fx(t + 0.03) - fx(t - 0.03)) / 0.06 / 340 * 0.3, -0.32, 0.32);
const laneAt = (fx, t) => Math.round((fx(t) - ROADL) / LW - 0.5);

const veh = (type, lane, ta, playerU, o = {}) => {
  const v = kmh2u(VKMH[type]);
  return Object.assign({ k: 'veh', type, lane, ta, rel: o.down ? playerU + v : playerU - v, color: vColor(type, o.variant || 0) }, o);
};
const cash = (lane, ta, value, u) => ({ k: 'cash', lane, ta, value, rel: u });
const fuelCan = (lane, ta, u) => ({ k: 'fuel', lane, ta, rel: u });
const obst = (type, lane, ta, u) => ({ k: type, lane, ta, rel: u });
const animal = (kind, x0, ta, actY, u, steps, variant = 0) => ({ k: 'animal', kind, x0, ta, actY, rel: u, steps, variant });
const ey = (e, t) => (e.yf ? e.yf(t) : PY - e.rel * (e.ta - t));

function markCollected(ents, fx) {
  for (const e of ents) if (e.k === 'cash' || e.k === 'fuel') e.got = laneAt(fx, e.ta) === e.lane;
}

function pathAt(steps, t) {
  let x = 0, rem = t;
  for (let i = 0; i < steps.length; i++) {
    const [dur, vx, alert] = steps[i];
    if (i === steps.length - 1 || rem <= dur) return { x: x + vx * Math.max(0, rem), vx, alert };
    x += vx * dur; rem -= dur;
  }
  return { x, vx: 0, alert: false };
}

// ============================================================== WORLD RENDER
function drawWorld(st) {
  const cam = Object.assign({ z: 1, fx: 200, fy: VH / 2, rot: 0, sx: 0, sy: 0 }, st.cam || {});
  const t = st.t;
  X.save();
  X.translate(W / 2 + cam.sx, H / 2 + cam.sy); X.rotate(cam.rot); X.scale(S * cam.z, S * cam.z); X.translate(-cam.fx, -cam.fy);
  const hh = H / 2 / (S * cam.z) * 1.3 + 60;
  const vy0 = cam.fy - hh, vy1 = cam.fy + hh;
  const envAt = typeof st.env === 'function' ? st.env : () => st.env;
  drawRoad(st.scroll, envAt, vy0, vy1, t);

  const ents = st.ents || [];
  const layer = { pothole: 0, skid: 0, cone: 1, barrier: 1, cash: 2, fuel: 3, animal: 4, veh: 5 };
  const list = ents.filter((e) => layer[e.k] !== undefined).sort((a, b) => layer[a.k] - layer[b.k]);
  for (const e of list) {
    const y = ey(e, t);
    if (y < vy0 - 160 || y > vy1 + 160) continue;
    const x = e.xf ? e.xf(t) : laneX(e.lane);
    switch (e.k) {
      case 'veh':
        drawVehicle(x, y, e.type, e.color, {
          down: e.down, variant: e.variant || 0, braking: e.brakeAt !== undefined && t > e.brakeAt,
          signal: e.signal, blink: t, beamStrong: e.beamStrong,
        });
        break;
      case 'cash': {
        const ph = t * 4 + e.lane * 1.3 + e.ta;
        if (t >= e.ta && e.got) {
          const a = t - e.ta;
          if (a < 0.25) drawCash(x, PY - 24 - 170 * a, e.value, ph, 1 - a / 0.25, 1 + 2.5 * a);
        } else drawCash(x, y, e.value, ph);
        break;
      }
      case 'fuel':
        if (t >= e.ta && e.got) {
          const a = t - e.ta;
          if (a < 0.3) drawFuel(x, PY - 10, t, 1 - a / 0.3, 1 + 3 * a);
        } else drawFuel(x, y, t);
        break;
      case 'pothole': case 'cone': case 'barrier':
        drawObstacle(e.k, x + (e.dx || 0), y);
        break;
      case 'animal': {
        const tAct = e.ta - (PY - e.actY) / e.rel;
        const lt = t - tAct;
        const p = lt >= 0 ? pathAt(e.steps, lt) : { x: 0, vx: 0, alert: false };
        const facing = p.vx !== 0 ? p.vx > 0 : e.steps.find((s) => s[1] !== 0)[1] > 0;
        drawAnimal(e.kind, e.x0 + p.x, y, e.variant, lt > 0 ? lt * (e.kind === 'chicken' ? 14 : 18) : 0, facing, p.alert ? '!' : null);
        break;
      }
    }
  }
  if (st.smoke) for (const p of st.smoke) CI(p.x, p.y, p.r, withA(0xFFB0B0B0, p.a));
  if (st.player) {
    const p = st.player;
    drawBike(p.bike, p.x, p.y ?? PY, 34, 68, { rot: p.rot || 0, braking: p.braking, anim: p.anim ?? t, beam: p.beam });
  }
  if (st.officer) drawOfficer(st.officer.x, st.officer.y, t * 4, st.officer.rot || 0);
  for (const e of ents) {
    if (e.k === 'checkpoint') drawCheckpoint(ey(e, t), t);
    if (e.k === 'flyover') drawProp('flyover', -400, ey(e, t) - 32, 0, false);
  }
  if (st.extraWorld) st.extraWorld();
  for (const e of ents) {
    if (e.k === 'warn' && t >= e.t0 && t <= e.t1) drawWarning(e.lane, Math.max(vy0 + 40, 26), t);
    if (e.k === 'float' && t >= e.t0 && t < e.t0 + 1.1) {
      const a = (t - e.t0) / 1.1;
      const fx = typeof e.x === 'function' ? e.x(e.t0) : e.x;
      const fy = (typeof e.y === 'function' ? e.y(e.t0) : e.y) - 40 * a;
      X.save(); X.globalAlpha = 1 - easeIn(a);
      TXT(e.text, fx, fy, e.size || 15, e.color, { align: 'center', stroke: 4, italic: true });
      X.restore();
    }
  }
  if (st.atmo !== undefined) drawAtmo(st.atmo, t, st.speedU || 400, vy0, vy1);
  if (st.lines) drawSpeedLines(t, st.speedU || 400, st.lines, vy0, vy1);
  X.restore();
}

function drawAtmo(env, t, speed, vy0, vy1) {
  const L = -600, Rr = 1000;
  X.save();
  switch (env) {
    case 0: {
      const g = X.createLinearGradient(0, 0, 0, VH * 0.4);
      g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      X.globalAlpha = 0.22; X.fillStyle = g; X.fillRect(L, vy0, Rr - L, vy1 - vy0);
      break;
    }
    case 1:
      R(L, vy0, Rr - L, vy1 - vy0, withA(0xFFFFD678, 0.06));
      for (let i = 0; i < 36; i++) { const p = particle(i, t, speed, false); CI(p.x, p.y, 1.2 + p.v, withA(0xFFD7B482, 0.35)); }
      break;
    case 2:
      R(L, vy0, Rr - L, vy1 - vy0, withA(0xFF78A0C8, 0.07));
      for (let i = 0; i < 3; i++) {
        const fx = ((t * (10 + i * 6) + i * 170) % 700) - 200, fy = VH * (0.08 + 0.18 * i);
        OV(fx - 160, fy - 35, 320, 70, 0x1AFFFFFF);
      }
      break;
    case 3: {
      const g = X.createLinearGradient(0, 0, 0, VH);
      g.addColorStop(0, 'rgba(255,112,67,1)'); g.addColorStop(0.45, 'rgba(255,183,77,0.333)'); g.addColorStop(1, 'rgba(255,183,77,0)');
      X.globalAlpha = 0.28; X.fillStyle = g; X.fillRect(L, vy0, Rr - L, vy1 - vy0);
      const r = X.createRadialGradient(330, 40, 0, 330, 40, 160);
      r.addColorStop(0, 'rgba(255,243,224,1)'); r.addColorStop(1, 'rgba(255,204,128,0)');
      X.globalAlpha = 0.5; X.fillStyle = r; X.beginPath(); X.arc(330, 40, 160, 0, 7); X.fill();
      break;
    }
    case 4:
      R(L, vy0, Rr - L, vy1 - vy0, withA(0xFF1E2D50, 0.14));
      for (let i = 0; i < 90; i++) {
        const p = particle(i, t, speed, true);
        LN(p.x, p.y, p.x - 5, p.y + 20 * p.v, withA(0xFFD2E1FF, 0.5), 1.4);
      }
      break;
  }
  X.restore();
}
function particle(i, t, speed, rainy) {
  const v = 0.5 + h01(i + 200);
  const rate = rainy ? (520 + speed * 0.8) * v : (speed * 0.9 + 20) * v;
  const span = VH + 40;
  const raw = h01(i + 100) * span + rate * t;
  const cyc = Math.floor(raw / span);
  const y = raw - cyc * span - 20;
  const x0 = -60 + h01(i * 31 + cyc * 7 + 1) * 520;
  const x = rainy ? wrap(x0 - 60 * t, -80, 480) : x0 - Math.cos(t * 0.8 + i) * 22;
  return { x, y, v };
}
function drawSpeedLines(t, speed, a, vy0, vy1) {
  const total = vy1 - vy0 + 300;
  for (let i = 0; i < 20; i++) {
    const left = i % 2 === 0;
    const len = 40 + h01(i * 3 + 5) * 80;
    const raw = h01(i + 50) * total + speed * 1.8 * t;
    const cyc = Math.floor(raw / total);
    const y = vy0 + raw - cyc * total - 200;
    const x = left ? ROADL - 34 + h01(i * 13 + cyc) * 54 : ROADR - 20 + h01(i * 17 + cyc) * 54;
    LN(x, y, x, y + len, withA(0xFFFFFFFF, 0.3 * a), 2);
  }
}

// ======================================================================= HUD
// Drawn in the game's logical coordinates (400 wide), like the Flutter HUD.
function hud(fn) { X.save(); X.setTransform(S, 0, 0, S, 0, 0); fn(); X.restore(); }

function glyph(kind, x, y, c) {
  switch (kind) {
    case 'fuel': RR(x, y - 8, x + 11, y + 8, 2, c); R(x + 2, y - 6, 7, 4, 0xFF10141F); LN(x + 12, y - 4, x + 15, y + 2, c, 2); break;
    case 'route': LN(x + 2, y + 7, x + 6, y - 7, c, 2); LN(x + 14, y + 7, x + 10, y - 7, c, 2); R(x + 7.2, y - 2, 1.6, 4, c); break;
    case 'speed':
      X.strokeStyle = C(c); X.lineWidth = 2.2; X.beginPath(); X.arc(x + 8, y + 4, 7, Math.PI, 0); X.stroke();
      LN(x + 8, y + 4, x + 12, y - 1, c, 2); break;
    case 'cash': RR(x, y - 6, x + 16, y + 6, 2, c); CI(x + 8, y, 2.6, 0xFF10141F); break;
    case 'bike': CI(x + 3, y + 1, 3, c); CI(x + 12, y + 1, 3, c); LN(x + 3, y + 1, x + 8, y - 3, c, 1.6); LN(x + 8, y - 3, x + 12, y + 1, c, 1.6); break;
  }
}
function chip(text, x, y, color, alignRight = false) {
  X.font = `900 10px ${FONT}`;
  const w = X.measureText(text).width + 12;
  const l = alignRight ? x - w : x;
  RR(l, y - 8, l + w, y + 8, 6, withA(color, 0.22));
  TXT(text, l + 6, y + 0.5, 10, color);
  return w;
}

function drawTopBar(h) {
  const x = 10, y = 12, w = 380, hh = 98, L = x + 10, Rt = x + w - 6;
  RR(x, y, x + w, y + hh, 16, 0xCC10141F);
  X.strokeStyle = C(0x1FFFFFFF); X.lineWidth = 1; X.beginPath(); X.roundRect(x + 0.5, y + 0.5, w - 1, hh - 1, 16); X.stroke();
  // Row 1: fuel gauge + pause.
  const f = clamp(h.fuel, 0, 1);
  const blink = h.low ? (Math.sin(h.t * Math.PI / 0.45) * 0.5 + 0.5) : 0;
  const fc = f > 0.5 ? 0xFF66BB6A : f > 0.25 ? 0xFFFFCA28 : 0xFFFF5252;
  glyph('fuel', L, y + 28, lerpC(fc, 0xFFFFFFFF, blink * 0.8));
  const bl = L + 26, br = Rt - 48 - 58;
  RR(bl, y + 20, br, y + 36, 8, 0x1FFFFFFF);
  if (f > 0) RR(bl + 1.5, y + 21.5, bl + 1.5 + (br - bl - 3) * f, y + 34.5, 7, fc);
  X.strokeStyle = C(h.low ? withA(0xFFFF5252, blink) : 0x3DFFFFFF); X.lineWidth = 1.5;
  X.beginPath(); X.roundRect(bl, y + 20, br - bl, 16, 8); X.stroke();
  TXT(h.low ? 'LOW!' : `${Math.round(f * 100)}%`, br + 58, y + 28.5, 14, h.low ? lerpC(0xFFFF5252, 0xFFFFFFFF, blink) : 0xFFFFFFFF, { align: 'right' });
  CI(Rt - 20, y + 28, 18, 0x1AFFFFFF);
  R(Rt - 25, y + 21, 3.5, 14, 0xFFFFFFFF); R(Rt - 18.5, y + 21, 3.5, 14, 0xFFFFFFFF);
  // Row 2: distance, speed, cash.
  const r2 = y + 64;
  glyph('route', L, r2, 0xFFFFFFFF); TXT(fmtDist(h.dist), L + 20, r2 + 1, 15, 0xFFFFFFFF);
  X.font = `900 15px ${FONT}`;
  const dw = X.measureText(fmtDist(h.dist)).width;
  glyph('speed', L + 20 + dw + 12, r2, 0xFF80D8FF); TXT(`${Math.round(h.kmh)} km/h`, L + 20 + dw + 32, r2 + 1, 15, 0xFF80D8FF);
  const cs = peso(h.cash);
  const cw = X.measureText(cs).width;
  TXT(cs, Rt - 4, r2 + 1, 15, YELLOW, { align: 'right' }); glyph('cash', Rt - 4 - cw - 22, r2, YELLOW);
  // Row 3: bike, difficulty, combo, world.
  const r3 = y + 86;
  glyph('bike', L, r3, MUTED); TXT(h.bike, L + 19, r3 + 0.5, 12, MUTED);
  X.font = `900 12px ${FONT}`;
  chip('MEDIUM', L + 19 + X.measureText(h.bike).width + 6, r3, YELLOW);
  const ew = chip(h.envName, Rt - 4, r3, h.envColor, true);
  if (h.combo >= 2) chip(`x${h.combo} COMBO`, Rt - 4 - ew - 6, r3, 0xFF80D8FF, true);
}

function drawChaseBanner(rem, t) {
  const red = Math.floor(rem * 2) % 2 === 0;
  const c = red ? 0xFFD50000 : 0xFF2962FF;
  X.save(); X.shadowColor = C(withA(c, 0.6)); X.shadowBlur = 14 * S;
  RR(10, 116, 390, 172, 12, withA(c, 0.88));
  X.restore();
  // Police badge icon.
  PG([30, 128, 40, 131, 40, 140, 30, 147, 20, 140, 20, 131], 0xFFFFFFFF);
  PG([30, 132, 36, 134, 36, 139, 30, 143, 24, 139, 24, 134], withA(c, 1));
  TXT("LTO CHASE! Don't crash!", 50, 138, 15, 0xFFFFFFFF);
  TXT(`${rem.toFixed(1)}s`, 378, 137, 22, 0xFFFFFFFF, { align: 'right' });
  RR(22, 156, 378, 162, 3, 0x3DFFFFFF);
  RR(22, 156, 22 + 356 * clamp(rem / 10, 0, 1), 162, 3, 0xFFFFFFFF);
}

function drawToast(text, color, age, y = 186, life = 1.6) {
  if (age < 0 || age > life) return;
  const a = Math.min(clamp(age / 0.22, 0, 1), clamp((life - age) / 0.25, 0, 1));
  X.save(); X.globalAlpha = a;
  X.font = `900 14px ${FONT}`;
  const w = X.measureText(text).width + 24;
  const yy = y - 10 * (1 - easeOut(age / 0.22));
  RR(200 - w / 2, yy - 14, 200 + w / 2, yy + 14, 10, 0xA6000000);
  TXT(text, 200, yy + 0.5, 14, color, { align: 'center' });
  X.restore();
}

function drawAnnouncement(title, sub, color, age, y = 120) {
  const life = 2.6;
  if (age < 0 || age > life) return;
  const v = age / life;
  const op = v < 0.08 ? v / 0.08 : v > 0.85 ? (1 - v) / 0.15 : 1;
  const slide = v < 0.08 ? (1 - v / 0.08) * -12 : 0;
  X.save(); X.globalAlpha = op; X.translate(0, slide);
  X.font = `900 15px ${FONT}`;
  const tw = X.measureText(title).width;
  X.font = `900 11px ${FONT}`;
  const sw = X.measureText(sub).width;
  const w = Math.max(tw, sw) + 24 + 24;
  RR(200 - w / 2, y, 200 + w / 2, y + 42, 10, 0xDD10141F);
  X.strokeStyle = C(color); X.lineWidth = 2; X.beginPath(); X.roundRect(200 - w / 2, y, w, 42, 10); X.stroke();
  const ix = 200 - w / 2 + 12;
  PG([ix + 8, y + 12, ix + 17, y + 29, ix - 1, y + 29], color);
  R(ix + 7, y + 17, 2, 6, 0xFF10141F); R(ix + 7, y + 25, 2, 2, 0xFF10141F);
  TXT(title, ix + 24, y + 14, 15, color);
  TXT(sub, ix + 24, y + 30, 11, 0xB3FFFFFF);
  X.restore();
}

function drawWorldBanner(title, sub, color, age, scale = 1.2) {
  const life = 2.8;
  if (age < 0 || age > life) return;
  const v = age / life;
  const op = v < 0.12 ? v / 0.12 : v > 0.8 ? (1 - v) / 0.2 : 1;
  X.font = `900 20px ${FONT}`; X.letterSpacing = '1px';
  const tw = X.measureText(title).width; X.letterSpacing = '0px';
  const w = Math.max(tw, 230) + 36;
  const sc = (v < 0.12 ? 0.8 + v / 0.12 * 0.2 : 1) * Math.min(scale, 376 / w);
  X.save(); X.globalAlpha = clamp(op, 0, 1);
  X.translate(200, 266); X.scale(sc, sc);
  RR(-w / 2, -30, w / 2, 30, 14, 0xDD10141F);
  X.strokeStyle = C(color); X.lineWidth = 2; X.beginPath(); X.roundRect(-w / 2, -30, w, 60, 14); X.stroke();
  TXT(title, 0, -8, 20, color, { align: 'center', ls: 1 });
  X.font = `400 13px 'Segoe UI',Arial`; X.textAlign = 'center'; X.fillStyle = C(0xB3FFFFFF); X.fillText(sub, 0, 15);
  X.restore();
}

function drawMeme(text, age, life = 1.7) {
  if (age < 0 || age > life) return;
  const pop = backOut(age / 0.28);
  const a = clamp((life - age) / 0.3, 0, 1);
  X.save(); X.globalAlpha = a;
  X.translate(200, 711 - 46); X.rotate(-0.05); X.scale(0.4 + 0.6 * pop, 0.4 + 0.6 * pop);
  X.font = `italic 900 22px ${FONT}`;
  const fit = Math.min(1, 228 / X.measureText(text).width);
  X.scale(fit, fit);
  TXT(text, 0, 0, 22, YELLOW, { align: 'center', italic: true, stroke: 6 });
  X.restore();
}

function drawSteerButtons() {
  for (const [cx, dir] of [[43, -1], [357, 1]]) {
    CI(cx, 662, 31, 0x59000000);
    X.strokeStyle = C(0x61FFFFFF); X.lineWidth = 2; X.beginPath(); X.arc(cx, 662, 30, 0, 7); X.stroke();
    LN(cx + 5 * dir, 650, cx - 7 * dir, 662, 0xB3FFFFFF, 5); LN(cx - 7 * dir, 662, cx + 5 * dir, 674, 0xB3FFFFFF, 5);
  }
}

// ================================================================ CAPTIONS
// Pixel-space trailer typography in the game's logo style.
function slam(text, t0, t1, t, o = {}) {
  if (t < t0 || t >= t1) return;
  const a = t - t0, b = t1 - t;
  const size = o.size || 140, y = o.y ?? 620, color = o.color ?? YELLOW, rot = o.rot ?? -0.05;
  const inD = 0.15;
  let sc = a < inD ? lerp(o.from || 1.9, 1, easeOut(a / inD)) : 1 + (a - inD) * 0.025;
  let alpha = clamp(a / 0.05, 0, 1);
  if (!o.hold && b < 0.12) { alpha *= b / 0.12; sc *= 1 + (0.12 - b) * 1.5; }
  const shake = a < 0.3 ? (1 - a / 0.3) * 16 : 0;
  X.save();
  X.setTransform(1, 0, 0, 1, 0, 0);
  X.globalAlpha = alpha;
  X.translate(W / 2 + (o.x || 0) + Math.sin(a * 97) * shake, y + Math.cos(a * 83) * shake);
  X.rotate(rot); X.scale(sc, sc);
  const lines = text.split('\n');
  X.font = `italic 900 ${size}px ${FONT}`;
  const mw = Math.max(...lines.map((l) => X.measureText(l).width));
  const fit = Math.min(1, (o.maxW || 980) / mw);
  X.scale(fit, fit);
  X.textAlign = 'center'; X.textBaseline = 'middle'; X.lineJoin = 'round';
  lines.forEach((l, i) => {
    const yy = (i - (lines.length - 1) / 2) * size * 0.95;
    X.fillStyle = 'rgba(0,0,0,0.45)'; X.fillText(l, 9, yy + 12);
    X.lineWidth = size * 0.17; X.strokeStyle = C(INK); X.strokeText(l, 0, yy);
    X.fillStyle = C(color); X.fillText(l, 0, yy);
  });
  X.restore();
}

function subline(text, t0, t1, t, o = {}) {
  if (t < t0 || t >= t1) return;
  const a = t - t0, b = t1 - t;
  const alpha = clamp(a / 0.15, 0, 1) * (o.hold ? 1 : clamp(b / 0.15, 0, 1));
  X.save(); X.setTransform(1, 0, 0, 1, 0, 0); X.globalAlpha = alpha;
  const y = (o.y ?? 760) + (1 - easeOut(a / 0.25)) * 20;
  TXT(text, W / 2 + (o.x || 0), y, o.size || 40, o.color ?? 0xFFFFFFFF, { align: 'center', ls: o.ls ?? 4, stroke: o.stroke ?? 10, strokeColor: 0xCC000000 });
  X.restore();
}

function screenOverlay(color) { X.save(); X.setTransform(1, 0, 0, 1, 0, 0); R(0, 0, W, H, color); X.restore(); }

function sirenWash(t, a) {
  X.save(); X.setTransform(1, 0, 0, 1, 0, 0);
  const red = Math.floor(t * 4) % 2 === 0;
  const g = X.createRadialGradient(red ? 0 : W, H, 0, red ? 0 : W, H, 1300);
  g.addColorStop(0, red ? `rgba(255,23,68,${0.35 * a})` : `rgba(41,121,255,${0.38 * a})`);
  g.addColorStop(1, 'rgba(0,0,0,0)');
  X.fillStyle = g; X.fillRect(0, 0, W, H);
  X.restore();
}

let _vig = null;
function vignette(strength = 1) {
  X.save(); X.setTransform(1, 0, 0, 1, 0, 0);
  if (!_vig) {
    _vig = X.createRadialGradient(W / 2, H / 2, 520, W / 2, H / 2, 1250);
    _vig.addColorStop(0, 'rgba(0,0,0,0)'); _vig.addColorStop(1, 'rgba(0,0,0,0.55)');
  }
  X.globalAlpha = strength; X.fillStyle = _vig; X.fillRect(0, 0, W, H);
  X.restore();
}

function shakeAt(t, times, amp = 10, dur = 0.3) {
  let sx = 0, sy = 0;
  for (const tt of times) {
    const d = t - tt;
    if (d >= 0 && d < dur) { const k = (1 - d / dur) * amp; sx += Math.sin(d * 90) * k; sy += Math.cos(d * 77) * k; }
  }
  return { sx, sy };
}

// ================================================================== SCENES
const SCENES = [];
function scene(t0, t1, draw) { SCENES.push({ t0, t1, draw }); FLASHES.push(t0); }

// ---------------------------------------------------------------- S0 COLD OPEN
scene(0, 1.6, (lt) => {
  R(0, 0, W, H, 0xFF05060A);
  sirenWash(lt, 0.9);
  subline('PAALALA:', 0.12, 1.6, lt, { y: 790, size: 50, ls: 16, color: 0xFFB0BEC5, hold: true });
  slam('HUWAG\nGAYAHIN.', 0.36, 1.6, lt, { y: 990, size: 170, color: 0xFFFFFFFF, hold: true, rot: -0.04 });
  subline("(Seriously. Don't ride like this.)", 0.8, 1.6, lt, { y: 1220, size: 38, ls: 1, color: 0xFFB0BEC5, hold: true });
});
FLASHES.length = 0; // no flash before the very first frame
cue(0.0, 'loop_engine', 0.55); cue(0.5, 'loop_engine', 0.65); cue(1.0, 'loop_engine', 0.75);
cue(0.05, 'loop_siren', 0.25); cue(0.36, 'boom', 0.9);

// ---------------------------------------------------------------- S1 CITY HOOK
{
  const T0 = 1.6, U = kmh2u(108), bike = BK('Kamote 110');
  const fx = laneTrack([[0, 2], [0.45, 3], [1.3, 2], [2.35, 3], [3.4, 2], [3.9, 1], [4.85, 2], [5.6, 3]]);
  const ents = [
    veh('car', 2, 0.95, U, { variant: 0 }),
    veh('taxi', 3, 1.75, U),
    veh('bus', 2, 2.9, U, { variant: 0 }),
    veh('van', 3, 3.95, U, { variant: 1 }),
    veh('car', 3, 5.0, U, { variant: 5 }),
    veh('truck', 2, 6.35, U, { variant: 2 }),
    veh('bus', 0, 1.0, U, { down: true, variant: 2 }),
    veh('car', 1, 1.9, U, { down: true, variant: 2 }),
    veh('taxi', 0, 2.6, U, { down: true }),
    veh('van', 1, 3.2, U, { down: true, variant: 3 }),
    veh('car', 0, 4.3, U, { down: true, variant: 6 }),
    veh('car', 1, 5.2, U, { down: true, variant: 1, beamStrong: true }),
    veh('van', 0, 5.9, U, { down: true, variant: 7 }),
    cash(3, 0.7, 50, U), cash(2, 1.55, 20, U), cash(3, 2.7, 100, U),
    cash(1, 4.15, 50, U), cash(1, 4.35, 100, U), cash(1, 4.55, 50, U),
    { k: 'flyover', ta: 1.3, rel: U },
    { k: 'warn', lane: 1, t0: 3.6, t1: 4.3 },
  ];
  markCollected(ents, fx);
  const pickups = ents.filter((e) => e.k === 'cash' && e.got);
  for (const p of pickups) cue(T0 + p.ta, 'sfx_cash', 0.7);
  for (const tt of [0.95, 2.9, 5.2]) cue(T0 + tt - 0.1, 'sfx_whoosh', 0.8);
  cue(T0 + 5.25, 'meme_uhoh', 0.9);
  for (const tt of [1.6, 3.2, 4.8]) cue(T0 + tt, 'boom', 0.7);

  scene(T0, 8.0, (lt) => {
    const t = lt;
    const r = easeOut(t / 0.9);
    const sh = shakeAt(t, [5.2], 14);
    const cam = { z: lerp(1.5, 1, r), fx: lerp(fx(t), 200, r), fy: lerp(PY - 30, VH / 2, r), sx: sh.sx, sy: sh.sy };
    drawWorld({
      t, scroll: 5000 + U * t, env: 0, ents, atmo: 0, speedU: U, lines: 0.5, cam,
      player: { bike, x: fx(t), rot: leanOf(fx, t) },
    });
    vignette(0.8);
    const got = pickups.filter((p) => p.ta <= t).reduce((s, p) => s + p.value, 0);
    hud(() => {
      drawTopBar({ t, fuel: 0.74 - 0.004 * t, low: false, dist: 620 + 30 * t, kmh: 108, cash: 1180 + got + (t > 5.25 ? 10 : 0),
        bike: bike.name, envName: 'City Highway', envColor: ENVS[0].accent, combo: t > 5.25 ? 2 : 0 });
      drawToast('NEAR MISS +₱10', 0xFF80D8FF, t - 5.25, 130);
      drawMeme('AY, NAKO!', t - 5.25);
      drawSteerButtons();
    });
    slam('4 LANES.', 1.6, 3.1, t, { y: 560 });
    slam('2 ARE\nONCOMING.', 3.2, 4.75, t, { y: 600, size: 130 });
    slam('ZERO CHILL.', 4.8, 6.4, t, { y: 600, size: 150, color: 0xFFFF5252 });
  });
}

// ---------------------------------------------------------------- S2 LTO CHASE
{
  const T0 = 8.0, U = kmh2u(112), bike = BK('Kamote 110');
  const fx = laneTrack([[0, 3], [1.6, 2], [2.7, 3], [3.5, 2], [4.4, 3]]);
  const remAt = (t) => clamp(10 - (t - 1.0) * (10 / 4.4), 0, 10);
  const ents = [
    { k: 'checkpoint', ta: 0.9, rel: U },
    veh('jeepney', 3, 2.2, U, { variant: 1 }),
    veh('car', 2, 3.2, U, { variant: 3 }),
    obst('cone', 3, 3.95, U), obst('cone', 3, 4.08, U),
    obst('barrier', 2, 4.85, U),
    veh('taxi', 1, 1.4, U, { down: true }),
    veh('bus', 0, 2.5, U, { down: true, variant: 1 }),
    veh('car', 1, 3.6, U, { down: true, variant: 4 }),
    veh('van', 0, 4.6, U, { down: true, variant: 2 }),
    veh('car', 1, 5.7, U, { down: true, variant: 0 }),
    cash(2, 2.0, 50, U), cash(3, 3.3, 20, U), cash(2, 4.2, 100, U),
  ];
  markCollected(ents, fx);
  // Officer pursuit, simulated like LtoOfficer.update.
  const off = [];
  {
    let ox = fx(1.0), oy = VH + 60, mode = 'entering';
    for (let i = 0; i <= 6.4 * 240; i++) {
      const t = i / 240, dt = 1 / 240;
      if (t >= 1.0) {
        if (t < 5.4) {
          const progress = 1 - remAt(t) / 10;
          const ty = PY + 92 + progress * 40 + Math.sin(t * 3) * 6;
          oy += (ty - oy) * Math.min(1, dt * (mode === 'entering' ? 3.5 : 5));
          ox += (fx(t) - ox) * Math.min(1, dt * 3.2);
          if (mode === 'entering' && Math.abs(oy - ty) < 6) mode = 'chasing';
        } else oy += 260 * dt;
      }
      off.push([ox, oy]);
    }
  }
  const offAt = (t) => off[clamp(Math.round(t * 240), 0, off.length - 1)];
  ents.push({ k: 'float', text: 'HOY! TABI!', t0: 1.7, x: (t) => offAt(t)[0], y: (t) => offAt(t)[1] + 30, color: 0xFF82B1FF, size: 15 });
  ents.push({ k: 'float', text: 'LISENSYA MO!', t0: 3.6, x: (t) => offAt(t)[0], y: (t) => offAt(t)[1] + 30, color: 0xFF82B1FF, size: 15 });
  const pickups = ents.filter((e) => e.k === 'cash' && e.got);
  for (const p of pickups) cue(T0 + p.ta, 'sfx_cash', 0.7);
  cue(T0 + 0.95, 'sfx_whistle', 1.0); cue(T0 + 1.05, 'meme_airhorn', 0.7);
  for (let s = 1.0; s < 5.4; s += 1.2) cue(T0 + s, 'loop_siren', 0.5);
  cue(T0 + 5.4, 'sfx_mission', 0.9); cue(T0 + 5.5, 'meme_tada', 0.6);
  cue(T0 + 1.2, 'boom', 0.7); cue(T0 + 3.0, 'boom', 0.7);

  scene(T0, 14.4, (t) => {
    const o = offAt(t);
    drawWorld({
      t, scroll: 9000 + U * t, env: 0, ents, atmo: 0, speedU: U, lines: 0.6,
      cam: { z: 1, fy: VH / 2 + 40 },
      player: { bike, x: fx(t), rot: leanOf(fx, t) },
      officer: t >= 1.0 && o[1] < VH + 120 ? { x: o[0], y: o[1] } : null,
    });
    if (t > 1.0 && t < 5.6) sirenWash(t, 0.55 * clamp((t - 1.0) / 0.3, 0, 1) * clamp((5.6 - t) / 0.3, 0, 1));
    vignette(0.8);
    const got = pickups.filter((p) => p.ta <= t).reduce((s, p) => s + p.value, 0);
    hud(() => {
      X.translate(0, 0);
      drawTopBar({ t, fuel: 0.66 - 0.004 * t, low: false, dist: 1410 + 31 * t, kmh: 112, cash: 1550 + got + (t > 5.4 ? 75 : 0),
        bike: bike.name, envName: 'City Highway', envColor: ENVS[0].accent, combo: 0 });
      if (t > 1.0 && t < 5.4) drawChaseBanner(remAt(t), t);
      drawToast('ESCAPED! +₱75', 0xFF69F0AE, t - 5.4, 130);
      drawMeme('LAGOT KA, BOSS!', t - 1.05);
      drawMeme('NICE ONE, IDOL!', t - 5.5);
      drawSteerButtons();
    });
    slam('THE LTO\nSAW THAT.', 1.2, 2.95, t, { y: 660, size: 140, color: 0xFF82B1FF });
    slam('SURVIVE\n10 SECONDS.', 3.0, 4.8, t, { y: 660, size: 140 });
  });
}

// ---------------------------------------------------------------- S3 HEAD-ON SLOW-MO
{
  const T0 = 14.4, U = kmh2u(108), bike = BK('Kamote 110');
  // Real time -> game time with a smooth slow-motion window.
  const rate = (lt) => {
    if (lt < 1.4) return 1;
    if (lt < 1.55) return lerp(1, 0.2, ease((lt - 1.4) / 0.15));
    if (lt < 3.2) return 0.2;
    if (lt < 3.35) return lerp(0.2, 1, ease((lt - 3.2) / 0.15));
    return 1;
  };
  const G = [0];
  for (let i = 1; i <= 4.8 * 1000; i++) G.push(G[i - 1] + rate((i - 0.5) / 1000) / 1000);
  const g = (lt) => G[clamp(Math.round(lt * 1000), 0, G.length - 1)];
  const realOf = (gt) => { let i = 0; while (i < G.length - 1 && G[i] < gt) i++; return i / 1000; };

  const fx = laneTrack([[0, 2], [0.45, 1], [1.5, 2]]);
  const ents = [
    fuelCan(1, 1.0, U),
    veh('jeepney', 1, 1.82, U, { down: true, variant: 1, beamStrong: true }),
    veh('tricycle', 3, 1.2, U, { variant: 0, signal: -1 }),
    veh('jeepney', 3, 2.9, U, { variant: 2 }),
    veh('car', 0, 0.9, U, { down: true, variant: 4 }),
    veh('truck', 0, 2.6, U, { down: true, variant: 1 }),
    { k: 'warn', lane: 1, t0: 0.3, t1: 0.95 },
  ];
  markCollected(ents, fx);
  cue(T0 + realOf(1.0), 'sfx_fuel', 0.9);
  cue(T0 + 1.42, 'meme_airhorn', 1.0); cue(T0 + 1.5, 'sfx_brake', 0.5);
  cue(T0 + 1.55, 'boom', 1.0); cue(T0 + 2.2, 'boom', 0.8);
  CUES.push({ t: T0 + 1.45, name: '_slowmo', vol: 1, dur: 1.95 });
  cue(T0 + 3.25, 'sfx_whoosh', 1.0); cue(T0 + 3.4, 'meme_uhoh', 0.9);

  scene(T0, 19.2, (lt) => {
    const t = g(lt);
    const k = clamp((1 - rate(lt)) / 0.8, 0, 1);
    const px = fx(t);
    const cam = { z: 1 + 0.55 * k, fx: lerp(200, px - 14, k), fy: lerp(VH / 2, PY - 80, k), rot: -0.06 * k };
    drawWorld({
      t, scroll: 15000 + U * t, env: 1, ents, atmo: 1, speedU: U, lines: 0.5 * (1 - k), cam,
      player: { bike, x: px, rot: leanOf(fx, t) * 1.3 },
    });
    if (k > 0) screenOverlay(withA(0xFF0A1428, 0.3 * k));
    vignette(0.8 + 0.6 * k);
    hud(() => {
      if (k < 0.5) drawToast('+28% FUEL', 0xFFFFEB3B, lt - realOf(1.0), 40, 1.0);
      drawToast('NEAR MISS +₱10', 0xFF80D8FF, lt - 3.4, 40);
      drawMeme('MUNTIK NA, IDOL!', lt - 3.4);
    });
    slam('HEAD-ON?', 1.55, 3.25, lt, { y: 470, size: 150, color: 0xFFFFFFFF });
    slam('= GAME OVER.', 2.2, 3.25, lt, { y: 640, size: 130, color: 0xFFFF5252 });
    slam('NOPE.', 3.35, 4.8, lt, { y: 560, size: 190 });
  });
}

// ---------------------------------------------------------------- S4 ANIMALS
{
  const T0 = 19.2, U = kmh2u(100), bike = BK('Kamote 110');
  const fx = laneTrack([[0, 2], [2.4, 3], [3.45, 2]]);
  const ents = [
    animal('dog', 372, 1.65, 150, U, [[0.6, 0, true], [Infinity, -150]], 0),
    animal('cat', 20, 2.9, 150, U, [[Infinity, 190]], 1),
    animal('chicken', 380, 4.0, 150, U, [[0.8, -85], [0.3, 0, true], [Infinity, -110]]),
    veh('truck', 0, 1.0, U, { down: true, variant: 0 }),
    veh('car', 1, 3.6, U, { down: true, variant: 2 }),
    cash(2, 1.2, 20, U), cash(3, 3.0, 50, U),
  ];
  markCollected(ents, fx);
  for (const p of ents.filter((e) => e.k === 'cash' && e.got)) cue(T0 + p.ta, 'sfx_cash', 0.6);
  cue(T0 + 0.7, 'meme_woof', 1.0); cue(T0 + 1.25, 'meme_woof', 0.8);
  cue(T0 + 1.95, 'meme_meow', 1.0); cue(T0 + 3.0, 'meme_cluck', 1.0); cue(T0 + 3.6, 'meme_cluck', 0.8);
  cue(T0 + 0.15, 'sfx_challenge', 0.8);
  for (const tt of [0.65, 1.9, 3.0]) cue(T0 + tt, 'boom', 0.7);

  scene(T0, 24.0, (t) => {
    drawWorld({
      t, scroll: 20000 + U * t, env: 2, ents, atmo: 2, speedU: U, lines: 0.3,
      cam: { z: 1.04, fy: VH / 2 + 15 },
      player: { bike, x: fx(t), rot: leanOf(fx, t) },
    });
    vignette(0.8);
    hud(() => {
      drawAnnouncement('ANIMAL CROSSING!', 'Dogs, cats & chickens ahead', 0xFFFFCA28, t - 0.15, 14);
      drawMeme('GOOD BOY, GOOD SAVE!', t - 1.75, 1.15);
      drawMeme('PUSA SA GITNA!', t - 2.95, 1.05);
      drawMeme('BAKIT TUMAWID ANG MANOK?', t - 4.05);
      drawSteerButtons();
    });
    slam('ASO.', 0.65, 4.8, t, { y: 330, size: 100, x: -345, rot: -0.07, maxW: 300 });
    slam('PUSA.', 1.9, 4.8, t, { y: 330, size: 100, x: -15, rot: -0.03, maxW: 300 });
    slam('MANOK.', 3.0, 4.8, t, { y: 330, size: 100, x: 330, rot: -0.07, color: 0xFFFF5252, maxW: 330 });
    subline('DOGS', 0.75, 4.8, t, { y: 430, size: 30, x: -345 });
    subline('CATS', 2.0, 4.8, t, { y: 430, size: 30, x: -15 });
    subline('CHICKENS', 3.1, 4.8, t, { y: 430, size: 30, x: 330 });
  });
}

// ---------------------------------------------------------------- S5 FIVE WORLDS
{
  const T0 = 24.0;
  const shots = [
    { env: 0, s0: 0.0, s1: 1.2, kmh: 110, bike: 'Kamote 110', lane: 3, cam: { z: 0.78, fy: VH / 2 - 10 },
      ents: (U) => [{ k: 'flyover', ta: 0.75, rel: U }, veh('bus', 2, 1.6, U), veh('taxi', 0, 0.5, U, { down: true }), veh('car', 1, 1.05, U, { down: true, variant: 6 }), veh('car', 3, 2.3, U, { variant: 1 })] },
    { env: 1, s0: 1.2, s1: 2.4, kmh: 95, bike: 'Tricycle Escape', lane: 2, cam: { z: 1.12, fx: 215, rot: 0.035 },
      ents: (U) => [veh('jeepney', 3, 1.0, U, { variant: 2 }), veh('jeepney', 1, 0.7, U, { down: true, variant: 1 }), veh('tricycle', 0, 1.15, U, { down: true, variant: 2 }), cash(2, 0.6, 50, U)] },
    { env: 2, s0: 2.4, s1: 3.6, kmh: 104, bike: 'Mountain Stalker', lane: 2, cam: { z: 0.9, fy: VH / 2 + 10, rot: -0.02 },
      ents: (U) => [veh('truck', 3, 0.95, U, { variant: 2 }), veh('truck', 1, 0.55, U, { down: true }), veh('car', 0, 1.1, U, { down: true, variant: 3 }), obst('pothole', 2, 1.6, U)] },
    { env: 3, s0: 3.6, s1: 4.8, kmh: 120, bike: 'Highway King 400', lane: 3, cam: { z: 1.0, rot: -0.03 },
      ents: (U) => [veh('van', 2, 1.0, U, { variant: 2 }), veh('bus', 0, 0.75, U, { down: true, variant: 2 }), veh('car', 1, 1.15, U, { down: true, variant: 5 }), cash(3, 0.55, 100, U)] },
    { env: 4, s0: 4.8, s1: 6.4, kmh: 116, bike: 'Asphalt Phantom', lane: 3, cam: { z: 1.15, fy: VH / 2 + 20 },
      ents: (U) => [veh('jeepney', 2, 1.1, U, { variant: 0 }), veh('taxi', 1, 0.6, U, { down: true }), veh('jeepney', 0, 1.35, U, { down: true, variant: 2 }), veh('taxi', 2, 2.4, U)] },
  ];
  for (const s of shots) {
    s.U = kmh2u(s.kmh); s.e = s.ents(s.U);
    const fx = () => laneX(s.lane);
    markCollected(s.e, fx);
    for (const p of s.e.filter((e) => e.k === 'cash' && e.got)) cue(T0 + s.s0 + p.ta, 'sfx_cash', 0.6);
    cue(T0 + s.s0, 'sfx_whoosh', 0.9); cue(T0 + s.s0 + 0.05, 'sfx_kilometer', 0.8);
    if (s.s0 > 0) FLASHES.push(T0 + s.s0);
  }
  cue(T0, 'boom', 1.0);

  scene(T0, 30.4, (lt) => {
    const s = shots.find((sh) => lt >= sh.s0 && lt < sh.s1);
    const t = lt - s.s0;
    const b = BK(s.bike);
    const push = 1 + 0.04 * t;
    const cam = Object.assign({}, s.cam, { z: s.cam.z * push });
    drawWorld({
      t, scroll: 30000 + s.env * 5000 + s.U * t, env: s.env, ents: s.e, atmo: s.env, speedU: s.U, lines: 0.5, cam,
      player: { bike: b, x: laneX(s.lane) + Math.sin(t * 3) * 3, rot: Math.cos(t * 3) * 0.03 },
    });
    vignette(0.9);
    const i = shots.indexOf(s);
    const env = ENVS[s.env];
    hud(() => drawWorldBanner(`WORLD ${i + 1}: ${env.name.toUpperCase()}`, env.tagline, env.accent, t + 0.25, 1.25));
    slam('5 WORLDS.', 0, 6.4, lt, { y: 330, size: 150, hold: true });
    subline(`${i + 1} / 5`, 0.15, 6.4, lt, { y: 450, size: 40, ls: 10, hold: true });
  });
}

// ---------------------------------------------------------------- S6 CASH RUSH
{
  const T0 = 30.4, U = kmh2u(135), bike = BK('Midnight Racer');
  const P = [2, 2, 3, 3, 3, 2, 2, 1, 1, 2, 3, 3];
  const V = [20, 50, 100, 20, 50, 100, 20, 50, 100, 50, 100, 100];
  const keys = [[0, 2]];
  const bills = P.map((lane, i) => {
    const ta = 0.8 + 0.2 * i;
    if (i > 0 && lane !== P[i - 1]) keys.push([ta - 0.15, lane]);
    return cash(lane, ta, V[i], U);
  });
  keys.push([3.9, 2]);
  const fx = laneTrack(keys, 0.12);
  const ents = [
    ...bills,
    veh('bus', 0, 1.0, U, { down: true, variant: 0 }),
    veh('car', 0, 2.4, U, { down: true, variant: 2 }),
    veh('car', 3, 4.3, U, { variant: 6 }),
  ];
  markCollected(ents, fx);
  for (const b of bills) cue(T0 + b.ta, 'sfx_cash', 0.75);
  cue(T0 + 0.1, 'sfx_challenge', 0.8); cue(T0 + 3.15, 'sfx_mission', 0.9); cue(T0 + 3.2, 'meme_tada', 0.8);
  cue(T0 + 3.25, 'boom', 1.0);

  scene(T0, 35.2, (t) => {
    drawWorld({
      t, scroll: 60000 + U * t, env: 3, ents, atmo: 3, speedU: U, lines: 1,
      cam: { z: 1.04, rot: Math.sin(t * 1.6) * 0.012 },
      player: { bike, x: fx(t), rot: leanOf(fx, t) * 0.8 },
    });
    vignette(0.85);
    const n = bills.filter((b) => b.got && b.ta <= t).length;
    const got = bills.filter((b) => b.got && b.ta <= t).reduce((s, b) => s + b.value, 0);
    hud(() => {
      drawTopBar({ t, fuel: 0.58 - 0.004 * t, low: false, dist: 3380 + 37 * t, kmh: 135, cash: 2140 + got + (t > 3.15 ? 80 : 0),
        bike: bike.name, envName: 'Coastal Highway', envColor: ENVS[3].accent, combo: Math.min(5, 1 + Math.floor(n / 2)) });
      drawAnnouncement('CASH RUSH!', 'Collect every bill', YELLOW, t - 0.1, 116);
      drawToast('CASH RUSH CLEAR! +₱80', YELLOW, t - 3.15, 130);
      drawMeme('YAMAN MO NA!', t - 3.2);
      drawSteerButtons();
    });
    slam('COMBO x5!', 3.25, 4.8, t, { y: 640, size: 170, color: 0xFF80D8FF });
  });
}

// ---------------------------------------------------------------- S7 GARAGE
{
  const T0 = 35.2;
  const hero = [0, 2, 3, 7, 8, 11, 12, 14].map((i) => BIKES[i]);
  for (let i = 0; i < 8; i++) cue(T0 + i * 0.4, 'sfx_click', 0.9);
  cue(T0 + 3.2, 'sfx_unlock', 1.0); cue(T0 + 3.2, 'boom', 1.0);
  FLASHES.push(T0 + 3.2);

  function backdrop(lt, glow) {
    R(0, 0, W, H, 0xFF141824);
    X.save();
    for (let i = -6; i < 16; i++) {
      const x = i * 160 + (lt * 120) % 160;
      PG([x, 0, x + 70, 0, x + 70 - 600, H, x - 600, H], 0x0AFFFFFF);
    }
    if (glow !== undefined) {
      const g = X.createRadialGradient(540, 860, 0, 540, 860, 700);
      g.addColorStop(0, C(withA(glow, 0.45))); g.addColorStop(1, 'rgba(0,0,0,0)');
      X.fillStyle = g; X.fillRect(0, 0, W, H);
    }
    X.restore();
  }

  function bikeArt(b, cx, top, scale) {
    // Centre the bike body; sidecar/tricycle cabs extend to the right.
    const extra = b.style === 'tricycle' ? 24 : b.style === 'sidecar' ? 19 : 0;
    drawBike(b, cx - extra * scale / 2, top + 40 * scale, 40 * scale, 80 * scale, { anim: 0 });
  }

  function statBar(label, v, max, y, color) {
    TXT(label, 190, y, 30, MUTED, { ls: 3 });
    RR(420, y - 11, 900, y + 11, 11, 0xFF2A3247);
    RR(420, y - 11, 420 + 480 * (v / max), y + 11, 11, color);
  }

  scene(T0, 40.0, (lt) => {
    if (lt < 3.2) {
      const i = Math.floor(lt / 0.4), a = lt - i * 0.4, b = hero[i];
      const rar = RARITY[b.tier];
      backdrop(lt, b.body);
      TXT('GARAGE', 540, 230, 64, 0xFFFFFFFF, { align: 'center', ls: 18 });
      TXT('Earn pesos. Bail out your rides.', 540, 305, 34, MUTED, { align: 'center' });
      const dx = (1 - easeOut(a / 0.16)) * 900;
      X.save(); X.translate(dx, 0);
      X.save(); X.shadowColor = C(withA(rar[1], 0.7)); X.shadowBlur = 50;
      RR(110, 420, 970, 1640, 44, 0xFF1F2536);
      X.restore();
      X.strokeStyle = C(rar[1]); X.lineWidth = 6; X.beginPath(); X.roundRect(110, 420, 860, 1220, 44); X.stroke();
      const sp = 1 + 0.03 * Math.sin(lt * 8);
      bikeArt(b, 540, 455, 6.4 * sp);
      TXT(b.name.toUpperCase(), 540, 1040, 76, 0xFFFFFFFF, { align: 'center', italic: true });
      X.font = `900 30px ${FONT}`; X.letterSpacing = '4px';
      const rw = X.measureText(rar[0]).width + 40; X.letterSpacing = '0px';
      RR(540 - rw / 2, 1088, 540 + rw / 2, 1140, 14, withA(rar[1], 0.25));
      TXT(rar[0], 540, 1115, 30, rar[1], { align: 'center', ls: 4 });
      statBar('SPEED', b.spd, 15, 1225, 0xFFFF7043);
      statBar('HANDLING', b.hnd, 10, 1300, 0xFF42A5F5);
      statBar('FUEL EFF.', b.fuel, 10, 1375, 0xFF66BB6A);
      TXT(b.price ? peso(b.price) : 'FREE', 540, 1520, 84, YELLOW, { align: 'center', italic: true, stroke: 14, strokeColor: INK });
      X.restore();
    } else {
      const s = lt - 3.2;
      backdrop(lt);
      const cw = 300, ch = 236, gap = 18, x0 = (W - 3 * cw - 2 * gap) / 2, y0 = 560;
      BIKES.forEach((b, i) => {
        const appear = s - i * 0.035;
        if (appear < 0) return;
        const sc = backOut(appear / 0.22);
        const col = i % 3, row = Math.floor(i / 3);
        const cx = x0 + col * (cw + gap) + cw / 2, cy = y0 + row * (ch + gap) + ch / 2;
        const rar = RARITY[b.tier];
        X.save(); X.translate(cx, cy); X.scale(sc, sc);
        RR(-cw / 2, -ch / 2, cw / 2, ch / 2, 22, 0xFF1F2536);
        X.strokeStyle = C(rar[1]); X.lineWidth = 4; X.beginPath(); X.roundRect(-cw / 2, -ch / 2, cw, ch, 22); X.stroke();
        bikeArt(b, 0, -ch / 2 + 12, 1.65);
        TXT(b.name, 0, ch / 2 - 52, 24, 0xFFFFFFFF, { align: 'center' });
        TXT(b.price ? peso(b.price) : 'FREE', 0, ch / 2 - 22, 24, YELLOW, { align: 'center' });
        X.restore();
      });
      slam('15 IMPOUNDED\nBIKES.', 0, 1.6, s, { y: 330, size: 130, hold: true });
    }
    vignette(0.7);
  });
}

// ---------------------------------------------------------------- S8 ENDINGS
{
  const T0 = 40.0, bike = BK('Kamote 110');
  FLASHES.push(T0 + 1.6, T0 + 3.2);
  cue(T0, 'sfx_brake', 0.8); cue(T0 + 0.05, 'sfx_whistle', 1.0); cue(T0 + 0.55, 'sfx_impact', 1.0); cue(T0 + 0.75, 'sfx_bump', 0.8);
  cue(T0 + 1.6, 'sfx_crash', 1.0); cue(T0 + 1.75, 'loop_ambulance', 0.7); cue(T0 + 2.75, 'loop_ambulance', 0.5);
  cue(T0 + 3.2, 'sfx_sputter', 1.0); cue(T0 + 3.9, 'meme_wahwah', 0.8); cue(T0 + 4.0, 'sfx_game_over', 0.5);
  for (const tt of [0, 1.6, 3.2]) cue(T0 + tt, 'boom', 0.9);
  const U = kmh2u(108);

  function jailBars(s) {
    const drop = easeOut(s / 0.22);
    const off = (1 - drop) * -VH;
    X.save(); X.translate(0, off);
    R(0, 0, 400, VH, 0x55000000);
    const n = 11;
    for (let i = 0; i < n; i++) { const x = (i + 0.5) * 400 / n; R(x - 4, 0, 8, VH, 0xFF263238); R(x - 3, 0, 2, VH, 0x55FFFFFF); }
    R(0, VH * 0.15, 400, 8, 0xFF263238); R(0, VH * 0.85, 400, 8, 0xFF263238);
    X.font = `900 14px ${FONT}`; X.letterSpacing = '2px';
    const sw = X.measureText('HOLDING CELL').width + 16; X.letterSpacing = '0px';
    R(200 - sw / 2, VH * 0.15 - 14, sw, 24, 0xFF1A237E);
    TXT('HOLDING CELL', 200, VH * 0.15 - 1.5, 14, 0xFFFFFFFF, { align: 'center', ls: 2 });
    X.restore();
  }
  function ticket(s) {
    if (s < 0) return;
    const k = easeOut(s / 0.3);
    X.save(); X.translate(200, 500 + (1 - k) * 300); X.rotate(0.07 * k - 0.2 * (1 - k));
    R(-128, -66, 256, 150, 0x55000000);
    RR(-130, -72, 126, 76, 6, 0xFFFFF8E1);
    TXT('TRAFFIC VIOLATION TICKET', -2, -52, 12, 0xFFB71C1C, { align: 'center' });
    X.font = `400 8px 'Segoe UI',Arial`; X.textAlign = 'center'; X.fillStyle = C(0x8A000000); X.fillText('Fictional Land Transport Office', -2, -36);
    R(-114, -26, 224, 1, 0x33000000);
    TXT('VIOLATION: Kamote driving', -112, -12, 11, 0xFF263238);
    TXT('2nd offense during chase', -112, 4, 11, 0xFF263238);
    TXT('PENALTY: Holding cell', -112, 22, 11, 0xFFB71C1C);
    X.save(); X.translate(64, 46); X.rotate(-0.25);
    X.strokeStyle = C(0xCCD50000); X.lineWidth = 2.5; X.strokeRect(-40, -12, 80, 24);
    TXT('HULI KA!', 0, 1, 13, 0xCCD50000, { align: 'center' });
    X.restore();
    X.restore();
  }

  scene(T0, 44.8, (lt) => {
    if (lt < 1.6) {
      const s = lt;
      const sp = s < 0.6 ? U * (s - s * s / 1.2) : U * 0.3;
      const ox = lerp(laneX(2), laneX(2) - 30, easeOut(s / 0.5)), oy = lerp(PY + 110, PY + 10, easeOut(s / 0.5));
      const sh = shakeAt(s, [0.55], 12);
      drawWorld({ t: s, scroll: 70000 + sp, env: 0, atmo: 0, cam: { sx: sh.sx, sy: sh.sy },
        player: { bike, x: laneX(2), braking: true, anim: 0 }, officer: { x: ox, y: oy } });
      hud(() => { if (s > 0.5) jailBars(s - 0.55); ticket(s - 0.75); });
      vignette(1);
      slam('1. TICKETED\n& JAILED!', 0.0, 1.6, s, { y: 560, size: 120, color: 0xFF82B1FF, hold: true });
    } else if (lt < 3.2) {
      const s = lt - 1.6;
      const ay = lerp(-120, PY - 150, easeOut(s / 0.7));
      const sh = shakeAt(s, [0], 22, 0.4);
      const bx = laneX(1) + 4;
      drawWorld({ t: s, scroll: 80000, env: 1, atmo: 1, cam: { z: 1.12, fy: PY - 140, sx: sh.sx, sy: sh.sy },
        ents: [{ k: 'veh', type: 'ambulance', lane: 1, yf: () => ay, color: 0xFFFAFAFA, down: true }],
        player: { bike, x: bx, rot: 1.45, anim: 0 },
        extraWorld: () => {
          for (let i = 0; i < 4; i++) {
            const a = s * 5 + i * Math.PI / 2;
            const x = bx + Math.cos(a) * 20, y = PY - 18 + Math.sin(a) * 7;
            TXT('★', x, y, 11, 0xFFFFEB3B, { align: 'center', stroke: 2.5 });
          }
        } });
      screenOverlay(withA(0xFF200D12, 0.35));
      sirenWash(s, 0.8);
      vignette(1);
      hud(() => drawMeme('KAMOTE MOMENT!', s - 0.45));
      slam('2. HEAD-ON\nCRASH!', 0.0, 1.6, s, { y: 560, size: 120, color: 0xFFFF5252, hold: true });
      subline("Rider's okay. Pride? Not so much.", 0.35, 1.6, s, { y: 1180, size: 38, ls: 1, hold: true });
    } else {
      const s = lt - 3.2, v0 = kmh2u(98), dec = 1.1;
      const sc = s < dec ? v0 * (s - s * s / (2 * dec)) : v0 * dec / 2;
      const spd = Math.max(0, v0 * (1 - s / dec));
      const px = laneX(3) + Math.sin(s * 40) * 2.2 * clamp(1 - s / 1.2, 0, 1);
      const smoke = [];
      for (let i = 0; i < 9; i++) {
        const born = i * 0.12, a = (s - born) / 0.9;
        if (a < 0 || a > 1) continue;
        smoke.push({ x: px + 9 + Math.sin(i * 2.3) * 6 * a, y: PY + 30 + 60 * a, r: 4 + 14 * a, a: 0.55 * (1 - a) });
      }
      drawWorld({ t: s, scroll: 90000 + sc, env: 2, atmo: 2, speedU: spd, cam: { z: 1.05 }, smoke,
        player: { bike, x: px, anim: s < dec ? s : dec } });
      vignette(1);
      hud(() => {
        drawTopBar({ t: s, fuel: 0, low: true, dist: 4870, kmh: spd / kmh2u(1), cash: 3460, bike: bike.name,
          envName: 'Mountain Road', envColor: ENVS[2].accent, combo: 0 });
        drawMeme('SANA ALL MAY GASOLINA!', s - 0.5);
      });
      slam('3. OUT OF\nFUEL!', 0.0, 1.6, s, { y: 620, size: 120, color: 0xFFFFCA28, hold: true });
    }
    slam('3 WAYS TO LOSE:', 0, 4.8, lt, { y: 350, size: 90, color: 0xFFFFFFFF, hold: true, rot: -0.03 });
  });
}

// ---------------------------------------------------------------- S9 TITLE
{
  const T0 = 44.8, U = kmh2u(120), bike = BK('Kamote 110');
  cue(T0, 'boom', 1.2); cue(T0, 'meme_airhorn', 0.9); cue(T0, 'sfx_impact', 1.0);
  cue(T0 + 0.4, 'sfx_whoosh', 0.9); cue(T0 + 0.1, 'loop_siren', 0.35); cue(T0 + 1.3, 'loop_siren', 0.3); cue(T0 + 2.5, 'loop_siren', 0.2);
  for (const tt of [1.6, 2.0, 2.4]) cue(T0 + tt, 'boom', 0.8);
  cue(T0 + 3.2, 'meme_tada', 0.9);
  const fx = laneTrack([[0, 2], [0.9, 3], [1.9, 2], [2.7, 3]], 0.25);
  const yOf = (t) => lerp(VH + 90, -160, clamp((t - 0.15) / 3.4, 0, 1));
  const traffic = [veh('car', 2, 1.4, U, { variant: 1 }), veh('jeepney', 3, 2.3, U, { variant: 0 }), veh('taxi', 1, 0.8, U, { down: true }), veh('bus', 0, 2.0, U, { down: true })];

  scene(T0, DUR, (t) => {
    const sh = shakeAt(t, [0], 26, 0.45);
    const py = yOf(t);
    drawWorld({
      t, scroll: 100000 + U * t, env: 4, ents: traffic, atmo: 4, speedU: U, lines: 1,
      cam: { z: 1.0, sx: sh.sx, sy: sh.sy },
      player: { bike, x: fx(t), y: py, rot: leanOf(fx, t), beam: true },
      officer: { x: fx(t - 0.35), y: py + 120 },
    });
    // Darken for the logo, with the officer's lights bleeding through.
    X.save(); X.setTransform(1, 0, 0, 1, 0, 0);
    const g = X.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, 'rgba(8,10,18,0.82)'); g.addColorStop(0.5, 'rgba(8,10,18,0.55)'); g.addColorStop(1, 'rgba(8,10,18,0.85)');
    X.fillStyle = g; X.fillRect(0, 0, W, H);
    const glow = X.createRadialGradient(540, 760, 0, 540, 760, 620);
    glow.addColorStop(0, 'rgba(255,196,0,0.22)'); glow.addColorStop(1, 'rgba(255,196,0,0)');
    X.fillStyle = glow; X.fillRect(0, 0, W, H);
    X.restore();
    sirenWash(t, 0.5);

    // Logo: KAMOTE / RIDER in the menu's italic yellow-on-ink style.
    {
      const a = t;
      const sc = a < 0.2 ? lerp(2.4, 1, easeOut(a / 0.2)) : 1 + 0.012 * (a - 0.2);
      X.save(); X.translate(W / 2 + sh.sx * 0.5, 760 + sh.sy * 0.5); X.rotate(-0.05); X.scale(sc, sc);
      X.globalAlpha = clamp(a / 0.05, 0, 1);
      X.font = `italic 900 215px ${FONT}`; X.textAlign = 'center'; X.textBaseline = 'middle'; X.lineJoin = 'round';
      X.letterSpacing = '2px';
      for (const [l, yy] of [['KAMOTE', -100], ['RIDER', 104]]) {
        X.fillStyle = 'rgba(0,0,0,0.5)'; X.fillText(l, 12, yy + 16);
        X.lineWidth = 40; X.strokeStyle = C(INK); X.strokeText(l, 0, yy);
        X.fillStyle = C(YELLOW); X.fillText(l, 0, yy);
      }
      X.letterSpacing = '0px';
      X.restore();
    }
    // HIGHWAY ESCAPE pill.
    if (t > 0.4) {
      const k = backOut((t - 0.4) / 0.3);
      X.save(); X.translate(W / 2, 1065 + (1 - k) * 60); X.scale(k, k); X.globalAlpha = clamp((t - 0.4) / 0.1, 0, 1);
      X.font = `900 58px ${FONT}`; X.letterSpacing = '16px';
      const w = X.measureText('HIGHWAY ESCAPE').width + 70; X.letterSpacing = '0px';
      RR(-w / 2, -50, w / 2, 50, 18, KRED);
      TXT('HIGHWAY ESCAPE', 8, 3, 58, 0xFFFFFFFF, { align: 'center', ls: 16 });
      X.restore();
    }
    // SWIPE. DODGE. ESCAPE.
    const words = [['SWIPE.', 1.6, -330, 0xFFFFFFFF], ['DODGE.', 2.0, 0, 0xFFFFFFFF], ['ESCAPE.', 2.4, 340, YELLOW]];
    for (const [w, t0, dx, c] of words) {
      if (t < t0) continue;
      const k = backOut((t - t0) / 0.22);
      X.save(); X.translate(W / 2 + dx, 1270); X.scale(k, k);
      TXT(w, 0, 0, 84, c, { align: 'center', italic: true, stroke: 16, strokeColor: INK });
      X.restore();
    }
    if (t > 3.2) {
      const k = backOut((t - 3.2) / 0.3);
      X.save(); X.translate(W / 2, 1470); X.rotate(-0.05); X.scale(k, k);
      TXT('TAKBO, KAMOTE!', 0, 0, 110, YELLOW, { align: 'center', italic: true, stroke: 26, strokeColor: INK });
      X.restore();
    }
    subline('AN ENDLESS HIGHWAY ARCADE GAME', 3.6, DUR, t, { y: 1610, size: 34, ls: 8, color: 0xFFE0E0E0, hold: true });
    subline('All characters, officers, vehicles and brands are fictional.', 3.8, DUR, t, { y: 1840, size: 24, ls: 1, color: 0xFF8A93A6, stroke: 0, hold: true });
    vignette(0.8);
    if (t > 5.8) screenOverlay(withA(0xFF000000, easeIn((t - 5.8) / 0.6)));
  });
}

// ================================================================ FRAME LOOP
function renderFrame(t) {
  X.setTransform(1, 0, 0, 1, 0, 0);
  X.globalAlpha = 1;
  X.fillStyle = '#000'; X.fillRect(0, 0, W, H);
  const sc = SCENES.find((s) => t >= s.t0 && t < s.t1) || SCENES[SCENES.length - 1];
  X.save();
  sc.draw(t - sc.t0, t);
  X.restore();
  X.setTransform(1, 0, 0, 1, 0, 0);
  X.globalAlpha = 1;
  for (const f of FLASHES) {
    const d = t - f;
    if (d >= 0 && d < 0.2) { X.globalAlpha = (1 - d / 0.2) * 0.75; X.fillStyle = '#fff'; X.fillRect(0, 0, W, H); }
  }
  X.globalAlpha = 1;
}

function captureFrame(t, quality) {
  renderFrame(t);
  return cv.toDataURL('image/jpeg', quality || 0.93);
}

window.TRAILER = { DUR, CUES, renderFrame, captureFrame };

// Live preview when opened directly: ?t=12.3 shows one frame, otherwise plays.
(function preview() {
  const q = new URLSearchParams(location.search);
  if (q.has('capture')) return;
  if (q.has('t')) { renderFrame(parseFloat(q.get('t'))); return; }
  const start = performance.now();
  const loop = () => { renderFrame(((performance.now() - start) / 1000) % DUR); requestAnimationFrame(loop); };
  requestAnimationFrame(loop);
})();
