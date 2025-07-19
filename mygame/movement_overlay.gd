extends TileMapLayer

var H_COORDS := []  # filled after tileset creation / assignment

func _ready():
	# If tiles created in editor, populate coords dynamically:
	_create_overlay_tileset(16)
	_cache_highlight_coords()
	

func _cache_highlight_coords():
	H_COORDS.clear()
	var atlas = tile_set.get_source(0)
	# Assuming tiles laid out horizontally y=0
	var size_guess := 0
	while atlas.has_tile(Vector2i(size_guess, 0)):
		H_COORDS.append(Vector2i(size_guess,0))
		size_guess += 1

func set_band_cell(cell: Vector2i, band: int) -> void:
	if H_COORDS.is_empty():
		return
	band = clamp(band, 0, H_COORDS.size() - 1)
	set_cell(cell, 0,H_COORDS[band])

func show_reachable(costs: Dictionary, max_cost: int) -> void:
	clear()
	if costs.is_empty(): return
	for cell in costs.keys():
		var c: int = costs[cell]
		var band := int(floor(float(c)/max_cost * float(H_COORDS.size()-1)))
		set_band_cell(cell, band)
		
func _create_overlay_tileset(tile_size: int = 16):
	var ts := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = _make_palette_texture(tile_size)
	# Suppose 5 horizontal colors in the generated strip.
	for x in range(5):
		atlas.create_tile(Vector2i(x,0))   # expose tile
	ts.add_source(atlas)  # assigns source id 0 by default
	tile_set = ts

func _make_palette_texture(tile_size: int) -> Texture2D:
	var colors = [
		Color(0.2,0.9,1.0,0.45),
		Color(0.2,0.8,1.0,0.35),
		Color(0.15,0.7,1.0,0.28),
		Color(0.15,0.55,0.9,0.22),
		Color(0.1,0.45,0.8,0.18),
	]
	var img := Image.create(tile_size * colors.size(), tile_size, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		img.fill_rect(Rect2i(i*tile_size, 0, tile_size, tile_size), colors[i])
	var tex := ImageTexture.create_from_image(img)
	return tex
