class_name Palette
extends RefCounted
## بيئات اللعبة الثلاث + تحويل الألوان إلى عالم السراب.

const BIOME_LEN := 1400.0
const BIOME_COUNT := 3


static func biome_index_at(distance: float) -> int:
	return int(distance / BIOME_LEN) % BIOME_COUNT


static func biome(i: int) -> Dictionary:
	match i % BIOME_COUNT:
		0:
			return {
				"id": 0, "name": "أور — أرض الزقورة", "night": false,
				"sky_top": Color(0.30, 0.50, 0.85), "sky_horizon": Color(1.0, 0.76, 0.5),
				"sun": Color(1.0, 0.85, 0.55), "sun_dir": Vector3(0.25, 0.28, -1.0),
				"fog": Color(0.98, 0.78, 0.58), "fog_begin": 40.0, "fog_end": 175.0,
				"ambient": Color(0.78, 0.7, 0.72), "ambient_energy": 0.85,
				"light": Color(1.0, 0.92, 0.78), "light_energy": 1.15, "light_rot": Vector3(-48, -28, 0),
				"road_a": Color(0.80, 0.66, 0.46), "road_b": Color(0.72, 0.58, 0.40),
				"edge": Color(0.60, 0.46, 0.32), "line": Color(0.95, 0.82, 0.55),
				"side": Color(0.92, 0.74, 0.50), "side2": Color(0.86, 0.66, 0.42),
				"dune": Color(0.95, 0.76, 0.52), "dune2": Color(0.88, 0.62, 0.40),
				"stone": Color(0.78, 0.66, 0.5), "stone2": Color(0.62, 0.5, 0.38),
				"green": Color(0.30, 0.52, 0.22), "trunk": Color(0.45, 0.3, 0.2),
				"far1": Color(0.86, 0.60, 0.52), "far2": Color(0.80, 0.54, 0.5), "far3": Color(0.7, 0.46, 0.46),
			}
		1:
			return {
				"id": 1, "name": "الأهوار — أرض القصب والماء", "night": false,
				"sky_top": Color(0.18, 0.52, 0.72), "sky_horizon": Color(0.84, 0.95, 0.82),
				"sun": Color(1.0, 0.96, 0.75), "sun_dir": Vector3(-0.3, 0.4, -1.0),
				"fog": Color(0.74, 0.90, 0.80), "fog_begin": 35.0, "fog_end": 165.0,
				"ambient": Color(0.70, 0.82, 0.82), "ambient_energy": 0.9,
				"light": Color(1.0, 0.97, 0.86), "light_energy": 1.1, "light_rot": Vector3(-55, 32, 0),
				"road_a": Color(0.70, 0.62, 0.48), "road_b": Color(0.62, 0.55, 0.42),
				"edge": Color(0.45, 0.38, 0.28), "line": Color(0.9, 0.9, 0.7),
				"side": Color(0.32, 0.66, 0.62), "side2": Color(0.4, 0.74, 0.66),
				"dune": Color(0.42, 0.62, 0.3), "dune2": Color(0.34, 0.54, 0.26),
				"stone": Color(0.78, 0.7, 0.52), "stone2": Color(0.6, 0.52, 0.38),
				"green": Color(0.32, 0.6, 0.28), "trunk": Color(0.5, 0.36, 0.22),
				"far1": Color(0.52, 0.74, 0.7), "far2": Color(0.44, 0.68, 0.66), "far3": Color(0.36, 0.6, 0.6),
			}
		_:
			return {
				"id": 2, "name": "أوروك — مدينة جلجامش", "night": true,
				"sky_top": Color(0.04, 0.05, 0.16), "sky_horizon": Color(0.62, 0.26, 0.42),
				"sun": Color(1.0, 0.7, 0.5), "sun_dir": Vector3(0.0, 0.12, -1.0),
				"fog": Color(0.30, 0.17, 0.34), "fog_begin": 30.0, "fog_end": 150.0,
				"ambient": Color(0.5, 0.42, 0.7), "ambient_energy": 0.8,
				"light": Color(0.85, 0.8, 1.0), "light_energy": 0.85, "light_rot": Vector3(-40, 20, 0),
				"road_a": Color(0.36, 0.3, 0.42), "road_b": Color(0.30, 0.25, 0.37),
				"edge": Color(0.22, 0.18, 0.28), "line": Color(1.0, 0.72, 0.35),
				"side": Color(0.2, 0.16, 0.26), "side2": Color(0.24, 0.2, 0.3),
				"dune": Color(0.28, 0.22, 0.34), "dune2": Color(0.22, 0.18, 0.3),
				"stone": Color(0.46, 0.38, 0.52), "stone2": Color(0.34, 0.28, 0.4),
				"green": Color(0.2, 0.36, 0.32), "trunk": Color(0.3, 0.22, 0.3),
				"far1": Color(0.36, 0.2, 0.4), "far2": Color(0.28, 0.16, 0.36), "far3": Color(0.2, 0.12, 0.3),
			}


## يحوّل لوناً إلى نظيره في عالم السراب (إزاحة لونية نحو البنفسجي/الفيروزي).
static func to_mirage(c: Color, amt: float = 1.0) -> Color:
	var m := Color.from_hsv(fposmod(c.h + 0.58, 1.0), clampf(c.s * 0.85 + 0.2, 0.0, 1.0), clampf(c.v * 0.82 + 0.04, 0.0, 1.0))
	m.a = c.a
	return c.lerp(m, amt)


static func lerp_biome_color(a: Dictionary, b: Dictionary, key: String, t: float) -> Color:
	return (a[key] as Color).lerp(b[key] as Color, t)
