// Standalone PNG generator that mirrors the algorithm in
// scripts/squirrel/squirrel_spritesheet.gd so the sheet can be produced
// without running Godot. Writes res://squirrel_sheet.png at the project
// root. Pure Node (no deps) — uses zlib for the IDAT payload.

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// ----- canvas + palette ---------------------------------------------------
const FRAME = 96;
const COLS = 6;
const ROWS = 7;
const W = FRAME * COLS;
const H = FRAME * ROWS;
const OUT_PATH = path.join(__dirname, '..', '..', 'squirrel_sheet.png');

const FUR_LIGHT  = [199, 138,  85, 255];
const FUR_MID    = [160, 102,  58, 255];
const FUR_DARK   = [110,  66,  36, 255];
const BELLY      = [240, 215, 170, 255];
const EAR_INNER  = [200, 150, 110, 255];
const EYE_WHITE  = [245, 245, 245, 255];
const EYE_BLACK  = [ 20,  20,  25, 255];
const NOSE       = [ 50,  30,  35, 255];
const TOOTH      = [250, 245, 220, 255];
const CLOTH      = [ 60,  80, 110, 255];
const CLOTH_DARK = [ 38,  52,  78, 255];
const BELT       = [ 70,  45,  25, 255];
const BUCKLE     = [210, 175,  80, 255];
const PANTS      = [ 70,  55,  40, 255];
const PANTS_DARK = [ 45,  35,  25, 255];
const BOOT       = [ 55,  35,  20, 255];
const BOOT_DARK  = [ 35,  22,  12, 255];
const BLADE      = [220, 225, 235, 255];
const BLADE_EDGE = [255, 255, 255, 255];
const BLADE_DARK = [140, 145, 155, 255];
const HILT       = [ 95,  60,  30, 255];
const GUARD      = [180, 145,  70, 255];
const OUTLINE    = [ 20,  14,  10, 255];
const CLEAR      = [0, 0, 0, 0];

// Pixel buffer; RGBA8 row-major.
const buf = Buffer.alloc(W * H * 4, 0);

// Per-frame draw cursor (top-left).
let ox = 0;
let oy = 0;

function set_cell(col, row) {
	ox = col * FRAME;
	oy = row * FRAME;
}

function px(x, y, c) {
	if (x < 0 || y < 0 || x >= FRAME || y >= FRAME) return;
	const gx = ox + x;
	const gy = oy + y;
	const i = (gy * W + gx) * 4;
	buf[i]     = c[0];
	buf[i + 1] = c[1];
	buf[i + 2] = c[2];
	buf[i + 3] = c[3];
}

function get_px(x, y) {
	if (x < 0 || y < 0 || x >= FRAME || y >= FRAME) return CLEAR;
	const gx = ox + x;
	const gy = oy + y;
	const i = (gy * W + gx) * 4;
	return [buf[i], buf[i + 1], buf[i + 2], buf[i + 3]];
}

function rect(x, y, w, h, c) {
	for (let j = 0; j < h; j++)
		for (let i = 0; i < w; i++)
			px(x + i, y + j, c);
}

function disc(cx, cy, r, c) {
	const r2 = r * r;
	for (let j = -r; j <= r; j++)
		for (let i = -r; i <= r; i++)
			if (i * i + j * j <= r2) px(cx + i, cy + j, c);
}

function ellipse(cx, cy, rx, ry, c) {
	if (rx <= 0 || ry <= 0) return;
	for (let j = -ry; j <= ry; j++)
		for (let i = -rx; i <= rx; i++) {
			const fx = i / rx;
			const fy = j / ry;
			if (fx * fx + fy * fy <= 1.0) px(cx + i, cy + j, c);
		}
}

