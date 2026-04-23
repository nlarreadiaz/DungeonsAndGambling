extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/options_ingame.tscn")
const PICKUP_ITEM_SCENE: PackedScene = preload("res://Scenes/world/pickup_item.tscn")
const STAR_ITEM_DATA: ItemData = preload("res://assets/items/item_estrella.tres")
const COIN_ITEM_DATA: ItemData = preload("res://assets/items/item_moneda.tres")

const HOUSE_EXTERIOR_TEXTURE: Texture2D = preload("res://assets/Herrería/PNG/House_exterior.png")
const OBJECTS_TEXTURE: Texture2D = preload("res://assets/Tiled_files/Objects.png")
const STREET_TEXTURE: Texture2D = preload("res://assets/Herrería/PNG/Walls_street.png")

const PLAYER_NODE_PATH := NodePath("player")
const TILEMAP_LAYERS_PATH := NodePath("TilemapLayers")
const BACKGROUND_LAYER_PATH := NodePath("TilemapLayers/Background")
const FOREGROUND_LAYER_PATH := NodePath("TilemapLayers/Foreground")
const DETAILS_LAYER_PATH := NodePath("TilemapLayers/details")

const TILE_SIZE := 16
const MAP_COLUMNS := 96
const MAP_ROWS := 64
const WATER_MARGIN_CELLS := 6

const PATH_TILE_REGION := Rect2i(0, 192, 16, 16)
const BLACKSMITH_HOUSE_REGION := Rect2i(12, 12, 156, 148)
const PLAIN_HOUSE_REGION := Rect2i(216, 14, 118, 128)
const WALL_FULL_REGION := Rect2i(346, 50, 108, 94)
const ROOF_LEFT_REGION := Rect2i(146, 149, 96, 95)
const ROOF_RIGHT_REGION := Rect2i(288, 149, 92, 95)
const PORCH_SMALL_REGION := Rect2i(246, 152, 48, 24)
const PORCH_LARGE_REGION := Rect2i(390, 151, 48, 25)
const CART_REGION := Rect2i(128, 88, 80, 72)
const COAL_CART_REGION := Rect2i(344, 88, 80, 72)
const WOOD_SIGN_REGION := Rect2i(100, 220, 72, 88)
const RED_AWNING_REGION := Rect2i(304, 0, 80, 36)
const BLUE_AWNING_REGION := Rect2i(384, 0, 80, 36)
const CRATE_STACK_REGION := Rect2i(104, 16, 96, 48)
const BARREL_STACK_REGION := Rect2i(224, 16, 88, 48)
const SACKS_REGION := Rect2i(264, 44, 64, 24)

var options_ingame: Control = null

var path_tile_texture: AtlasTexture = null
var blacksmith_house_texture: Texture2D = null
var plain_house_texture: Texture2D = null
var wall_full_texture: AtlasTexture = null
var roof_left_texture: Texture2D = null
var roof_right_texture: Texture2D = null
var porch_small_texture: AtlasTexture = null
var porch_large_texture: AtlasTexture = null
var cart_texture: AtlasTexture = null
var coal_cart_texture: AtlasTexture = null
var wood_sign_texture: AtlasTexture = null
var red_awning_texture: AtlasTexture = null
var blue_awning_texture: AtlasTexture = null
var crate_stack_texture: AtlasTexture = null
var barrel_stack_texture: AtlasTexture = null
var sacks_texture: AtlasTexture = null


func _ready() -> void:
	_build_island_village()
	_spawn_demo_pickups()


func _input(event: InputEvent) -> void:
	if not _is_pause_event(event):
		return

	if _close_player_inventory_if_open():
		get_viewport().set_input_as_handled()
		return

	if is_instance_valid(options_ingame):
		return

	get_viewport().set_input_as_handled()
	_open_options_ingame()


func _open_options_ingame() -> void:
	options_ingame = OPTIONS_INGAME_SCENE.instantiate() as Control
	if options_ingame == null:
		push_warning("No se pudo cargar el menu de opciones in-game.")
		return

	add_child(options_ingame)
	options_ingame.tree_exited.connect(_on_options_ingame_closed)
	get_tree().paused = true


func _on_options_ingame_closed() -> void:
	options_ingame = null
	get_tree().paused = false


