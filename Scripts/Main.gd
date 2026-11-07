extends Node
## App shell: title, journey map, level select, battle HUD, results and codex.
## The rules live in `Battlefield` and the diorama in `BattleView`; this script
## owns navigation, touch input, presentation of state and persistence.

const STAR_SPEC := "3 stars: take no damage.  2 stars: keep at least 80% of the heart."

var _ui: CanvasLayer
var _screen_root: Control
var _screen := "title"
var _map: JourneyMap
var _view: BattleView
var _sim: Battlefield

var _mode := "campaign"
var _level_id := 1
var _kingdom := 0
var _paused := false
var _result_open := false
var _result_guard := false
var _session_start := 0.0
var _publish_timer := 0.0
var _tap_guard := 0.0

var _lives_label: Label
var _gold_label: Label
var _wave_label: Label
var _title_label: Label
var _boss_panel: PanelContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _toast_label: Label
var _toast_tween: Tween
var _shelf_scroll: ScrollContainer
var _shelf: HBoxContainer
var _shelf_buttons: Dictionary = {}
var _panel: VBoxContainer
var _panel_holder: PanelContainer
var _wave_button: Button
var _hint: Label

var _build_id := ""
var _selected := -1
var _run_kills := 0
var _run_credits := 0
var _kills_at_start := 0
var _credits_at_start := 0
var _reset_armed := false
var _map_stamp := -1


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_toast_label = Ui.label("", 17, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_label.offset_left = 24
	_toast_label.offset_right = -24
	_toast_label.offset_top = 150
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_color_override("font_outline_color", Color("#04101c"))
	_toast_label.add_theme_constant_override("outline_size", 8)
	_toast_label.modulate.a = 0.0
	_ui.add_child(_toast_label)
	_map = JourneyMap.new()
	_map.name = "JourneyMap"
	add_child(_map)
	_refresh_map(1.0)
	Save.achievement_unlocked.connect(_on_achievement)
	Arcade.identity_changed.connect(_refresh_account_labels)
	Audio.play_music("menu")
	_show_title()
	_session_start = Time.get_ticks_msec() / 1000.0
	if OS.has_feature("web"):
		_maybe_autostart()


func _maybe_autostart() -> void:
	var query: Variant = JavaScriptBridge.eval(
		"typeof location !== 'undefined' ? location.search : ''", true)
	var search := String(query) if query != null else ""
	if not search.contains("autostart"):
		return
	if search.contains("mode=endless"):
		_start_battle("endless", 1)
	elif search.contains("mode=survival"):
		_start_battle("survival", 1)
	else:
		var level := 1
		var match_id := search.find("level=")
		if match_id >= 0:
			var tail := search.substr(match_id + 6)
			var digits := ""
			for i in range(tail.length()):
				var ch := tail[i]
				if ch >= "0" and ch <= "9":
					digits += ch
				else:
					break
			level = maxi(1, int(digits))
		_start_battle("campaign", level)


func _process(delta: float) -> void:
	if _screen == "battle" and _sim != null:
		_tick_battle(delta)
	_publish_timer += delta
	if _publish_timer >= 0.3:
		_publish_timer = 0.0
		_publish_state()
		if OS.has_feature("web"):
			_poll_debug()
	_tap_guard = maxf(0.0, _tap_guard - delta)


func _publish_state() -> void:
	if not OS.has_feature("web"):
		return
	var payload := {
		"screen": _screen,
		"mode": _mode,
		"phase": _sim.phase if _sim != null else "none",
		"wave": _sim.wave_index if _sim != null else 0,
		"cleared": _sim.waves_cleared if _sim != null else 0,
		"gold": _sim.gold if _sim != null else 0,
		"lives": _sim.lives if _sim != null else 0,
		"towers": _sim.towers.size() if _sim != null else 0,
		"enemies": _sim.enemies.size() if _sim != null else 0,
		"stars": Save.total_stars(),
		"level": _level_id,
		"result": _result_open,
	}
	var literal := JSON.stringify(JSON.stringify(payload))
	JavaScriptBridge.eval("window.__wonderguardState = %s" % literal, true)


## A tiny development hook used by the browser smoke test. It only exists in
## the web build and only runs one of a fixed list of commands.
func _poll_debug() -> void:
	var raw: Variant = JavaScriptBridge.eval("window.__wonderguardCommand || ''", true)
	var command := String(raw) if raw != null else ""
	if command.is_empty():
		return
	JavaScriptBridge.eval("window.__wonderguardCommand = ''", true)
	var parts := command.split(":")
	match parts[0]:
		"start":
			var target_mode := parts[1] if parts.size() > 1 else "campaign"
			var target_level := int(parts[2]) if parts.size() > 2 else 1
			_start_battle(target_mode, target_level)
		"build":
			if _sim != null and parts.size() > 1:
				_debug_build(parts[1])
		"wave":
			if _sim != null:
				_sim.next_wave_early()
		"advance":
			if _sim != null and parts.size() > 1:
				var seconds := float(parts[1])
				var steps := int(seconds / 0.05)
				for i in range(steps):
					_sim.advance(0.05)
		"select":
			if _sim != null and parts.size() > 1:
				_open_tower(int(parts[1]))


func _debug_build(tower_id: String) -> void:
	if _sim == null or not Towers.has(tower_id):
		return
	var best := Vector2i(-1, -1)
	var best_score := INF
	var path: Array = _sim.level.get("path", [])
	for entry in _sim.level.get("sockets", []):
		var cell: Vector2i = entry
		if _sim.tower_at(cell) >= 0:
			continue
		var score := 0.0
		for path_cell in path:
			score += float(absi((path_cell as Vector2i).x - cell.x) + absi((path_cell as Vector2i).y - cell.y))
		score /= maxf(1.0, float(path.size()))
		if score < best_score:
			best_score = score
			best = cell
	if best.x >= 0 and _sim.build(best, tower_id):
		_view.set_build_mode(true, tower_id)
		_refresh_shelf()


# --------------------------------------------------------------------------
# screen plumbing
# --------------------------------------------------------------------------

func _clear(background := true) -> Control:
	if _screen_root != null and is_instance_valid(_screen_root):
		_screen_root.queue_free()
	_screen_root = Control.new()
	_screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui.add_child(_screen_root)
	if background:
		_screen_root.add_child(Ui.backdrop(Color("#12223a"), Color("#05080f")))
	return _screen_root


func _scrim(top_alpha := 0.6, bottom_alpha := 0.85) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.03, 0.06, top_alpha))
	gradient.set_color(1, Color(0.02, 0.03, 0.06, bottom_alpha))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 256
	var node := TextureRect.new()
	node.texture = texture
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	return node