function line(x0, y0, x1, y1, c, thick) {
	thick = thick || 1;
	x0 |= 0; y0 |= 0; x1 |= 0; y1 |= 0;
	const dx = Math.abs(x1 - x0);
	const dy = -Math.abs(y1 - y0);
	const sx = x0 < x1 ? 1 : -1;
	const sy = y0 < y1 ? 1 : -1;
	let err = dx + dy;
	let x = x0, y = y0;
	while (true) {
		if (thick <= 1) px(x, y, c);
		else disc(x, y, (thick / 2) | 0, c);
		if (x === x1 && y === y1) break;
		const e2 = 2 * err;
		if (e2 >= dy) { err += dy; x += sx; }
		if (e2 <= dx) { err += dx; y += sy; }
	}
}

function outline_frame() {
	// Snapshot then add 1px OUTLINE where transparent neighbours touch opaque.
	const snap = new Uint8Array(FRAME * FRAME * 4);
	for (let j = 0; j < FRAME; j++)
		for (let i = 0; i < FRAME; i++) {
			const p = get_px(i, j);
			const k = (j * FRAME + i) * 4;
			snap[k] = p[0]; snap[k + 1] = p[1]; snap[k + 2] = p[2]; snap[k + 3] = p[3];
		}
	const dirs = [[1,0],[-1,0],[0,1],[0,-1]];
	for (let j = 0; j < FRAME; j++)
		for (let i = 0; i < FRAME; i++) {
			const k = (j * FRAME + i) * 4;
			if (snap[k + 3] > 0) continue;
			for (const d of dirs) {
				const ni = i + d[0], nj = j + d[1];
				if (ni < 0 || nj < 0 || ni >= FRAME || nj >= FRAME) continue;
				const kk = (nj * FRAME + ni) * 4;
				if (snap[kk + 3] > 0) { px(i, j, OUTLINE); break; }
			}
		}
}

// ----- body builder -------------------------------------------------------
function r2i(v) { return Math.round(v) | 0; }

function draw_tail(cx, cy, facing, phase, crouch) {
	const base_x = cx - 10.0 * facing;
	const base_y = cy + 12.0 - crouch * 3.0;
	const seg = 8;
	for (let i = 0; i < seg; i++) {
		const t = i / (seg - 1);
		const ang = (160.0 + (60.0 + phase * 25.0 - 160.0) * t) * Math.PI / 180;
		const dist = 14.0 * (0.6 + t * 0.9);
		const r = 9.0 + (4.0 - 9.0) * t;
		const x = base_x - Math.cos(ang) * dist * facing;
		const y = base_y - Math.sin(ang) * dist;
		disc(r2i(x), r2i(y), r | 0, FUR_MID);
	}
	for (let i = 0; i < seg; i++) {
		const t = i / (seg - 1);
		const ang = (160.0 + (60.0 + phase * 25.0 - 160.0) * t) * Math.PI / 180;
		const dist = 14.0 * (0.6 + t * 0.9);
		const r = 6.0 + (2.0 - 6.0) * t;
		const x = base_x - Math.cos(ang) * dist * facing - 1.0 * facing;
		const y = base_y - Math.sin(ang) * dist - 1.0;
		disc(r2i(x), r2i(y), r | 0, FUR_LIGHT);
	}
}

function draw_head(cx, cy, facing, blink, mouth) {
	const icx = r2i(cx);
	const icy = r2i(cy);
	disc(icx - 7, icy - 9, 5, FUR_MID);
	disc(icx + 7, icy - 9, 5, FUR_MID);
	disc(icx - 7, icy - 9, 3, EAR_INNER);
	disc(icx + 7, icy - 9, 3, EAR_INNER);
	ellipse(icx, icy, 10, 9, FUR_MID);
	ellipse(icx + 5 * facing, icy + 3, 6, 4, FUR_LIGHT);
	disc(icx - 7 * facing, icy + 2, 3, FUR_LIGHT);
	const ex = icx + 2 * facing;
	const ey = icy - 2;
	if (blink) {
		rect(ex - 1, ey, 3, 1, EYE_BLACK);
	} else {
		disc(ex, ey, 2, EYE_WHITE);
		px(ex + facing, ey, EYE_BLACK);
		px(ex, ey, EYE_BLACK);
	}
	px(ex - 1, ey - 3, FUR_DARK);
	px(ex,     ey - 3, FUR_DARK);
	px(ex + 1, ey - 3, FUR_DARK);
	disc(icx + 9 * facing, icy + 2, 1, NOSE);
	if (mouth === 'o') {
		rect(icx + 6 * facing, icy + 5, 3, 2, EYE_BLACK);
		px(icx + 6 * facing, icy + 5, TOOTH);
		px(icx + 7 * facing, icy + 5, TOOTH);
	} else {
		px(icx + 6 * facing, icy + 5, EYE_BLACK);
		px(icx + 7 * facing, icy + 5, EYE_BLACK);
	}
}

