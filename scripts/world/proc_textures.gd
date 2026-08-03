class_name ProcTextures
extends RefCounted
## Small textures generated at load time, so the project still ships no image
## assets.
##
## They are all near-white greyscale: the colour the player picks is applied
## through albedo_color and these only add the grain, the seams and the
## shading that stop a surface reading as a flat slab.

static var _cache: Dictionary = {}


static func _cached(key: String, maker: Callable) -> ImageTexture:
	if not _cache.has(key):
		var image: Image = maker.call()
		image.generate_mipmaps()
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## Soft round blob used to ground furniture on the floor.
static func contact_shadow() -> ImageTexture:
	return _cached("shadow", func() -> Image:
		var size := 64
		var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
		var centre := float(size - 1) * 0.5
		for y in size:
			for x in size:
				var distance := Vector2(x - centre, y - centre).length() / centre
				var alpha: float = clampf(1.0 - distance, 0.0, 1.0)
				# Smoothstep, so the rim fades out rather than cutting off.
				alpha = alpha * alpha * (3.0 - 2.0 * alpha)
				image.set_pixel(x, y, Color(0, 0, 0, alpha))
		return image)


## Floorboards, two metres of them across the texture.
static func floor_planks() -> ImageTexture:
	return _cached("planks", func() -> Image:
		var size := 256
		var image := Image.create(size, size, true, Image.FORMAT_RGB8)
		var plank_height := 22
		var random := RandomNumberGenerator.new()
		random.seed = 20260803
		for y in size:
			var plank := y / plank_height
			# Every board gets its own tone, and a stagger so the short ends
			# do not line up into a grid.
			random.seed = 20260803 + plank * 7919
			var tone := 0.90 + random.randf() * 0.12
			var offset := (plank % 3) * (size / 3)
			for x in size:
				var value := tone
				# Long edges between boards.
				var edge := y % plank_height
				if edge == 0 or edge == 1:
					value *= 0.74
				elif edge == plank_height - 1:
					value *= 0.88
				# Short ends, staggered board to board.
				if (x + offset) % size < 2:
					value *= 0.80
				# Grain.
				value *= 1.0 + sin(float(x) * 0.35 + float(plank) * 2.1) * 0.012
				image.set_pixel(x, y, Color(value, value, value))
		return image)


## Barely-there mottling that keeps a painted wall from looking like a
## flat-shaded polygon.
static func wall_plaster() -> ImageTexture:
	return _cached("plaster", func() -> Image:
		var size := 128
		var image := Image.create(size, size, true, Image.FORMAT_RGB8)
		var noise := FastNoiseLite.new()
		noise.seed = 4242
		noise.frequency = 0.05
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		for y in size:
			for x in size:
				var value: float = 1.0 + noise.get_noise_2d(float(x), float(y)) * 0.035
				image.set_pixel(x, y, Color(value, value, value))
		return image)