func _margins(root: Control, amount := 16) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount + 8)
	margin.add_theme_constant_override("margin_bottom", amount)
	root.add_child(margin)
	return margin


## The kingdom map is rebuilt when the frontier moves; between screens the
## existing islands are simply re-framed, which keeps back-and-forth cheap.
func _refresh_map(framing: float) -> void:
	if _map == null:
		return
	var highest := Save.highest_kingdom()
	if _map_stamp != highest:
		_map.build(highest, highest)
		_map_stamp = highest
	_map.set_framing(framing)
	_map.focus(highest)
	_map.make_current()


func _teardown_battle() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_sim = null
	_selected = -1
	_build_id = ""
	_paused = false
	_result_open = false
	_result_guard = false


func _header(title: String, subtitle := "", back := "") -> HBoxContainer:
	var row_node := Ui.row(10)
	var left := Ui.column(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if back != "":
		var back_button := Ui.ghost("← " + back, func() -> void: _show_title(), 54, 18, 12)
		back_button.custom_minimum_size.x = 120
		row_node.add_child(back_button)
	left.add_child(Ui.label(title, 34))
	if subtitle != "":
		left.add_child(Ui.label(subtitle, 16, Ui.MUTED))
	row_node.add_child(left)
	return row_node


# --------------------------------------------------------------------------
# title
# --------------------------------------------------------------------------

func _show_title() -> void:
	_screen = "title"
	_teardown_battle()
	_map.visible = true
	_refresh_map(1.9)
	Audio.play_music("menu")
	var root := _clear(false)
	root.add_child(_scrim(0.55, 0.94))
	var margin := _margins(root, 18)
	var outer := Ui.column(10)
	margin.add_child(outer)

	var title := Ui.column(2)
	title.add_child(Ui.label("WONDERGUARD", 52, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER))
	title.add_child(Ui.label("3 D", 44, Ui.MINT, HORIZONTAL_ALIGNMENT_CENTER))
	title.add_child(Ui.label("The toybox kingdom is under siege.", 17, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	outer.add_child(title)

	var chips := Ui.row(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_child(_chip("%d stars" % Save.total_stars()))
	chips.add_child(_chip("%d trophies" % Save.trophy_count()))
	chips.add_child(_chip("%d crowns" % Save.credits()))
	outer.add_child(chips)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(spacer)

	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Ui.box(Color("#0a1322").lerp(Color("#0d1a2b"), 0.5), 26, Color("#243a56"), 14))
	outer.add_child(sheet)

	var sheet_col := Ui.column(10)
	sheet.add_child(sheet_col)

	var next_id := Save.next_level()
	var next_kingdom := Campaign.kingdom_index(next_id)
	var continue_button := Ui.button("CONTINUE JOURNEY  ·  %s %02d" % [String(Campaign.KINGDOMS[next_kingdom]["short"]), Campaign.local_level(next_id)],
			24, 78, Ui.MINT, func() -> void: _start_battle("campaign", next_id), Color("#06201a"))
	sheet_col.add_child(continue_button)

	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 8)
	modes.add_theme_constant_override("v_separation", 8)
	sheet_col.add_child(modes)
	modes.add_child(Ui.ghost("Kingdom Map", func() -> void: _show_kingdoms(), 62, 20))
	modes.add_child(Ui.ghost("Endless Siege", func() -> void: _start_battle("endless", 1), 62, 20))
	modes.add_child(Ui.ghost("Daily Defense", func() -> void: _start_battle("daily", 1), 62, 20))
	modes.add_child(Ui.ghost("Boss Rush", func() -> void: _start_battle("bossrush", 1), 62, 20))
	modes.add_child(Ui.ghost("Survival", func() -> void: _start_battle("survival", 1), 62, 20))
	modes.add_child(Ui.ghost("Sandbox", func() -> void: _start_battle("sandbox", 1), 62, 20))
	modes.add_child(Ui.ghost("Tower Codex", func() -> void: _show_codex(), 62, 20))
	modes.add_child(Ui.ghost("Bestiary", func() -> void: _show_bestiary(), 62, 20))
	modes.add_child(Ui.ghost("Trophies", func() -> void: _show_trophies(), 62, 20))
	modes.add_child(Ui.ghost("Settings", func() -> void: _show_settings(), 62, 20))

	var account := PanelContainer.new()
	account.add_theme_stylebox_override("panel", Ui.box(Color("#0e1a2b"), 16, Color("#22344d"), 12))
	sheet_col.add_child(account)
	var account_row := Ui.row(8)
	account.add_child(account_row)
	var account_col := Ui.column(0)
	account_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_col.add_child(Ui.label(Arcade.status_text(), 15, Ui.MUTED))
	account_col.add_child(Ui.label("Progress saves on this device and syncs when signed in.", 13, Ui.DIM))
	account_row.add_child(account_col)
	var sign_action := func() -> void:
		if Arcade.signed_in:
			Arcade.open_arcade()
		else:
			Arcade.sign_in()
	var sign_button := Ui.ghost("Sign in" if not Arcade.signed_in else "Account", sign_action, 52, 16, 12)
	sign_button.name = "AccountButton"
	account_row.add_child(sign_button)

	var footer := Ui.label("A Little Joy Arcade original  ·  v1.0.0", 12, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sheet_col.add_child(footer)


func _chip(text: String) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", Ui.box(Color("#0e1a2b"), 14, Color("#22344d"), 10))
	node.add_child(Ui.label(text, 15, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER))
	return node


func _refresh_account_labels() -> void:
	if _screen != "title" or _screen_root == null:
		return
	var button := _screen_root.find_child("AccountButton", true, false) as Button
	if button != null:
		button.text = "Sign in" if not Arcade.signed_in else "Account"
	_toast(Arcade.status_text())


# --------------------------------------------------------------------------
# kingdoms and levels
# --------------------------------------------------------------------------

func _show_kingdoms() -> void:
	_screen = "kingdoms"
	_teardown_battle()
	_map.visible = true
	_refresh_map(1.5)
	Audio.play_music("menu")
	var root := _clear(false)
	root.add_child(_scrim(0.25, 0.96))
	var margin := _margins(root, 16)
	var outer := Ui.column(8)
	margin.add_child(outer)
	outer.add_child(_header("Journey Map", "Twenty kingdoms, one long road home.", "Back"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(spacer)

	var sheet := Ui.panel(Color("#0a1322"), 26, Color("#243a56"), 12)
	sheet.custom_minimum_size.y = 620
	outer.add_child(sheet)
	var sheet_col := Ui.column(8)
	sheet.add_child(sheet_col)
	sheet_col.add_child(Ui.label("Choose a kingdom", 22, Ui.INK))
	var scroll := Ui.scroll()
	scroll.custom_minimum_size.y = 540
	sheet_col.add_child(scroll)
	var list := Ui.column(8)
	scroll.add_child(list)
	for i in range(Campaign.KINGDOM_COUNT):
		var kingdom: Dictionary = Campaign.KINGDOMS[i]
		var open := Save.is_kingdom_unlocked(i)
		var cleared := Save.completed_in_kingdom(i)
		var stars := Save.stars_in_kingdom(i)
		var row_button := Button.new()
		row_button.custom_minimum_size.y = 74
		row_button.disabled = not open
		row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_button.add_theme_font_size_override("font_size", 19)
		row_button.text = "%2d   %s\n%s" % [i + 1, String(kingdom["name"]),
				("%d/50 cleared  ·  ★ %d/150" % [cleared, stars]) if open else "Locked · clear six levels in the previous kingdom"]
		row_button.add_theme_color_override("font_color", Ui.INK if open else Ui.DIM)
		row_button.add_theme_color_override("font_hover_color", Ui.INK)
		row_button.add_theme_color_override("font_pressed_color", Ui.INK)
		var tint := Color(String(kingdom["from"]))
		row_button.add_theme_stylebox_override("normal", Ui.box(Color("#101d2e").lerp(tint, 0.18), 16, Color("#22344d"), 14))
		row_button.add_theme_stylebox_override("hover", Ui.box(Color("#16273c").lerp(tint, 0.24), 16, Color("#3d5578"), 14))
		row_button.add_theme_stylebox_override("pressed", Ui.box(Color("#0c1622"), 16, Color("#3d5578"), 14))
		row_button.add_theme_stylebox_override("disabled", Ui.box(Color("#0b1220"), 16, Color("#1b2739"), 14))
		row_button.pressed.connect(func() -> void:
			Audio.ui_click()
			_show_levels(i))
		list.add_child(row_button)


func _show_levels(index: int) -> void:
	_kingdom = clampi(index, 0, Campaign.KINGDOM_COUNT - 1)
	_screen = "levels"
	_teardown_battle()
	_map.visible = false
	var kingdom: Dictionary = Campaign.KINGDOMS[_kingdom]
	var from := Color(String(kingdom["from"]))
	var to := Color(String(kingdom["to"]))
	Audio.play_music("menu")
	var root := _clear(false)
	root.add_child(Ui.backdrop(from.darkened(0.35), to))
	root.add_child(_scrim(0.15, 0.8))
	var margin := _margins(root, 16)
	var outer := Ui.column(8)
	margin.add_child(outer)

	var head := Ui.row(8)
	var back := Ui.ghost("← Map", func() -> void: _show_kingdoms(), 52, 16, 12)
	back.custom_minimum_size.x = 108
	head.add_child(back)
	var head_col := Ui.column(0)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_child(Ui.label(String(kingdom["name"]), 30))
	head_col.add_child(Ui.label(String(kingdom["tagline"]), 14, Ui.MUTED))
	head.add_child(head_col)
	outer.add_child(head)

	outer.add_child(Ui.label("★ %d / 150   ·   %d / 50 cleared" % [Save.stars_in_kingdom(_kingdom), Save.completed_in_kingdom(_kingdom)], 16, Ui.GOLD))

	var scroll := Ui.scroll()
	outer.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var first := _kingdom * Campaign.LEVELS_PER_KINGDOM + 1
	for local in range(1, Campaign.LEVELS_PER_KINGDOM + 1):
		var id := first + local - 1
		var stars := Save.level_stars(id)
		var boss := Campaign.is_boss_level(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		button.text = "%02d\n%s" % [local, "BOSS" if boss else Ui.stars_text(stars)]
		button.add_theme_color_override("font_color", Color("#231a0a") if boss else Ui.INK)
		button.add_theme_color_override("font_hover_color", Ui.INK)
		button.add_theme_color_override("font_pressed_color", Ui.INK)
		var fill := Color("#1b2c42")
		if boss:
			fill = Color("#ffd166")
		elif stars > 0:
			fill = Color(String(kingdom["accent"])).darkened(0.35)
		button.add_theme_stylebox_override("normal", Ui.box(fill, 14, Color("#33496a"), 6))
		button.add_theme_stylebox_override("hover", Ui.box(fill.lightened(0.1), 14, Color("#5d7ba6"), 6))
		button.add_theme_stylebox_override("pressed", Ui.box(fill.darkened(0.15), 14, Color("#5d7ba6"), 6))
		button.pressed.connect(func() -> void:
			Audio.ui_click()
			_start_battle("campaign", id))
		grid.add_child(button)

	outer.add_child(Ui.label(STAR_SPEC, 13, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var next := Save.next_level_in_kingdom(_kingdom)
	var play := Ui.button("DEFEND  ·  %s %02d" % [String(kingdom["short"]), Campaign.local_level(next)],
			22, 74, Ui.MINT, func() -> void: _start_battle("campaign", next), Color("#06201a"))
	outer.add_child(play)


# --------------------------------------------------------------------------
# battle
# --------------------------------------------------------------------------

func _start_battle(run_mode: String, level_id: int) -> void:
	Audio.kick()
	_teardown_battle()
	_mode = run_mode
	_level_id = clampi(level_id, 1, Campaign.LEVEL_COUNT)
	_kills_at_start = int(Save.data["stats"]["kills"])
	_credits_at_start = Save.credits()
	_map.visible = false
	var setup: Dictionary
	if run_mode == "campaign":
		setup = Campaign.generate(_level_id)
	elif run_mode == "daily":
		setup = Campaign.generate_mode("daily", Save.daily_seed(), Save.highest_kingdom())
	elif run_mode == "sandbox":
		setup = Campaign.generate_mode("sandbox", int(Time.get_ticks_msec()), Save.highest_kingdom())
	else:
		setup = Campaign.generate_mode(run_mode, int(Time.get_ticks_msec() / 10) % 99991 + 7, Save.highest_kingdom())
	_sim = Battlefield.new()
	_sim.setup(setup, run_mode)
	_sim.start()
	_view = BattleView.new()
	_view.name = "BattleView"
	add_child(_view)
	_view.build(_sim)
	_screen = "battle"
	Audio.play_music("boss" if bool(setup.get("boss", false)) else "battle")
	_show_battle_hud()
	if run_mode == "campaign" and _level_id <= 3:
		# The top of the board is where wave one walks in, so the coaching line
		# lives in the hint slot under the field instead of over the spawn row.
		_hint.text = "Tap a tower below, then a glowing spot beside the road."


func _show_battle_hud() -> void:
	var root := _clear(false)
	var margin := _margins(root, 10)
	var outer := Ui.column(6)
	margin.add_child(outer)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Ui.box(Color("#08121f").lerp(Color("#0d1b2c"), 0.5), 18, Color("#22344d"), 12))
	outer.add_child(top)
	var top_row := Ui.row(10)
	top.add_child(top_row)

	_lives_label = Ui.label("LIVES 20", 21, Color("#ff8f8f"))
	_lives_label.custom_minimum_size.x = 128
	top_row.add_child(_lives_label)
	_gold_label = Ui.label("0", 22, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_gold_label)
	_wave_label = Ui.label("Wave 1", 18, Ui.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_wave_label.custom_minimum_size.x = 132
	top_row.add_child(_wave_label)
	var pause_button := Ui.ghost("II", func() -> void: _toggle_pause(), 46, 18, 10)
	pause_button.custom_minimum_size.x = 56
	top_row.add_child(pause_button)

	_title_label = Ui.label(_battle_title(), 14, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	outer.add_child(_title_label)

	_boss_panel = PanelContainer.new()
	_boss_panel.add_theme_stylebox_override("panel", Ui.box(Color("#20100f"), 14, Color("#5a2a2a"), 8))
	_boss_panel.visible = false
	outer.add_child(_boss_panel)
	var boss_col := Ui.column(2)
	_boss_panel.add_child(boss_col)
	_boss_name = Ui.label("Boss", 16, Color("#ffcf9a"))
	boss_col.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size.y = 16
	_boss_bar.show_percentage = false
	_boss_bar.add_theme_stylebox_override("background", Ui.box(Color("#2a1414"), 8, Color.TRANSPARENT, 0))
	_boss_bar.add_theme_stylebox_override("fill", Ui.box(Color("#ff7a5c"), 8, Color.TRANSPARENT, 0))
	boss_col.add_child(_boss_bar)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(spacer)

	_hint = Ui.label("", 14, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_hint)

	_panel_holder = PanelContainer.new()
	_panel_holder.add_theme_stylebox_override("panel", Ui.box(Color("#0a1524"), 20, Color("#2b4562"), 12))
	_panel_holder.visible = false
	outer.add_child(_panel_holder)
	_panel = Ui.column(6)
	_panel_holder.add_child(_panel)

	_shelf_scroll = Ui.scroll()
	_shelf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_shelf_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shelf_scroll.custom_minimum_size.y = 96
	_shelf_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	outer.add_child(_shelf_scroll)
	_shelf = Ui.row(8)
	_shelf_scroll.add_child(_shelf)

	var actions := Ui.row(8)
	outer.add_child(actions)
	var wave_action := func() -> void:
		if _sim != null:
			_sim.next_wave_early()
	_wave_button = Ui.button("CALL WAVE", 19, 62, Ui.GOLD, wave_action, Color("#231a0a"))
	_wave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_wave_button)

	_refresh_shelf()
	_refresh_hud()


func _battle_title() -> String:
	match _mode:
		"campaign":
			return "%s  ·  %s" % [String(_sim.level.get("kingdom_name", "")), String(_sim.level.get("name", ""))]
		_:
			return String(_sim.level.get("name", "Battle"))


func _refresh_shelf() -> void:
	if _shelf == null or _sim == null:
		return
	for child in _shelf.get_children():
		child.queue_free()
	_shelf_buttons.clear()
	for id in _sim.level.get("allowed", []):
		var tower_id := String(id)
		var base := Towers.by_id(tower_id)
		if base.is_empty():
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(128, 84)
		card.add_theme_font_size_override("font_size", 14)
		card.text = "%s\n%d gold" % [String(base["name"]), int(base["cost"])]
		var color := Color(String(base["color"]))
		card.add_theme_color_override("font_color", Ui.INK)
		card.add_theme_color_override("font_hover_color", Ui.INK)
		card.add_theme_color_override("font_pressed_color", Ui.INK)
		card.add_theme_color_override("font_disabled_color", Ui.DIM)
		card.add_theme_stylebox_override("normal", Ui.box(Color("#122033").lerp(color, 0.28), 14, Color("#2b4562"), 8))
		card.add_theme_stylebox_override("hover", Ui.box(Color("#182a41").lerp(color, 0.34), 14, Color("#4a6a92"), 8))
		card.add_theme_stylebox_override("pressed", Ui.box(Color("#0d1826"), 14, Color("#4a6a92"), 8))
		card.add_theme_stylebox_override("disabled", Ui.box(Color("#0e1622"), 14, Color("#1d2a3c"), 8))
		card.pressed.connect(func() -> void: _pick_build(tower_id))
		_shelf.add_child(card)
		_shelf_buttons[tower_id] = card


func _pick_build(tower_id: String) -> void:
	if _sim == null:
		return
	_build_id = "" if _build_id == tower_id else tower_id
	_selected = -1
	_view.show_selection(-1)
	_panel_holder.visible = false
	_shelf_scroll.visible = true
	_view.set_build_mode(_build_id != "", _build_id)
	if _build_id == "":
		_hint.text = ""
	else:
		_hint.text = "Tap a glowing spot beside the road to build %s" % String(Towers.by_id(_build_id)["name"])
	Audio.ui_click()


func _open_tower(index: int) -> void:
	if _sim == null or index < 0 or index >= _sim.towers.size():
		return
	_selected = index
	_build_id = ""
	_view.set_build_mode(false)
	_view.show_selection(index)
	_shelf_scroll.visible = false
	_panel_holder.visible = true
	_hint.text = "Tap the board to dismiss."
	_rebuild_panel()


func _close_tower() -> void:
	_selected = -1
	_view.show_selection(-1)
	_panel_holder.visible = false
	_shelf_scroll.visible = true
	_hint.text = ""


func _rebuild_panel() -> void:
	if _panel == null or _sim == null:
		return
	for child in _panel.get_children():
		child.queue_free()
	if _selected < 0 or _selected >= _sim.towers.size():
		_panel_holder.visible = false
		return
	var tower: Dictionary = _sim.towers[_selected]
	var stats: Dictionary = tower["stats"]
	var head := Ui.row(8)
	head.add_child(Ui.label(String(stats["display_name"]), 19))
	var badge := Ui.label("T%d  ·  %s" % [int(tower["tier"]), Towers.type_label(String(stats["type"]))], 13, Ui.MUTED)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(badge)
	var close_action := func() -> void:
		_close_tower()
	var close := Ui.ghost("✕", close_action, 40, 16, 8)
	close.custom_minimum_size.x = 46
	head.add_child(close)
	_panel.add_child(head)

	var rate := float(stats["interval"]) / maxf(0.1, 1.0 + float(tower["buff_rate"]))
	var hit := float(stats["damage"]) * float(tower["power"]) * (1.0 + float(tower["buff_dmg"]))
	var dps := hit / maxf(0.05, rate)
	var info := "DMG %.0f   RATE %.2fs   RANGE %.1f   DPS %.0f" % [hit, rate, float(stats["reach"]) + float(tower["buff_range"]), dps]
	_panel.add_child(Ui.label(info, 14, Ui.MUTED))

	var tier := int(tower["tier"])
	var actions := Ui.row(8)
	_panel.add_child(actions)
	if tier < Towers.MAX_TIER - 1:
		var price := Towers.upgrade_cost(String(tower["id"]), tier)
		var upgrade_action := func() -> void:
			if _sim.upgrade(_selected, ""):
				Audio.play_sfx("upgrade")
				_rebuild_panel()
				_refresh_shelf()
		var button := Ui.button("UPGRADE TO TIER %d  ·  %d gold" % [tier + 1, price], 16, 54, Ui.MINT, upgrade_action, Color("#06201a"))
		button.disabled = _sim.gold < price
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	elif tier == Towers.MAX_TIER - 1:
		var price := Towers.upgrade_cost(String(tower["id"]), tier)
		var branches: Dictionary = Towers.by_id(String(tower["id"])).get("branch", {})
		for key in ["a", "b"]:
			var option: Dictionary = branches.get(key, {})
			if option.is_empty():
				continue
			var choose := func() -> void:
				if _sim.upgrade(_selected, key):
					Audio.play_sfx("upgrade")
					_rebuild_panel()
					_refresh_shelf()
			var choice := Ui.ghost("%s\n%s  ·  %d gold" % [String(option["name"]), String(option.get("note", "")), price], choose, 76, 13, 8)
			choice.disabled = _sim.gold < price
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(choice)
	else:
		_panel.add_child(Ui.label("Ultimate: %s" % String(stats["display_name"]), 14, Ui.GOLD))

	var foot := Ui.row(8)
	_panel.add_child(foot)
	var target_action := func() -> void:
		var modes := ["first", "last", "strong", "weak", "close", "flying"]
		var at := modes.find(String(_sim.towers[_selected]["target_mode"]))
		_sim.set_target_mode(_selected, modes[(at + 1) % modes.size()])
		_rebuild_panel()
	var target_button := Ui.ghost("Target: %s" % String(tower["target_mode"]).capitalize(), target_action, 46, 15, 8)
	target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(target_button)
	var refund := Towers.sell_value(String(tower["id"]), tier, int(tower["invested"]))
	var sell_action := func() -> void:
		if _sim.sell(_selected):
			Audio.play_sfx("sell")
			_close_tower()
			_refresh_shelf()
	var sell := Ui.ghost("SELL  ·  %d" % refund, sell_action, 46, 15, 8)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sell)


func _tick_battle(delta: float) -> void:
	if _sim == null or _view == null:
		return
	if not _paused and not _result_open:
		_sim.advance(delta)
	_view.sync(delta)
	_refresh_hud()
	if not _result_guard and (_sim.phase == "won" or _sim.phase == "lost"):
		_result_guard = true
		_show_result(_sim.phase == "won")


func _refresh_hud() -> void:
	if _sim == null or _lives_label == null:
		return
	_lives_label.text = "LIVES %d" % _sim.lives
	_gold_label.text = "%d gold" % _sim.gold
	_wave_label.text = _sim.wave_label()
	if _mode == "campaign":
		_title_label.text = "%s  ·  %s %02d" % [String(_sim.level.get("kingdom_name", "")), String(Campaign.kingdom(_sim.level.get("id", 1))["short"]), int(_sim.level.get("local", 1))]
	for tower_id in _shelf_buttons.keys():
		var card: Button = _shelf_buttons[tower_id]
		card.disabled = _sim.gold < int(Towers.by_id(String(tower_id))["cost"])
	var boss: Dictionary = {}
	for enemy in _sim.enemies:
		if bool(enemy["is_boss"]):
			boss = enemy
			break
	if boss.is_empty():
		_boss_panel.visible = false
	else:
		_boss_panel.visible = true
		_boss_name.text = "%s  ·  %s" % [String(boss["name"]), String((boss["boss_stats"] as Dictionary).get("phase_name", ""))]
		_boss_bar.max_value = maxf(1.0, float(boss["max_hp"]))
		_boss_bar.value = float(boss["hp"])
	if _wave_button != null:
		if _sim.phase == "prep":
			_wave_button.disabled = false
			_wave_button.text = "CALL WAVE  ·  +%d gold  ·  %ds" % [8 + _sim.wave_index * 3, int(ceil(_sim.prep_timer))]
		else:
			_wave_button.disabled = true
			_wave_button.text = "WAVE IN PROGRESS  ·  %d enemies" % _sim.enemies.size()


func _unhandled_input(event: InputEvent) -> void:
	if _screen != "battle" or _result_open or _paused or _sim == null or _view == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			_toggle_pause()
		elif key == KEY_SPACE:
			_sim.next_wave_early()
		return
	var pressed := false
	var position := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		position = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
		position = mouse.position
	if not pressed or _tap_guard > 0.0:
		return
	_tap_guard = 0.06
	_handle_board_tap(position)


func _handle_board_tap(position: Vector2) -> void:
	var cell := _view.cell_from_screen(position)
	if cell.x < 0:
		if _selected >= 0:
			_close_tower()
		return
	var index := _sim.tower_at(cell)
	if index >= 0:
		_open_tower(index)
		return
	if _selected >= 0:
		_close_tower()
		return
	if _build_id != "":
		if _sim.build(cell, _build_id):
			Audio.play_sfx("build")
			_view.set_build_mode(true, _build_id)
			_refresh_shelf()
		elif not _sim.socket_open(cell):
			_toast("That spot is part of the road or the scenery.")
		else:
			_toast("Not enough gold for %s." % String(Towers.by_id(_build_id)["name"]))


func _toast(text: String) -> void:
	if _toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.7)


func _toggle_pause() -> void:
	if _screen != "battle" or _result_open:
		return
	_paused = not _paused
	if _paused:
		_show_pause()
	else:
		_hide_pause()


func _show_pause() -> void:
	var overlay := Control.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var margin := _margins(overlay, 26)
	var col := Ui.column(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)
	col.add_child(Ui.label("PAUSED", 40, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Ui.label(_battle_title(), 16, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Ui.spacer(12))
	var resume_action := func() -> void:
		_paused = false
		_hide_pause()
	col.add_child(Ui.button("RESUME", 22, 68, Ui.MINT, resume_action, Color("#06201a")))
	var restart_action := func() -> void:
		_start_battle(_mode, _level_id)
	col.add_child(Ui.ghost("Restart battle", restart_action, 62, 18))
	var leave_action := func() -> void:
		Audio.ui_back()
		if _mode == "campaign":
			_show_levels(Campaign.kingdom_index(_level_id))
		else:
			_show_title()
	col.add_child(Ui.ghost("Leave battle", leave_action, 62, 18))
	col.add_child(Ui.label("Tap the board to dismiss a tower card.", 13, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER, true))


func _hide_pause() -> void:
	if _screen_root == null:
		return
	var overlay := _screen_root.get_node_or_null("PauseOverlay")
	if overlay != null:
		overlay.queue_free()


func _show_result(won: bool) -> void:
	_result_open = true
	var campaign := _mode == "campaign"
	var stars := 0
	var leaks := _sim.max_lives - _sim.lives
	if won and campaign:
		stars = 3 if leaks == 0 else (2 if leaks <= int(_sim.max_lives * 0.2) else 1)
	_run_credits = Save.credits() - _credits_at_start
	_run_kills = int(Save.data["stats"]["kills"]) - _kills_at_start
	if won:
		if campaign:
			Save.complete_level(_level_id, stars, leaks, 0, 0)
		elif _mode == "daily":
			Save.record_daily(_sim.waves_cleared)
			Save.record_run("survival", _sim.waves_cleared)
		elif _mode == "endless":
			Save.record_run("endless", _sim.waves_cleared)
		elif _mode == "survival":
			Save.record_run("survival", _sim.waves_cleared)
		elif _mode == "bossrush":
			Save.record_run("bossrush", _sim.boss_kills)
		elif _mode == "sandbox":
			Save.record_run("sandbox", _sim.waves_cleared)
	Save.flush()

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.86)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var margin := _margins(overlay, 22)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)

	var panel := Ui.panel(Color("#0a1524"), 26, Color("#2b4562"), 18)
	center.add_child(panel)
	var col := Ui.column(10)
	panel.add_child(col)
	col.add_child(Ui.label("VICTORY" if won else "THE ROAD IS LOST", 38, Ui.MINT if won else Ui.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	if campaign and won:
		col.add_child(Ui.label(Ui.stars_text(stars), 46, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		col.add_child(Ui.label("Fell during wave %d" % maxi(1, _sim.wave_index), 20, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Ui.label("%s" % _battle_title(), 15, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Ui.spacer(6))

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 6)
	col.add_child(stats)
	_stat(stats, "Waves", str(_sim.waves_cleared))
	_stat(stats, "Enemies", str(_run_kills))
	_stat(stats, "Towers", str(_sim.towers.size()))
	_stat(stats, "Damage taken", str(leaks))
	_stat(stats, "Crowns", "+%d" % maxi(0, _run_credits))
	_stat(stats, "Gold", Ui.format_number(int(Save.data["stats"]["gold"])))
	if campaign:
		col.add_child(Ui.label(STAR_SPEC, 12, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	col.add_child(Ui.spacer(8))

	if campaign and won and _level_id < Campaign.LEVEL_COUNT:
		col.add_child(Ui.button("NEXT LEVEL  ·  %02d" % (_level_id + 1), 20, 64, Ui.MINT, func() -> void: _start_battle("campaign", _level_id + 1), Color("#06201a")))
	col.add_child(Ui.button("PLAY AGAIN", 18, 56, Color("#1b2c42"), func() -> void: _start_battle(_mode, _level_id), Ui.INK))
	var leave_action := func() -> void:
		if campaign:
			_show_levels(Campaign.kingdom_index(_level_id))
		else:
			_show_title()
	col.add_child(Ui.ghost("Back to the map" if campaign else "Back to the title", leave_action, 56, 17))


func _stat(grid: GridContainer, key: String, value: String) -> void:
	grid.add_child(Ui.label(key, 15, Ui.MUTED))
	var right := Ui.label(value, 15, Ui.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(right)


func _on_achievement(id: String) -> void:
	var name := id
	for entry in Save.ACHIEVEMENTS:
		if String(entry["id"]) == id:
			name = String(entry["name"])
			break
	_toast("Trophy unlocked · %s" % name)


# --------------------------------------------------------------------------
# codex, bestiary, trophies, settings
# --------------------------------------------------------------------------

func _show_codex() -> void:
	_screen = "collection"
	_teardown_battle()
	_map.visible = false
	var root := _clear(true)
	var margin := _margins(root, 16)
	var col := Ui.column(8)
	margin.add_child(col)
	col.add_child(_header("Tower Codex", "%d families · three tiers and two ultimates each" % Towers.count(), "Back"))
	var scroll := Ui.scroll()
	col.add_child(scroll)
	var list := Ui.column(8)
	scroll.add_child(list)
	for item in Towers.ITEMS:
		var card := Ui.panel(Color("#0d1a2b"), 18, Color("#22344d"), 12)
		list.add_child(card)
		var body := Ui.column(4)
		card.add_child(body)
		var title := Ui.row(6)
		body.add_child(title)
		title.add_child(Ui.label(String(item["name"]), 19))
		var cat := Ui.label("%s  ·  %d gold" % [String(item["cat"]), int(item["cost"])], 13, Color(String(item["color"])))
		cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title.add_child(cat)
		body.add_child(Ui.label(String(item["blurb"]), 14, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		var base := Towers.stats(String(item["id"]), "", 1)
		body.add_child(Ui.label("%s  ·  DMG %.0f  ·  %.2fs  ·  range %.1f%s" % [
			Towers.type_label(String(item["type"])), float(base["damage"]), float(base["interval"]), float(base["reach"]),
			"  ·  air" if bool(item.get("air", false)) else ""], 13, Ui.DIM))
		var branches: Dictionary = item.get("branch", {})
		body.add_child(Ui.label("A · %s — %s" % [String(branches.get("a", {}).get("name", "")), String(branches.get("a", {}).get("note", ""))], 12, Ui.DIM))
		body.add_child(Ui.label("B · %s — %s" % [String(branches.get("b", {}).get("name", "")), String(branches.get("b", {}).get("note", ""))], 12, Ui.DIM))


func _show_bestiary() -> void:
	_screen = "bestiary"
	_teardown_battle()
	_map.visible = false
	var root := _clear(true)
	var margin := _margins(root, 16)
	var col := Ui.column(8)
	margin.add_child(col)
	col.add_child(_header("Bestiary", "%d archetypes · everything that walks, flies or rolls" % Enemies.count(), "Back"))
	var scroll := Ui.scroll()
	col.add_child(scroll)
	var list := Ui.column(6)
	scroll.add_child(list)
	for item in Enemies.ITEMS:
		var card := Ui.panel(Color("#0d1a2b"), 16, Color("#22344d"), 10)
		list.add_child(card)
		var body := Ui.column(2)
		card.add_child(body)
		var title := Ui.row(6)
		body.add_child(title)
		title.add_child(Ui.label(String(item["name"]), 17, Color(String(item["color"])).lightened(0.25)))
		var tag := "%s%s" % [String(item["kind"]), "  ·  flying" if bool(item.get("flying", false)) else ""]
		var right := Ui.label(tag, 12, Ui.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(right)
		var ability := String(item.get("ability", ""))
		body.add_child(Ui.label("HP %.0f  ·  speed %.2f  ·  armour %.1f  ·  reward %d%s" % [
			float(item["hp"]), float(item["speed"]), float(item["armor"]), int(item["reward"]),
			("  ·  " + ability) if ability != "" else ""], 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))


func _show_trophies() -> void:
	_screen = "trophies"
	_teardown_battle()
	_map.visible = false
	var root := _clear(true)
	var margin := _margins(root, 16)
	var col := Ui.column(8)
	margin.add_child(col)
	col.add_child(_header("Trophies", "%d of %d unlocked" % [Save.trophy_count(), Save.ACHIEVEMENTS.size()], "Back"))
	var scroll := Ui.scroll()
	col.add_child(scroll)
	var list := Ui.column(5)
	scroll.add_child(list)
	for entry in Save.ACHIEVEMENTS:
		var id := String(entry["id"])
		var got := Save.has_achievement(id)
		var row_node := PanelContainer.new()
		row_node.add_theme_stylebox_override("panel", Ui.box(Color("#0d1a2b") if got else Color("#0a1220"), 14, Color("#2b4562") if got else Color("#1a2434"), 10))
		list.add_child(row_node)
		var body := Ui.column(1)
		row_node.add_child(body)
		body.add_child(Ui.label(("* " if got else "-  ") + String(entry["name"]), 15, Ui.GOLD if got else Ui.MUTED))
		body.add_child(Ui.label(String(entry["hint"]), 12, Ui.DIM, HORIZONTAL_ALIGNMENT_LEFT, true))


func _show_settings() -> void:
	_screen = "settings"
	_teardown_battle()
	_map.visible = false
	var root := _clear(true)
	var margin := _margins(root, 20)
	var col := Ui.column(12)
	margin.add_child(col)
	col.add_child(_header("Settings", "Sound, motion and your save", "Back"))

	col.add_child(_slider("Music", "music", 0.0, 1.0))
	col.add_child(_slider("Sound effects", "sfx", 0.0, 1.0))
	col.add_child(_toggle("Reduced motion", "reduced_motion"))
	col.add_child(_toggle("Screen shake", "screen_shake"))
	col.add_child(Ui.spacer(8))

	var panel := Ui.panel(Color("#0d1a2b"), 18, Color("#22344d"), 14)
	col.add_child(panel)
	var body := Ui.column(6)
	panel.add_child(body)
	body.add_child(Ui.label("Save", 18))
	body.add_child(Ui.label("Progress saves locally after every wave. Sign in to sync it across devices with cloud saves and trophies.", 13, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	body.add_child(Ui.label(Arcade.status_text(), 13, Ui.GOLD))
	var account_row := Ui.row(8)
	body.add_child(account_row)
	var account_action := func() -> void:
		if Arcade.signed_in:
			Arcade.open_arcade()
		else:
			Arcade.sign_in()
	account_row.add_child(Ui.ghost("Sign in" if not Arcade.signed_in else "Open arcade", account_action, 52, 16))
	var reset_action := func() -> void:
		_reset_pressed()
	account_row.add_child(Ui.ghost("Reset progress", reset_action, 52, 16))

	var stats := Ui.panel(Color("#0d1a2b"), 18, Color("#22344d"), 14)
	col.add_child(stats)
	var stats_body := Ui.column(3)
	stats.add_child(stats_body)
	stats_body.add_child(Ui.label("Journey so far", 18))
	stats_body.add_child(Ui.label("★ %d stars  ·  %d levels  ·  %d bosses  ·  %d trophies" % [
		Save.total_stars(), Save.completed_levels(), (Save.data["stats"]["bosses"] as Dictionary).size(), Save.trophy_count()], 13, Ui.MUTED))
	stats_body.add_child(Ui.label("Enemies defeated %d  ·  waves held %d  ·  battle gold %d" % [
		int(Save.data["stats"]["kills"]), int(Save.data["stats"]["waves"]), int(Save.data["stats"]["gold"])], 13, Ui.MUTED))
	stats_body.add_child(Ui.label("1,000 levels  ·  20 kingdoms  ·  %d towers  ·  %d enemies  ·  20 bosses" % [Towers.count(), Enemies.count()], 13, Ui.DIM))


func _slider(title: String, key: String, low: float, high: float) -> Control:
	var row_node := Ui.row(8)
	row_node.add_child(Ui.label(title, 17))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = float(Save.get_setting(key, 0.6))
	slider.custom_minimum_size = Vector2(220, 34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		Save.set_setting(key, value))
	row_node.add_child(slider)
	return row_node


func _toggle(title: String, key: String) -> Control:
	var row_node := Ui.row(8)
	row_node.add_child(Ui.label(title, 17))
	var check := CheckButton.new()
	check.button_pressed = bool(Save.get_setting(key, true))
	check.size_flags_horizontal = Control.SIZE_SHRINK_END
	check.toggled.connect(func(value: bool) -> void:
		Save.set_setting(key, value))
	row_node.add_child(check)
	return row_node


func _reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_toast("Tap reset again to erase all progress.")
		var timer := get_tree().create_timer(4.0)
		timer.timeout.connect(func() -> void: _reset_armed = false)
		return
	_reset_armed = false
	Save.reset_progress()
	Save.flush()
	_show_title()