func _build_island_village() -> void:
	var player := get_node_or_null(PLAYER_NODE_PATH) as Node2D
	var tilemap_layers := get_node_or_null(TILEMAP_LAYERS_PATH) as Node2D
	var background_layer := get_node_or_null(BACKGROUND_LAYER_PATH) as TileMapLayer
	var foreground_layer := get_node_or_null(FOREGROUND_LAYER_PATH) as TileMapLayer
	var details_layer := get_node_or_null(DETAILS_LAYER_PATH) as TileMapLayer

	if player == null or tilemap_layers == null or background_layer == null or foreground_layer == null or details_layer == null:
		push_warning("No se pudo construir la nueva isla porque faltan nodos del mapa.")
		return

	var water_tile := _most_common_tile(background_layer)
	var grass_tiles := _collect_common_tiles(foreground_layer, 6)
	if water_tile.is_empty() or grass_tiles.is_empty():
		push_warning("No se pudieron detectar tiles base para regenerar la isla.")
		return

	_cache_map_textures()

	tilemap_layers.position = Vector2.ZERO
	background_layer.position = Vector2.ZERO
	foreground_layer.position = Vector2.ZERO
	details_layer.position = Vector2.ZERO
	background_layer.clear()
	foreground_layer.clear()
	details_layer.clear()

	var island_cells := _get_island_cells_rect()
	var island_world := _cells_to_world_rect(island_cells)
	var ground_rng := RandomNumberGenerator.new()
	ground_rng.seed = 842761

	_fill_layer_rect(background_layer, Rect2i(0, 0, MAP_COLUMNS, MAP_ROWS), water_tile)
	_fill_ground_with_variations(foreground_layer, island_cells, grass_tiles, ground_rng)

	var generated_root := _rebuild_generated_root(player)
	var paths_root := Node2D.new()
	paths_root.name = "Paths"
	generated_root.add_child(paths_root)

	var buildings_root := Node2D.new()
	buildings_root.name = "Buildings"
	generated_root.add_child(buildings_root)

	var props_root := Node2D.new()
	props_root.name = "Props"
	generated_root.add_child(props_root)

	var collisions_root := Node2D.new()
	collisions_root.name = "Collisions"
	generated_root.add_child(collisions_root)

	_build_village_paths(paths_root)
	_build_border_colliders(collisions_root, island_world)
	_build_houses(buildings_root, props_root)
	_build_plaza_props(props_root)

	player.position = Vector2(46 * TILE_SIZE, 33 * TILE_SIZE)
	_configure_player_camera(player, island_world)


func _cache_map_textures() -> void:
	if path_tile_texture != null:
		return

	path_tile_texture = _make_atlas_texture(STREET_TEXTURE, PATH_TILE_REGION)
	blacksmith_house_texture = _make_clean_texture(
		HOUSE_EXTERIOR_TEXTURE,
		BLACKSMITH_HOUSE_REGION,
		[
			Rect2i(0, 0, 22, 14),
		]
	)
	plain_house_texture = _make_clean_texture(
		HOUSE_EXTERIOR_TEXTURE,
		PLAIN_HOUSE_REGION,
		[
			Rect2i(0, 0, 18, 10),
		]
	)
	wall_full_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, WALL_FULL_REGION)
	roof_left_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, ROOF_LEFT_REGION)
	roof_right_texture = _make_clean_texture(
		HOUSE_EXTERIOR_TEXTURE,
		ROOF_RIGHT_REGION,
		[
			Rect2i(0, 0, 14, 18),
		]
	)
	porch_small_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, PORCH_SMALL_REGION)
	porch_large_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, PORCH_LARGE_REGION)
	cart_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, CART_REGION)
	coal_cart_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, COAL_CART_REGION)
	wood_sign_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, WOOD_SIGN_REGION)
	red_awning_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, RED_AWNING_REGION)
	blue_awning_texture = _make_atlas_texture(HOUSE_EXTERIOR_TEXTURE, BLUE_AWNING_REGION)
	crate_stack_texture = _make_atlas_texture(OBJECTS_TEXTURE, CRATE_STACK_REGION)
	barrel_stack_texture = _make_atlas_texture(OBJECTS_TEXTURE, BARREL_STACK_REGION)
	sacks_texture = _make_atlas_texture(OBJECTS_TEXTURE, SACKS_REGION)


func _make_atlas_texture(atlas: Texture2D, region: Rect2i) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(region.position, region.size)
	return texture


func _make_clean_texture(atlas: Texture2D, region: Rect2i, clear_rects: Array = []) -> Texture2D:
	var atlas_image := atlas.get_image()
	var image := atlas_image.get_region(region)

	for clear_rect_variant in clear_rects:
		var clear_rect: Rect2i = clear_rect_variant
		_clear_image_rect(image, clear_rect)

	return ImageTexture.create_from_image(image)