function draw_torso(cx, cy, facing, crouch) {
	const icx = r2i(cx);
	const icy = r2i(cy);
	ellipse(icx, icy, 10, 13 - (crouch * 3.0 | 0), CLOTH);
	for (let j = -12; j < 12; j++)
		for (let i = -10; i < 0; i++) {
			const fx = i / 10.0;
			const fy = j / 13.0;
			if (fx * fx + fy * fy <= 1.0)
				px(icx + i * facing, icy + j, CLOTH_DARK);
		}
	ellipse(icx, icy + 2, 4, 6, BELLY);
	rect(icx - 9, icy + 9, 18, 3, BELT);
	rect(icx - 1, icy + 9, 3, 3, BUCKLE);
}

function draw_arm(sx, sy, offset, facing, is_right) {
	const isx = r2i(sx);
	const isy = r2i(sy);
	disc(isx, isy, 4, CLOTH);
	const hand_x = sx + offset[0] * facing;
	const hand_y = sy + offset[1] + 14.0;
	const elbow_x = (sx + hand_x) * 0.5 + (is_right ? 1.5 * facing : -1.5 * facing);
	const elbow_y = (sy + hand_y) * 0.5 - 1.0;
	line(isx, isy, r2i(elbow_x), r2i(elbow_y), CLOTH, 5);
	line(r2i(elbow_x), r2i(elbow_y), r2i(hand_x), r2i(hand_y), FUR_MID, 4);
	disc(r2i(hand_x), r2i(hand_y), 3, FUR_LIGHT);
	return [hand_x, hand_y];
}

function draw_leg(hx, hy, offset, crouch, facing, is_right) {
	const foot_x = hx + offset[0];
	const foot_y = hy + offset[1] + 22.0 - crouch * 6.0;
	const knee_x = (hx + foot_x) * 0.5 + (is_right ? 2.0 : -2.0) * facing;
	const knee_y = (hy + foot_y) * 0.5 + crouch * 4.0;
	line(r2i(hx), r2i(hy), r2i(knee_x), r2i(knee_y), PANTS, 6);
	line(r2i(knee_x), r2i(knee_y), r2i(foot_x), r2i(foot_y), PANTS_DARK, 5);
	ellipse(r2i(foot_x) + facing, r2i(foot_y) + 1, 5, 3, BOOT);
	rect(r2i(foot_x) - 3, r2i(foot_y) + 2, 8, 2, BOOT_DARK);
}

