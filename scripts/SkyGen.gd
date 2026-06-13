class_name SkyGen
extends RefCounted
# Procedurally paints an equirectangular panorama sky (gradient, drifting clouds,
# a sun with glow, and a distant mountain silhouette along the horizon) and wraps
# it in a PanoramaSkyMaterial. No external image needed.

static func make_sky() -> Sky:
	var img := _generate(1024, 512)
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = ImageTexture.create_from_image(img)
	var sky := Sky.new()
	sky.sky_material = mat
	return sky

static func _generate(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var clouds := FastNoiseLite.new()
	clouds.noise_type = FastNoiseLite.TYPE_PERLIN
	clouds.frequency = 0.012
	clouds.fractal_octaves = 4
	clouds.seed = 2026
	var ridge := FastNoiseLite.new()
	ridge.noise_type = FastNoiseLite.TYPE_PERLIN
	ridge.frequency = 0.02
	ridge.seed = 555

	var top := Color(0.16, 0.30, 0.62)
	var horizon := Color(0.88, 0.74, 0.58)
	var below := Color(0.30, 0.42, 0.52)
	var sun_u := 0.70
	var sun_v := 0.33

	for y in h:
		var v := float(y) / h           # 0 = zenith, 1 = nadir
		var sky_col: Color
		if v < 0.5:
			sky_col = horizon.lerp(top, clampf(1.0 - v * 2.0, 0.0, 1.0))
		else:
			sky_col = horizon.lerp(below, clampf((v - 0.5) * 2.0, 0.0, 1.0))
		for x in w:
			var u := float(x) / w
			var col := sky_col
			# Clouds in the upper sky.
			if v < 0.5:
				var cn := clouds.get_noise_2d(float(x), float(y))
				var amt := smoothstep(0.15, 0.6, cn) * (1.0 - v * 2.0)
				col = col.lerp(Color(1, 1, 1), amt * 0.55)
			# Sun + glow (azimuth weighted so it reads round).
			var d := Vector2((u - sun_u) * 2.0, v - sun_v)
			var dist := d.length()
			col = col.lerp(Color(1.0, 0.96, 0.8), clampf(1.0 - dist / 0.28, 0.0, 1.0) ** 2)
			if dist < 0.028:
				col = Color(1.0, 0.98, 0.92)
			# Distant mountain silhouette along the horizon.
			var rn := ridge.get_noise_2d(float(x), 0.0) * 0.5 + 0.5
			var ridge_v := 0.5 - (0.02 + rn * 0.06)
			if v >= ridge_v and v <= 0.5:
				col = col.lerp(Color(0.10, 0.12, 0.18), 0.85)
			img.set_pixel(x, y, col)
	return img