func _clear_image_rect(image: Image, rect: Rect2i) -> void:
	var start_x := clampi(rect.position.x, 0, image.get_width())
	var start_y := clampi(rect.position.y, 0, image.get_height())
	var end_x := clampi(rect.position.x + rect.size.x, 0, image.get_width())
	var end_y := clampi(rect.position.y + rect.size.y, 0, image.get_height())

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			image.set_pixel(x, y, Color(0, 0, 0, 0))


func _rebuild_generated_root(player: Node2D) -> Node2D:
	var existing := get_node_or_null("GeneratedWorld") as Node2D
	if existing != null:
		existing.free()

	var generated_root := Node2D.new()
	generated_root.name = "GeneratedWorld"
	add_child(generated_root)
	move_child(generated_root, player.get_index())
	return generated_root


func _build_village_paths(paths_root: Node2D) -> void:
	var path_rects := [
		Rect2i(36, 28, 18, 8),
		Rect2i(44, 15, 4, 13),
		Rect2i(20, 18, 24, 4),
		Rect2i(48, 18, 26, 4),
		Rect2i(44, 36, 4, 12),
		Rect2i(24, 45, 20, 4),
		Rect2i(48, 45, 20, 4),
	]

	for rect in path_rects:
		_paint_path_rect(paths_root, rect)