function draw_weapon(hand, ang, facing, kind) {
	const length = kind === 'stab' ? 24 : 22;
	const dir = [Math.cos(ang) * facing, Math.sin(ang)];
	const hilt_start = [hand[0] - dir[0] * 4.0, hand[1] - dir[1] * 4.0];
	const hilt_end   = [hand[0] + dir[0] * 2.0, hand[1] + dir[1] * 2.0];
	const guard_end  = [hand[0] + dir[0] * 3.0, hand[1] + dir[1] * 3.0];
	const blade_end  = [hand[0] + dir[0] * length, hand[1] + dir[1] * length];

	line(r2i(hilt_start[0]), r2i(hilt_start[1]), r2i(hilt_end[0]), r2i(hilt_end[1]), HILT, 3);
	const perp = [-dir[1], dir[0]];
	const g1 = [guard_end[0] + perp[0] * 4.0, guard_end[1] + perp[1] * 4.0];
	const g2 = [guard_end[0] - perp[0] * 4.0, guard_end[1] - perp[1] * 4.0];
	line(r2i(g1[0]), r2i(g1[1]), r2i(g2[0]), r2i(g2[1]), GUARD, 2);
	line(r2i(guard_end[0]), r2i(guard_end[1]), r2i(blade_end[0]), r2i(blade_end[1]), BLADE, 3);
	const hl1 = [guard_end[0] + perp[0] * 0.5, guard_end[1] + perp[1] * 0.5];
	const hl2 = [blade_end[0] + perp[0] * 0.5, blade_end[1] + perp[1] * 0.5];
	line(r2i(hl1[0]), r2i(hl1[1]), r2i(hl2[0]), r2i(hl2[1]), BLADE_EDGE, 1);
	const sh1 = [guard_end[0] - perp[0] * 1.0, guard_end[1] - perp[1] * 1.0];
	const sh2 = [blade_end[0] - perp[0] * 1.0, blade_end[1] - perp[1] * 1.0];
	line(r2i(sh1[0]), r2i(sh1[1]), r2i(sh2[0]), r2i(sh2[1]), BLADE_DARK, 1);
}

function get(pose, key, def) { return key in pose ? pose[key] : def; }

function draw_squirrel(pose) {
	const facing = get(pose, 'facing', 1);
	const crouch = get(pose, 'crouch', 0.0);
	const lean   = get(pose, 'lean', 0.0);
	const pos    = get(pose, 'pos', [0, 0]);

	const cx = 48.0 + pos[0];
	const cy = 50.0 + pos[1] + crouch * 8.0;

	const tail_phase = get(pose, 'tail_phase', 0.0);
	draw_tail(cx, cy, facing, tail_phase, crouch);

	const hip_y = cy + 16.0 - crouch * 4.0;
	const l_leg = get(pose, 'l_leg', [0, 0]);
	const r_leg = get(pose, 'r_leg', [0, 0]);
	draw_leg(cx - 6 * facing, hip_y, l_leg, crouch, facing, false);
	draw_leg(cx + 6 * facing, hip_y, r_leg, crouch, facing, true);

	const torso_top = cy - 14.0;
	const lean_off = lean * 0.4;
	draw_torso(cx + lean_off, cy, facing, crouch);

	const head_cx = cx + lean_off * 1.6 + facing * 1.0;
	const head_cy = torso_top - 10.0;
	draw_head(head_cx, head_cy, facing, get(pose, 'blink', false), get(pose, 'mouth', 'n'));

	const sh_y = torso_top + 2.0;
	const l_arm = get(pose, 'l_arm', [0, 0]);
	const r_arm = get(pose, 'r_arm', [0, 0]);
	draw_arm(cx - 9 * facing + lean_off, sh_y, l_arm, facing, false);
	const weapon = get(pose, 'weapon', '');
	const hand_pos = draw_arm(cx + 9 * facing + lean_off, sh_y, r_arm, facing, true);
	if (weapon !== '') {
		const ang = (get(pose, 'weapon_ang', 0.0)) * Math.PI / 180;
		const woff = get(pose, 'weapon_off', [0, 0]);
		draw_weapon([hand_pos[0] + woff[0], hand_pos[1] + woff[1]], ang, facing, weapon);
	}
	outline_frame();
}

// ----- animations ---------------------------------------------------------
function draw_idle(f) {
	const bob = Math.sin(f * Math.PI * 0.5);
	const tail = Math.sin(f * Math.PI * 0.5) * 0.4;
	draw_squirrel({
		pos: [0, bob],
		tail_phase: tail,
		l_arm: [-1, 1 + bob * 0.3],
		r_arm: [ 1, 1 + bob * 0.3],
		weapon: 'carry',
		weapon_ang: -90.0 + 6.0 * Math.sin(f * Math.PI * 0.5),
		weapon_off: [0, -2],
		blink: f === 3,
	});
}

