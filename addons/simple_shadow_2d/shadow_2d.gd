@tool
class_name Shadow2D
extends Node2D
## Node that provides simple 2D eliptical shadow.
##
## Place under a Node2D actor. Tune width, height, offset, and color in the inspector.


#region Properties
## Minimum shadow size in pixels.
const MIN_SHADOW_SIZE: int = 1

## Shared texture cache keyed by shadow configuration.
static var _shared_textures := {}

## Width of the shadow ellipse in pixels.
@export var width: float = 32.0: set = _set_width
## Height of the shadow ellipse in pixels.
@export var height: float = 16.0: set = _set_height
## Offset from the parent actor position in pixels.
@export var offset := Vector2(0, 8): set = _set_offset
## Shadow tint and base opacity.
@export var color := Color(0, 0, 0, 0.5): set = _set_color
## Layer count for stepped shadows (1 uses a single layer).
@export_range(1, 16, 1) var shadow_steps: int = 1: set = _set_shadow_steps
## Edge softness from 0.0 (sharp) to 1.0 (fully smooth).
@export_range(0.0, 1.0, 0.01) var smoothing_amount: float = 0.0: set = _set_smoothing_amount
## Alpha multiplier applied per shadow step layer.
@export_range(0.0, 1.0, 0.01) var step_falloff: float = 0.3: set = _set_step_falloff

var _texture: ImageTexture
var _suppress_refresh: bool = false
#endregion


## Sets draw order and parent behavior, then builds the first shadow texture.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0
	z_as_relative = true
	y_sort_enabled = false
	show_behind_parent = true
	_refresh()


## Draws the shadow texture centered on the configured offset.
func _draw() -> void:
	if not _texture: return
	draw_texture(_texture, offset - _texture.get_size() / 2.0)


## Assigns width and refreshes the shadow when the node is in the tree.
func _set_width(value: float) -> void:
	width = value
	if is_inside_tree() and not _suppress_refresh: _refresh()


## Assigns height and refreshes the shadow when the node is in the tree.
func _set_height(value: float) -> void:
	height = value
	if is_inside_tree() and not _suppress_refresh: _refresh()


## Assigns offset and refreshes the shadow when the node is in the tree.
func _set_offset(value: Vector2) -> void:
	offset = value
	if is_inside_tree() and not _suppress_refresh: _refresh()


## Assigns color and refreshes the shadow when the node is in the tree.
func _set_color(value: Color) -> void:
	color = value
	if is_inside_tree(): _refresh()


## Assigns shadow step count and refreshes the shadow when the node is in the tree.
func _set_shadow_steps(value: int) -> void:
	shadow_steps = value
	if is_inside_tree(): _refresh()


## Assigns edge smoothing and refreshes the shadow when the node is in the tree.
func _set_smoothing_amount(value: float) -> void:
	smoothing_amount = value
	if is_inside_tree(): _refresh()


## Assigns step falloff and refreshes the shadow when the node is in the tree.
func _set_step_falloff(value: float) -> void:
	step_falloff = value
	if is_inside_tree(): _refresh()


## Rebuilds the shadow texture and queues a redraw.
func _refresh() -> void:
	_texture = _get_or_create_texture()
	queue_redraw()


## Sets width, height, and offset together in one refresh pass.
func apply_dimensions(new_width: float, new_height: float, new_offset: Vector2) -> void:
	_suppress_refresh = true
	width = new_width
	height = new_height
	offset = new_offset
	_suppress_refresh = false
	if is_inside_tree(): _refresh()


## Returns a shadow texture built from the current property values.
func create_texture() -> ImageTexture:
	return _get_or_create_texture()


## Builds the cache key string for the current shadow settings.
func _texture_cache_key() -> String:
	return "%d|%d|%d|%d|%d|%08x" % [
		maxi(MIN_SHADOW_SIZE, int(width)),
		maxi(MIN_SHADOW_SIZE, int(height)),
		shadow_steps,
		int(smoothing_amount * 1000.0),
		int(step_falloff * 1000.0),
		color.to_rgba32(),
	]


## Returns a cached or newly generated shadow texture for the current settings.
func _get_or_create_texture() -> ImageTexture:
	var key := _texture_cache_key()
	if _shared_textures.has(key):
		return _shared_textures[key]

	var w: int = maxi(MIN_SHADOW_SIZE, int(width))
	var h: int = maxi(MIN_SHADOW_SIZE, int(height))
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx: float = w / 2.0
	var cy: float = h / 2.0
	var rx: float = (w / 2.0) - 0.5
	var ry: float = (h / 2.0) - 0.5

	for py: int in range(h):
		for px: int in range(w):
			var dx: float = (px - cx) / rx
			var dy: float = (py - cy) / ry
			var distance: float = dx * dx + dy * dy
			if distance < 1.0:
				var alpha: float = _calculate_shadow_alpha(distance)
				var final_color := Color(color.r, color.g, color.b, alpha)
				image.set_pixel(px, py, final_color)

	var texture := ImageTexture.create_from_image(image)
	_shared_textures[key] = texture
	return texture


## Returns the alpha value for a normalized distance from the shadow center.
func _calculate_shadow_alpha(distance: float) -> float:
	var alpha: float = color.a
	var gradient_value: float = 1.0 - distance

	if shadow_steps > 1:
		alpha *= _apply_stepped_gradient(distance)

	if smoothing_amount > 0.0:
		alpha *= clampf(gradient_value / smoothing_amount, 0.0, 1.0)

	return alpha


## Returns the alpha multiplier for a stepped gradient band at the given distance.
func _apply_stepped_gradient(distance: float) -> float:
	var step_size: float = 1.0 / float(shadow_steps)
	var step_index: float = distance / step_size
	var current_step: int = int(floor(step_index))
	var next_step: int = current_step + 1
	var current_step_alpha: float = 1.0 - (float(current_step) * step_size * step_falloff)
	var next_step_alpha: float = 1.0 - (float(next_step) * step_size * step_falloff)

	if smoothing_amount > 0.0:
		var step_fraction: float = fposmod(step_index, 1.0)
		var smooth_factor: float = clampf(step_fraction / smoothing_amount, 0.0, 1.0)
		return lerpf(current_step_alpha, next_step_alpha, smooth_factor)

	return current_step_alpha