func _paint_path_rect(paths_root: Node2D, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_add_sprite(paths_root, path_tile_texture, Vector2(x * TILE_SIZE, y * TILE_SIZE))


func _build_border_colliders(collisions_root: Node2D, island_world: Rect2) -> void:
	var bounds := StaticBody2D.new()
	bounds.name = "WaterBounds"
	collisions_root.add_child(bounds)

	var thickness := float(TILE_SIZE * 2)
	_add_rectangle_collision(
		bounds,
		Rect2(island_world.position.x, island_world.position.y - thickness, island_world.size.x, thickness)
	)
	_add_rectangle_collision(
		bounds,
		Rect2(island_world.position.x, island_world.end.y, island_world.size.x, thickness)
	)
	_add_rectangle_collision(
		bounds,
		Rect2(island_world.position.x - thickness, island_world.position.y, thickness, island_world.size.y)
	)
	_add_rectangle_collision(
		bounds,
		Rect2(island_world.end.x, island_world.position.y, thickness, island_world.size.y)
	)


func _add_rectangle_collision(body: StaticBody2D, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size

	var collision := CollisionShape2D.new()
	collision.position = rect.position + rect.size * 0.5
	collision.shape = shape
	body.add_child(collision)


func _build_houses(buildings_root: Node2D, props_root: Node2D) -> void:
	_add_building(
		buildings_root,
		props_root,
		"CasaHerreria",
		Vector2(11 * TILE_SIZE, 9 * TILE_SIZE),
		Rect2(18, 92, 102, 42),
		[
			{"texture": blacksmith_house_texture, "position": Vector2.ZERO},
		],
		[
			{"texture": wood_sign_texture, "position": Vector2(126, 86), "scale": Vector2(0.72, 0.72)},
			{"texture": barrel_stack_texture, "position": Vector2(122, 114), "scale": Vector2(0.82, 0.82)},
			{"texture": crate_stack_texture, "position": Vector2(-18, 114), "scale": Vector2(0.72, 0.72)},
		],
	)

	_add_building(
		buildings_root,
		props_root,
		"CasaCentral",
		Vector2(39 * TILE_SIZE, 10 * TILE_SIZE),
		Rect2(16, 80, 86, 42),
		[
			{"texture": plain_house_texture, "position": Vector2.ZERO},
		],
		[
			{"texture": crate_stack_texture, "position": Vector2(96, 98), "scale": Vector2(0.78, 0.78)},
			{"texture": wood_sign_texture, "position": Vector2(-12, 76), "scale": Vector2(0.64, 0.64)},
			{"texture": sacks_texture, "position": Vector2(18, 112)},
		],
	)

	_add_building(
		buildings_root,
		props_root,
		"CasaMercado",
		Vector2(59 * TILE_SIZE, 7 * TILE_SIZE),
		Rect2(30, 112, 76, 42),
		[
			{"texture": wall_full_texture, "position": Vector2(18, 76)},
			{"texture": roof_left_texture, "position": Vector2(24, 0)},
			{"texture": porch_large_texture, "position": Vector2(48, 145)},
		],
		[
			{"texture": red_awning_texture, "position": Vector2(10, 116), "scale": Vector2(0.72, 0.72)},
			{"texture": blue_awning_texture, "position": Vector2(58, 116), "scale": Vector2(0.72, 0.72)},
			{"texture": sacks_texture, "position": Vector2(58, 146)},
			{"texture": crate_stack_texture, "position": Vector2(110, 116), "scale": Vector2(0.78, 0.78)},
		],
	)

	_add_building(
		buildings_root,
		props_root,
		"CasaCampo",
		Vector2(18 * TILE_SIZE, 33 * TILE_SIZE),
		Rect2(28, 112, 74, 42),
		[
			{"texture": wall_full_texture, "position": Vector2(16, 76)},
			{"texture": roof_right_texture, "position": Vector2(24, 0)},
			{"texture": porch_small_texture, "position": Vector2(46, 145)},
		],
		[
			{"texture": cart_texture, "position": Vector2(92, 124), "scale": Vector2(0.84, 0.84)},
			{"texture": sacks_texture, "position": Vector2(0, 148)},
			{"texture": wood_sign_texture, "position": Vector2(-16, 100), "scale": Vector2(0.62, 0.62)},
		],
	)

	_add_building(
		buildings_root,
		props_root,
		"CasaAlmacen",
		Vector2(58 * TILE_SIZE, 36 * TILE_SIZE),
		Rect2(16, 80, 86, 42),
		[
			{"texture": plain_house_texture, "position": Vector2.ZERO, "flip_h": true},
		],
		[
			{"texture": barrel_stack_texture, "position": Vector2(-22, 102), "scale": Vector2(0.82, 0.82)},
			{"texture": crate_stack_texture, "position": Vector2(94, 104), "scale": Vector2(0.82, 0.82)},
			{"texture": wood_sign_texture, "position": Vector2(102, 78), "scale": Vector2(0.68, 0.68)},
		],
	)


func _add_building(
	buildings_root: Node2D,
	props_root: Node2D,
	house_name: String,
	top_left: Vector2,
	collision_rect: Rect2,
	building_parts: Array,
	front_props: Array = []
) -> void:
	var house_root := Node2D.new()
	house_root.name = house_name
	house_root.position = top_left
	buildings_root.add_child(house_root)

	for part_data in building_parts:
		if not part_data.has("texture"):
			continue

		var part_texture := part_data["texture"] as Texture2D
		if part_texture == null:
			continue

		var part_position: Vector2 = part_data.get("position", Vector2.ZERO)
		var part_flip_h := bool(part_data.get("flip_h", false))
		var part_scale: Vector2 = part_data.get("scale", Vector2.ONE)
		_add_sprite(house_root, part_texture, part_position, part_flip_h, part_scale)

	var body := StaticBody2D.new()
	body.name = "Collision"
	house_root.add_child(body)
	_add_rectangle_collision(body, collision_rect)

	for prop_data in front_props:
		if not prop_data.has("texture") or not prop_data.has("position"):
			continue

		var prop_texture := prop_data["texture"] as Texture2D
		if prop_texture == null:
			continue

		var prop_position: Vector2 = prop_data["position"]
		var prop_flip_h := bool(prop_data.get("flip_h", false))
		var prop_scale: Vector2 = prop_data.get("scale", Vector2.ONE)
		_add_sprite(props_root, prop_texture, top_left + prop_position, prop_flip_h, prop_scale)


func _build_plaza_props(props_root: Node2D) -> void:
	_add_sprite(props_root, wood_sign_texture, Vector2(31 * TILE_SIZE, 27 * TILE_SIZE))
	_add_sprite(props_root, wood_sign_texture, Vector2(65 * TILE_SIZE, 27 * TILE_SIZE), true)
	_add_sprite(props_root, crate_stack_texture, Vector2(40 * TILE_SIZE, 32 * TILE_SIZE))
	_add_sprite(props_root, barrel_stack_texture, Vector2(51 * TILE_SIZE, 32 * TILE_SIZE))
	_add_sprite(props_root, sacks_texture, Vector2(45 * TILE_SIZE, 36 * TILE_SIZE))
	_add_sprite(props_root, coal_cart_texture, Vector2(70 * TILE_SIZE, 44 * TILE_SIZE))
	_add_sprite(props_root, cart_texture, Vector2(28 * TILE_SIZE, 44 * TILE_SIZE))


func _add_sprite(
	parent: Node2D,
	texture: Texture2D,
	position: Vector2,
	flip_h: bool = false,
	scale: Vector2 = Vector2.ONE
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = position
	sprite.flip_h = flip_h
	sprite.scale = scale
	parent.add_child(sprite)
	return sprite


func _configure_player_camera(player: Node2D, island_world: Rect2) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = int(island_world.position.x)
	camera.limit_top = int(island_world.position.y)
	camera.limit_right = int(island_world.end.x)
	camera.limit_bottom = int(island_world.end.y)


func _fill_layer_rect(layer: TileMapLayer, rect: Rect2i, tile: Dictionary) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_layer_cell(layer, Vector2i(x, y), tile)


func _fill_ground_with_variations(layer: TileMapLayer, rect: Rect2i, tiles: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_layer_cell(layer, Vector2i(x, y), _pick_weighted_tile(tiles, rng))


func _set_layer_cell(layer: TileMapLayer, cell: Vector2i, tile: Dictionary) -> void:
	if tile.is_empty():
		return

	var source_id := int(tile["source_id"])
	var atlas_coords: Vector2i = tile["atlas_coords"]
	var alternative_tile := int(tile["alternative_tile"])
	layer.set_cell(cell, source_id, atlas_coords, alternative_tile)


func _pick_weighted_tile(tiles: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if tiles.is_empty():
		return {}
	if tiles.size() == 1:
		return tiles[0]

	var total_weight := 0
	for tile in tiles:
		total_weight += int(tile["count"])

	var roll := rng.randi_range(1, max(total_weight, 1))
	var running_weight := 0
	for tile in tiles:
		running_weight += int(tile["count"])
		if roll <= running_weight:
			return tile

	return tiles[0]


func _most_common_tile(layer: TileMapLayer) -> Dictionary:
	var tiles := _collect_common_tiles(layer, 1)
	if tiles.is_empty():
		return {}
	return tiles[0]


func _collect_common_tiles(layer: TileMapLayer, limit: int) -> Array[Dictionary]:
	var counts := {}
	for cell in layer.get_used_cells():
		var source_id := layer.get_cell_source_id(cell)
		if source_id < 0:
			continue

		var atlas_coords := layer.get_cell_atlas_coords(cell)
		var alternative_tile := layer.get_cell_alternative_tile(cell)
		var key := "%d:%d:%d:%d" % [source_id, atlas_coords.x, atlas_coords.y, alternative_tile]

		if not counts.has(key):
			counts[key] = {
				"source_id": source_id,
				"atlas_coords": atlas_coords,
				"alternative_tile": alternative_tile,
				"count": 0,
			}

		counts[key]["count"] = int(counts[key]["count"]) + 1

	var tiles: Array[Dictionary] = []
	for tile_data in counts.values():
		tiles.append(tile_data)

	tiles.sort_custom(Callable(self, "_sort_tiles_by_frequency"))
	if limit > 0 and tiles.size() > limit:
		tiles.resize(limit)

	return tiles


func _sort_tiles_by_frequency(a: Dictionary, b: Dictionary) -> bool:
	return int(a["count"]) > int(b["count"])


func _get_island_cells_rect() -> Rect2i:
	return Rect2i(
		WATER_MARGIN_CELLS,
		WATER_MARGIN_CELLS,
		MAP_COLUMNS - WATER_MARGIN_CELLS * 2,
		MAP_ROWS - WATER_MARGIN_CELLS * 2
	)


func _cells_to_world_rect(rect: Rect2i) -> Rect2:
	return Rect2(
		Vector2(rect.position.x * TILE_SIZE, rect.position.y * TILE_SIZE),
		Vector2(rect.size.x * TILE_SIZE, rect.size.y * TILE_SIZE)
	)


func _spawn_demo_pickups() -> void:
	var player := get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return

	_spawn_single_pickup("PickupEstrellaDemo", STAR_ITEM_DATA, 20, player.position + Vector2(64, -12))
	_spawn_single_pickup("PickupMonedaDemo", COIN_ITEM_DATA, 9, player.position + Vector2(112, 18))


func _spawn_single_pickup(pickup_name: String, item_data: ItemData, amount: int, world_position: Vector2) -> void:
	if has_node(NodePath(pickup_name)):
		return

	var pickup := PICKUP_ITEM_SCENE.instantiate()
	if pickup == null:
		return

	pickup.name = pickup_name
	if pickup is Node2D:
		(pickup as Node2D).position = world_position

	add_child(pickup)

	if pickup.has_method("configure_pickup"):
		pickup.call("configure_pickup", item_data, amount)
	else:
		pickup.set("item_data", item_data)
		pickup.set("amount", amount)


func _close_player_inventory_if_open() -> bool:
	var player := get_node_or_null(PLAYER_NODE_PATH)
	if player == null:
		return false

	if player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		if player.has_method("close_inventory"):
			player.call("close_inventory")
		return true

	return false


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		)

	return false