function draw_walk(f) {
	const phase = f / 6.0 * Math.PI * 2;
	const leg_swing = Math.sin(phase) * 5.0;
	const arm_swing = Math.sin(phase) * 4.0;
	const bob = Math.abs(Math.sin(phase * 2.0)) * -1.5;
	draw_squirrel({
		pos: [0, bob],
		tail_phase: Math.sin(phase) * 0.5,
		l_leg: [ leg_swing, Math.abs(Math.sin(phase)) * -3.0],
		r_leg: [-leg_swing, Math.abs(Math.cos(phase)) * -3.0],
		l_arm: [-arm_swing, 0],
		r_arm: [ arm_swing, 0],
		weapon: 'carry',
		weapon_ang: -90.0 + arm_swing * 2.0,
		weapon_off: [0, -1],
	});
}

function draw_run(f) {
	const phase = f / 6.0 * Math.PI * 2;
	const leg_swing = Math.sin(phase) * 9.0;
	const arm_swing = Math.sin(phase) * 8.0;
	const bob = Math.abs(Math.sin(phase * 2.0)) * -3.0;
	draw_squirrel({
		pos: [0, bob],
		lean: 12.0,
		tail_phase: 0.7 + Math.sin(phase) * 0.3,
		l_leg: [ leg_swing, -Math.abs(Math.sin(phase)) * 6.0],
		r_leg: [-leg_swing, -Math.abs(Math.cos(phase)) * 6.0],
		l_arm: [-arm_swing - 2, -2],
		r_arm: [ arm_swing + 2, -2],
		weapon: 'carry',
		weapon_ang: -70.0 + arm_swing * 3.0,
		weapon_off: [0, -1],
		mouth: 'o',
	});
}

function draw_crouch(f) {
	const t = f / 2.0;
	draw_squirrel({
		pos: [0, 0],
		crouch: t,
		tail_phase: -0.2 - t * 0.4,
		l_arm: [-2, 4 * t],
		r_arm: [ 2, 4 * t],
		weapon: 'carry',
		weapon_ang: -90.0 + 30.0 * t,
		weapon_off: [0, -1 + 2 * t],
	});
}

function draw_slide(f) {
	const t = f / 3.0;
	draw_squirrel({
		pos: [4, 14],
		crouch: 1.0,
		lean: 35.0,
		tail_phase: -0.8,
		l_leg: [14, 4],
		r_leg: [-2, 4],
		l_arm: [-6, 6],
		r_arm: [ 8, 4],
		weapon: 'carry',
		weapon_ang: -30.0,
		weapon_off: [2, 0],
		mouth: 'o',
	});
	for (let i = 0; i < 3; i++) {
		const dx = 8 + i * 10;
		const dy = 80 + (i % 2) * 2 - (t * 2.0 | 0);
		disc(dx, dy, 3 + i, [217, 199, 166, 140]);
		disc(dx - 2, dy + 2, 2, [242, 230, 199, 102]);
	}
}

function draw_slash(f) {
	const angles = [-160.0, -110.0, -40.0, 30.0, 60.0];
	const arm_x  = [-4.0,    0.0,   8.0, 10.0,  6.0];
	const arm_y  = [-6.0,   -8.0,  -4.0,  2.0,  4.0];
	const lean   = [-8.0,   -4.0,   6.0, 12.0,  8.0];
	draw_squirrel({
		pos: [0, 0],
		lean: lean[f],
		tail_phase: 0.3 + f * 0.1,
		l_arm: [-2, 2],
		r_arm: [arm_x[f], arm_y[f]],
		l_leg: [-2, 0],
		r_leg: [ 3, 0],
		weapon: 'slash',
		weapon_ang: angles[f],
		weapon_off: [0, 0],
		mouth: f === 2 ? 'o' : 'n',
	});
	if (f === 2 || f === 3) {
		const cx = 60, cy = 50;
		const r = f === 2 ? 26 : 28;
		for (let a_deg = -70; a_deg < 30; a_deg += 4) {
			const a = a_deg * Math.PI / 180;
			const x = cx + Math.round(Math.cos(a) * r);
			const y = cy + Math.round(Math.sin(a) * r);
			px(x, y, [255, 255, 255, 179]);
			px(x, y + 1, [255, 255, 255, 102]);
		}
	}
}

