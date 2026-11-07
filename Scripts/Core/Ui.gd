class_name Ui
extends RefCounted
## Shared toybox UI kit: colours, panels, buttons and text helpers.

const INK := Color("#f4f8ff")
const MUTED := Color("#9fb0c8")
const DIM := Color("#5f7088")
const GOLD := Color("#ffd166")
const MINT := Color("#7fe4c8")
const SKY := Color("#7cc6ff")
const PANEL := Color("#101a2a")
const PANEL_HI := Color("#16243a")
const DANGER := Color("#ff6b6b")
const NIGHT := Color("#070c16")


## Labels wrap only when asked: a wrapping label inside a tight row shrinks
## until every character gets its own line, which is exactly what the HUD
## bars and the result grids must never do.
static func label(text: String, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = align
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return node


static func box(color: Color, radius := 20, border := Color.TRANSPARENT, pad := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if border.a > 0.0:
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = border
	return style


static func button(text: String, size: int, height: int, color: Color, on_press: Callable,
		text_color := Color("#07131a"), pad := 16) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", text_color)
	node.add_theme_color_override("font_hover_color", text_color)
	node.add_theme_color_override("font_pressed_color", text_color)
	node.add_theme_color_override("font_disabled_color", DIM)
	node.add_theme_stylebox_override("normal", box(color, 18, Color.TRANSPARENT, pad))
	node.add_theme_stylebox_override("hover", box(color.lightened(0.08), 18, Color.TRANSPARENT, pad))
	node.add_theme_stylebox_override("pressed", box(color.darkened(0.12), 18, Color.TRANSPARENT, pad))
	node.add_theme_stylebox_override("disabled", box(Color("#1a2434"), 18, Color.TRANSPARENT, pad))
	node.pressed.connect(func() -> void:
		Audio.ui_click()
		on_press.call())
	return node


static func ghost(text: String, on_press: Callable, height := 64, size := 20, pad := 14) -> Button:
	var node := button(text, size, height, Color("#1b2a40"), on_press, INK, pad)
	node.add_theme_stylebox_override("normal", box(Color("#141f31"), 18, Color("#2a3d59"), pad))
	node.add_theme_stylebox_override("hover", box(Color("#1a273c"), 18, Color("#3d5578"), pad))
	node.add_theme_stylebox_override("pressed", box(Color("#101a2a"), 18, Color("#3d5578"), pad))
	node.add_theme_stylebox_override("disabled", box(Color("#101623"), 18, Color("#1c2739"), pad))
	return node


static func panel(color := PANEL, radius := 22, border := Color.TRANSPARENT, pad := 16) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(color, radius, border, pad))
	return node


static func spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	return node


static func row(gap := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func column(gap := 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func format_number(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


## The bundled default font has no star glyphs, so earned stars are asterisks
## and missing ones are dashes: "***", "**-", "*--", "---".
static func stars_text(stars: int, total := 3) -> String:
	var out := ""
	for i in range(total):
		out += "*" if i < stars else "-"
	return out


static func ordinal(value: int) -> String:
	var suffix := "th"
	if value % 100 < 11 or value % 100 > 13:
		match value % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [value, suffix]


static func gradient_texture(from: Color, to: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.15, 0.0)
	texture.fill_to = Vector2(0.85, 1.0)
	texture.width = 8
	texture.height = 256
	return texture


static func backdrop(from: Color, to: Color) -> TextureRect:
	var node := TextureRect.new()
	node.texture = gradient_texture(from, to)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	return node


static func scroll() -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node