function draw_stab(f) {
	const arm_x = [-6.0, -2.0, 16.0, 14.0,  6.0];
	const arm_y = [ 0.0,  0.0,  0.0,  0.0,  1.0];
	const ang   = [-10.0,  0.0,  0.0,  0.0, -8.0];
	const lean  = [-6.0, -2.0,  8.0,  4.0,  0.0];
	draw_squirrel({
		pos: [0, 0],
		lean: lean[f],
		tail_phase: 0.2 + (f === 2 ? 0.5 : 0.0),
		l_arm: [-3, 2],
		r_arm: [arm_x[f], arm_y[f]],
		l_leg: [-3, 0],
		r_leg: [ 4, 0],
		weapon: 'stab',
		weapon_ang: ang[f],
		weapon_off: [0, 0],
		mouth: f === 2 ? 'o' : 'n',
	});
	if (f === 2) {
		for (let i = 0; i < 4; i++) {
			px(86 + i, 48, [255, 255, 255, 204]);
			px(86 + i, 50, [255, 255, 255, 128]);
			px(86 + i, 52, [255, 255, 255, 204]);
		}
	}
}

// ----- run all frames -----------------------------------------------------
for (let f = 0; f < 4; f++) { set_cell(f, 0); draw_idle(f); }
for (let f = 0; f < 6; f++) { set_cell(f, 1); draw_walk(f); }
for (let f = 0; f < 6; f++) { set_cell(f, 2); draw_run(f); }
for (let f = 0; f < 3; f++) { set_cell(f, 3); draw_crouch(f); }
for (let f = 0; f < 4; f++) { set_cell(f, 4); draw_slide(f); }
for (let f = 0; f < 5; f++) { set_cell(f, 5); draw_slash(f); }
for (let f = 0; f < 5; f++) { set_cell(f, 6); draw_stab(f); }

// ----- encode PNG ---------------------------------------------------------
const CRC_TABLE = (() => {
	const t = new Uint32Array(256);
	for (let n = 0; n < 256; n++) {
		let c = n;
		for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
		t[n] = c >>> 0;
	}
	return t;
})();

function crc32(buf) {
	let c = 0xffffffff;
	for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
	return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length, 0);
	const typeBuf = Buffer.from(type, 'ascii');
	const crcInput = Buffer.concat([typeBuf, data]);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(crc32(crcInput), 0);
	return Buffer.concat([len, typeBuf, data, crc]);
}

// IHDR
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0);
ihdr.writeUInt32BE(H, 4);
ihdr[8]  = 8;   // bit depth
ihdr[9]  = 6;   // colour type RGBA
ihdr[10] = 0;   // compression
ihdr[11] = 0;   // filter
ihdr[12] = 0;   // interlace

// IDAT: each scanline prefixed with filter byte 0 (None).
const raw = Buffer.alloc((W * 4 + 1) * H);
for (let y = 0; y < H; y++) {
	raw[y * (W * 4 + 1)] = 0;
	buf.copy(raw, y * (W * 4 + 1) + 1, y * W * 4, (y + 1) * W * 4);
}
const idat = zlib.deflateSync(raw, { level: 9 });

const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const png = Buffer.concat([
	sig,
	chunk('IHDR', ihdr),
	chunk('IDAT', idat),
	chunk('IEND', Buffer.alloc(0)),
]);

fs.writeFileSync(OUT_PATH, png);
console.log('Wrote', OUT_PATH, png.length, 'bytes');
