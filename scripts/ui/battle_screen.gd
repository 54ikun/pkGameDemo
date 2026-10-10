extends Control
## 战斗界面：播放 BattleEngine 产生的事件，提供 战斗 / 背包 / 宝可梦 / 逃跑 指令

signal finished(report: Dictionary)

const PLAYER := 0
const ENEMY := 1

var engine: BattleEngine
var ctx: Dictionary = {}
var busy := false
var auto := false
var fast := false

var stage: BattleStage
var sprites: Array = [null, null]
var sprite_home: Array = [Vector2.ZERO, Vector2.ZERO]
var infos: Array = [{}, {}]
var log_label: RichTextLabel
var menu: VBoxContainer
var bottom: PanelContainer
var ball: BallSprite


class BattleStage extends Control:
	var bg: Texture2D
	var sky_top := Color("6fb7ff")
	var sky_bottom := Color("cfe9ff")
	var ground := Color("8fcf6a")
	var enemy_pos := Vector2.ZERO
	var player_pos := Vector2.ZERO

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if bg:
			var ts := bg.get_size()
			var sc := maxf(size.x / ts.x, size.y / ts.y)
			var src_size := size / sc
			draw_texture_rect_region(bg, r, Rect2((ts - src_size) / 2.0, src_size))
		else:
			draw_texture_rect(Art.gradient(sky_top, sky_bottom), Rect2(0, 0, size.x, size.y * 0.55), false)
			draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), ground)
			draw_rect(Rect2(0, size.y * 0.55, size.x, 6), ground.darkened(0.15))
			for i in 6:
				var cx := fmod(i * 263.0 + 80.0, size.x)
				draw_circle(Vector2(cx, size.y * 0.12 + (i % 3) * 30), 26 + (i % 2) * 12, Color(1, 1, 1, 0.55))
				draw_circle(Vector2(cx + 30, size.y * 0.12 + (i % 3) * 30 + 6), 20, Color(1, 1, 1, 0.55))
		_platform(enemy_pos, 150, 38)
		_platform(player_pos, 190, 46)

	func _platform(c: Vector2, rx: float, ry: float) -> void:
		draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
		draw_circle(Vector2.ZERO, rx, ground.darkened(0.3))
		draw_circle(Vector2(0, -6), rx * 0.92, ground.lightened(0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class BallSprite extends Control:
	var top := Color("e3350d")
	var glow := 0.0

	func _draw() -> void:
		Art.draw_ball(self, size / 2.0, size.x / 2.0, top)
		if glow > 0.0:
			draw_circle(size / 2.0, size.x * 0.7, Color(1, 1, 0.6, glow * 0.5))


class Burst extends Control:
	var color := Color.WHITE
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.5 * t
		draw_circle(c, r, Color(color, 0.35 * (1.0 - t)))
		draw_arc(c, r, 0, TAU, 40, Color(color, 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
		for i in 8:
			var a := i * TAU / 8.0
			draw_line(c + Vector2(cos(a), sin(a)) * r * 0.5, c + Vector2(cos(a), sin(a)) * r * 1.1, Color(color.lightened(0.4), 1.0 - t), 3.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	stage = BattleStage.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rid := ""
	if ctx.has("region"):
		rid = DB.region(int(ctx.region)).get("id", "")
	stage.bg = Art.ui("battle_bg_" + rid) if rid != "" else null
	if stage.bg == null:
		stage.bg = Art.ui("battle_bg")
	_theme_stage(int(ctx.get("region", -1)))
	add_child(stage)

	for side in [ENEMY, PLAYER]:
		var p := Portrait.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.flip_h = side == PLAYER
		add_child(p)
		sprites[side] = p
		infos[side] = _make_info(side)
		add_child(infos[side].panel)

	ball = BallSprite.new()
	ball.size = Vector2(34, 34)
	ball.pivot_offset = ball.size / 2.0
	ball.visible = false
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ball)

	bottom = UI.panel(Color("141b33"), 0, 12, UI.BORDER)
	add_child(bottom)
	var bh := UI.hbox(14)
	bottom.add_child(bh)
	var log_panel := UI.panel(Color("0d1226"), 10, 12, UI.BORDER)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_stretch_ratio = 1.15
	bh.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 17)
	log_panel.add_child(log_label)
	menu = UI.vbox(8)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(menu)

	resized.connect(_layout)
	_layout.call_deferred()
	_set_info(PLAYER, engine.player())
	_set_info(ENEMY, engine.enemy())
	_clear_menu()
	_start.call_deferred()


func _start() -> void:
	for side in [ENEMY, PLAYER]:
		sprites[side].modulate.a = 0.0
	await get_tree().process_frame
	_layout()
	_anim_enter(ENEMY)
	await _wait(0.3)
	_anim_enter(PLAYER)
	await _play(engine.intro())


func _theme_stage(ri: int) -> void:
	var themes := [
		["5fb0ff", "d9f1ff", "7cc85a"], ["8fb3d9", "e6eef7", "b59a72"], ["4fb4ff", "c8f0ff", "e8d59a"],
		["4b5a78", "9aa8c4", "8a8f99"], ["ff9ec8", "ffe3f0", "8cd06a"], ["3a2a5c", "7b6a9e", "5d5470"],
		["74b8e8", "e8f5d0", "a6c25a"], ["9fd8f0", "f0fbff", "dff1f7"], ["b8402a", "ffb070", "6b4a3a"],
		["4a4f6a", "a0a6c0", "7a7060"], ["1c1838", "4a3f78", "3d3550"],
	]
	if ctx.get("type", "") == "legend":
		stage.sky_top = Color("2a0f4a")
		stage.sky_bottom = Color("8a5cc8")
		stage.ground = Color("4a3a6a")
	elif ctx.get("type", "") == "tower":
		stage.sky_top = Color("39406a")
		stage.sky_bottom = Color("9aa0c8")
		stage.ground = Color("6c7090")
	elif ri >= 0 and ri < themes.size():
		stage.sky_top = Color(themes[ri][0])
		stage.sky_bottom = Color(themes[ri][1])
		stage.ground = Color(themes[ri][2])


func _layout() -> void:
	var w := size.x
	var h := size.y
	var bottom_h := 200.0
	var sh := h - bottom_h
	stage.position = Vector2.ZERO
	stage.size = Vector2(w, sh)
	stage.enemy_pos = Vector2(w * 0.72, sh * 0.52)
	stage.player_pos = Vector2(w * 0.27, sh * 0.93)
	stage.queue_redraw()
	var es := 230.0
	var ps := 280.0
	sprite_home[ENEMY] = stage.enemy_pos - Vector2(es / 2.0, es * 0.9)
	sprite_home[PLAYER] = stage.player_pos - Vector2(ps / 2.0, ps * 0.92)
	sprites[ENEMY].size = Vector2(es, es)
	sprites[PLAYER].size = Vector2(ps, ps)
	for side in [ENEMY, PLAYER]:
		sprites[side].pivot_offset = sprites[side].size / 2.0
		if not busy:
			sprites[side].position = sprite_home[side]
	infos[ENEMY].panel.position = Vector2(36, 28)
	infos[PLAYER].panel.position = Vector2(w - 456, sh - 150)
	bottom.position = Vector2(0, sh)
	bottom.size = Vector2(w, bottom_h)


# ---------------- 信息面板 ----------------

func _make_info(side: int) -> Dictionary:
	var p := UI.panel(Color(0.07, 0.09, 0.18, 0.88), 12, 12, UI.BORDER)
	p.custom_minimum_size = Vector2(420, 0)
	var v := UI.vbox(5)
	p.add_child(v)
	var r1 := UI.hbox(8)
	v.add_child(r1)
	var nm := UI.lbl("", 20, Color.WHITE, true)
	r1.add_child(nm)
	var rar_box := UI.hbox(4)
	r1.add_child(rar_box)
	r1.add_child(UI.spacer())
	var lv := UI.lbl("", 18, UI.ACCENT, true)
	r1.add_child(lv)
	var r2 := UI.hbox(6)
	v.add_child(r2)
	var hpb := UI.bar(1, 1, UI.GOOD, 300, 14)
	hpb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(UI.lbl("HP", 14, UI.ACCENT, true))
	r2.add_child(hpb)
	var hpt := UI.lbl("", 14, UI.TEXT)
	hpt.custom_minimum_size.x = 80
	hpt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r2.add_child(hpt)
	var d := {"panel": p, "nm": nm, "lv": lv, "tags": rar_box, "bar": hpb, "hp": hpt}
	if side == PLAYER:
		var xpb := UI.bar(0, 1, Color("4aa3ff"), 300, 6)
		xpb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(xpb)
		d["xp"] = xpb
	else:
		var extra := UI.lbl("", 13, UI.MUTED)
		v.add_child(extra)
		d["extra"] = extra
	return d


func _set_info(side: int, m: Monster) -> void:
	var d: Dictionary = infos[side]
	d.nm.text = m.display_name()
	d.lv.text = "Lv.%d" % m.level
	UI.clear(d.tags)
	d.tags.add_child(UI.rarity_pill(m.rarity, 12))
	for t in m.types():
		d.tags.add_child(UI.type_pill(t, 12))
	if m.shiny:
		d.tags.add_child(UI.pill("闪光", Color("ffe14a"), 12))
	if m.status != "":
		d.tags.add_child(UI.pill(DB.STATUS_NAMES.get(m.status, m.status), Color("c0392b"), 12))
	d.bar.max_value = m.max_hp()
	d.bar.value = m.hp
	_color_bar(d.bar, float(m.hp) / maxf(1.0, m.max_hp()))
	d.hp.text = "%d/%d" % [m.hp, m.max_hp()]
	if d.has("xp"):
		d.xp.value = m.xp_progress()
	if d.has("extra"):
		var txt := ""
		if engine.kind == BattleEngine.Kind.WILD or engine.kind == BattleEngine.Kind.BOSS:
			txt = "已捕获过" if Game.caught.has(m.species_id) else "未捕获"
			txt += "  ·  个体值 ??"
		else:
			txt = "%s  ·  剩余 %d/%d" % [engine.enemy_name, engine.alive_count(ENEMY), engine.teams[ENEMY].size()]
		d.extra.text = txt
	sprites[side].setup(m.species_id, m.shiny)


func _color_bar(b: ProgressBar, ratio: float) -> void:
	b.add_theme_stylebox_override("fill", UI.style(UI.hp_color(ratio), 4))


func _tween_hp(side: int, hp: int, mx: int) -> void:
	var d: Dictionary = infos[side]
	d.bar.max_value = mx
	var tw := create_tween()
	tw.tween_property(d.bar, "value", float(hp), 0.45 / _speed())
	d.hp.text = "%d/%d" % [hp, mx]
	await tw.finished
	_color_bar(d.bar, float(hp) / maxf(1.0, mx))


# ---------------- 事件播放 ----------------

func _speed() -> float:
	return 2.2 if fast else 1.0


func _wait(t: float) -> void:
	await get_tree().create_timer(t / _speed()).timeout


func _log(text: String, color: String = "") -> void:
	if color != "":
		log_label.append_text("[color=%s]%s[/color]\n" % [color, text])
	else:
		log_label.append_text(text + "\n")


func _play(evs: Array) -> void:
	busy = true
	_clear_menu()
	for e in evs:
		match str(e.type):
			"msg":
				_log(e.text)
				await _wait(0.5)
			"attack":
				await _anim_attack(int(e.side), str(e.mtype), str(e.cat))
			"damage":
				var col := Color.WHITE
				if float(e.eff) > 1.0:
					col = Color("ffd23f")
				elif float(e.eff) < 1.0:
					col = Color("b0b8d0")
				_float_text(int(e.side), "-%d" % int(e.amount), UI.BAD if col == Color.WHITE else col, 30 if e.crit else 24)
				_hit_shake(int(e.side))
				await _tween_hp(int(e.side), int(e.hp), int(e.max))
			"heal":
				_float_text(int(e.side), "+HP", UI.GOOD, 22)
				await _tween_hp(int(e.side), int(e.hp), int(e.max))
			"miss":
				_float_text(int(e.side), "MISS", Color("c0c8e0"), 22)
			"status":
				_set_info(int(e.side), engine.mon(int(e.side)))
			"stat":
				var up: bool = int(e.delta) > 0
				_float_text(int(e.side), "%s%s" % [DB.STAT_SHORT[e.stat], "↑" if up else "↓"], Color("7fd0ff") if up else Color("ff9a7f"), 20)
			"faint":
				await _anim_faint(int(e.side))
			"switch_in":
				_set_info(int(e.side), engine.mon(int(e.side)))
				await _anim_enter(int(e.side))
			"xp":
				if int(e.uid) == engine.player().uid:
					var tw := create_tween()
					tw.tween_property(infos[PLAYER].xp, "value", engine.player().xp_progress(), 0.4 / _speed())
			"level_up":
				if int(e.uid) == engine.player().uid:
					_set_info(PLAYER, engine.player())
					_float_text(PLAYER, "LEVEL UP!", UI.ACCENT, 26)
					_burst(sprites[PLAYER].position + sprites[PLAYER].size / 2.0, UI.ACCENT, 260)
					await _wait(0.2)
			"ball_throw":
				await _anim_ball_throw(str(e.item))
			"shake":
				for i in int(e.count):
					await _anim_ball_shake()
			"caught":
				await _anim_caught()
			"break_free":
				await _anim_break_free(bool(e.get("blocked", false)))
	busy = false
	_after_play()


func _after_play() -> void:
	if engine.over:
		await _wait(0.6)
		var report := Game.finish_battle(engine, ctx)
		finished.emit(report)
		return
	if engine.awaiting_switch:
		if auto:
			await _play(engine.force_switch(engine._first_alive(PLAYER)))
		else:
			_show_party(true)
		return
	_show_main_menu()
	if auto:
		await _wait(0.25)
		if auto and not busy and not engine.over:
			_do_action({"kind": "move", "move": ""})


func _do_action(action: Dictionary) -> void:
	if busy or engine.over:
		return
	await _play(engine.do_turn(action))


# ---------------- 动画 ----------------

func _anim_attack(side: int, mtype: String, cat: String) -> void:
	var s: Control = sprites[side]
	var target: Control = sprites[1 - side]
	var dir := (target.position - s.position).normalized()
	var home: Vector2 = sprite_home[side]
	var tw := create_tween()
	if cat == "status":
		tw.tween_property(s, "scale", Vector2(1.12, 1.12), 0.12 / _speed())
		tw.tween_property(s, "scale", Vector2.ONE, 0.12 / _speed())
		_burst(s.position + s.size / 2.0, DB.type_color(mtype), 200)
	else:
		tw.tween_property(s, "position", home + dir * 46.0, 0.12 / _speed())
		tw.tween_property(s, "position", home, 0.16 / _speed())
		_burst(target.position + target.size / 2.0, DB.type_color(mtype), 180)
	await tw.finished


func _hit_shake(side: int) -> void:
	var s: Control = sprites[side]
	var home: Vector2 = sprite_home[side]
	var tw := create_tween()
	for i in 3:
		tw.tween_property(s, "position", home + Vector2(10, 0), 0.04 / _speed())
		tw.tween_property(s, "position", home - Vector2(10, 0), 0.04 / _speed())
	tw.tween_property(s, "position", home, 0.04 / _speed())
	var tw2 := create_tween()
	tw2.tween_property(s, "modulate", Color(1, 0.4, 0.4, 1), 0.06)
	tw2.tween_property(s, "modulate", Color.WHITE, 0.2)


func _anim_faint(side: int) -> void:
	var s: Control = sprites[side]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "position", sprite_home[side] + Vector2(0, 70), 0.45 / _speed())
	tw.tween_property(s, "modulate:a", 0.0, 0.45 / _speed())
	await tw.finished


func _anim_enter(side: int) -> void:
	var s: Control = sprites[side]
	s.position = sprite_home[side]
	s.scale = Vector2(0.2, 0.2)
	s.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE, 0.35 / _speed()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 1.0, 0.25 / _speed())
	await tw.finished


func _anim_ball_throw(iid: String) -> void:
	ball.top = Art.ball_color(iid)
	ball.glow = 0.0
	ball.rotation = 0.0
	ball.visible = true
	ball.queue_redraw()
	var from: Vector2 = sprite_home[PLAYER] + Vector2(160, 40)
	var to: Vector2 = sprite_home[ENEMY] + sprites[ENEMY].size * Vector2(0.5, 0.45) - ball.size / 2.0
	var arc := func(t: float):
		ball.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * 160.0)
		ball.rotation = t * TAU * 2.0
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.55 / _speed())
	await tw.finished
	if not engine.can_catch():
		return
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(sprites[ENEMY], "scale", Vector2(0.05, 0.05), 0.25 / _speed())
	tw2.tween_property(sprites[ENEMY], "modulate", Color(3, 3, 3, 0), 0.25 / _speed())
	await tw2.finished
	var ground: Vector2 = Vector2(to.x, stage.enemy_pos.y - ball.size.y)
	var tw3 := create_tween()
	tw3.tween_property(ball, "position", ground, 0.25 / _speed()).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw3.finished
	await _wait(0.25)


func _anim_ball_shake() -> void:
	var tw := create_tween()
	tw.tween_property(ball, "rotation", 0.45, 0.12 / _speed())
	tw.tween_property(ball, "rotation", -0.45, 0.18 / _speed())
	tw.tween_property(ball, "rotation", 0.0, 0.12 / _speed())
	tw.tween_interval(0.35 / _speed())
	await tw.finished


func _anim_caught() -> void:
	ball.glow = 1.0
	ball.queue_redraw()
	for i in 3:
		_burst(ball.position + ball.size / 2.0 + Vector2(randf_range(-30, 30), randf_range(-30, 10)), Color("fff27a"), 80)
	ball.modulate = Color(0.7, 0.7, 0.7)
	await _wait(0.8)


func _anim_break_free(blocked: bool) -> void:
	if blocked:
		var tw0 := create_tween()
		tw0.tween_property(ball, "position", ball.position + Vector2(-120, 80), 0.3 / _speed())
		await tw0.finished
		ball.visible = false
		return
	_burst(ball.position + ball.size / 2.0, Color.WHITE, 140)
	ball.visible = false
	var s: Control = sprites[ENEMY]
	s.position = sprite_home[ENEMY]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE, 0.25 / _speed())
	tw.tween_property(s, "modulate", Color.WHITE, 0.25 / _speed())
	await tw.finished


func _burst(center: Vector2, color: Color, sz: float) -> Burst:
	var b := Burst.new()
	b.color = color
	b.size = Vector2(sz, sz)
	b.position = center - b.size / 2.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	move_child(b, bottom.get_index())
	var tw := b.create_tween()
	tw.tween_property(b, "t", 1.0, 0.4 / _speed())
	tw.tween_callback(b.queue_free)
	return b


func _float_text(side: int, text: String, color: Color, sz: int) -> void:
	var l := UI.lbl(text, sz, color, true)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	var s: Control = sprites[side]
	l.position = s.position + Vector2(s.size.x * 0.5 - 40 + randf_range(-20, 20), s.size.y * 0.15)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# ---------------- 菜单 ----------------

func _clear_menu() -> void:
	UI.clear(menu)


func _menu_header(title: String, back: bool) -> void:
	var h := UI.hbox(8)
	h.add_child(UI.lbl(title, 17, UI.ACCENT, true))
	h.add_child(UI.spacer())
	if back:
		h.add_child(UI.btn("返回", _show_main_menu))
	menu.add_child(h)


func _show_main_menu() -> void:
	_clear_menu()
	var h := UI.hbox(8)
	h.add_child(UI.lbl("%s 要怎么做？" % engine.player().display_name(), 17, UI.TEXT, true))
	h.add_child(UI.spacer())
	var cb_auto := CheckButton.new()
	cb_auto.text = "自动"
	cb_auto.button_pressed = auto
	cb_auto.toggled.connect(_on_auto_toggled)
	h.add_child(cb_auto)
	var cb_fast := CheckButton.new()
	cb_fast.text = "2倍速"
	cb_fast.button_pressed = fast
	cb_fast.toggled.connect(func(v: bool): fast = v)
	h.add_child(cb_fast)
	menu.add_child(h)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(g)
	var defs := [
		["战斗", _show_moves, Color("e8533f")],
		["背包", _show_bag, Color("f0a830")],
		["宝可梦", _show_party.bind(false), Color("4cae4f")],
		["逃跑" if engine.can_run() else "认输", _on_run, Color("4a7fd4")],
	]
	for d in defs:
		var b := UI.accent_btn(d[0], d[1], 0, d[2])
		b.add_theme_font_size_override("font_size", 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		g.add_child(b)


func _on_auto_toggled(v: bool) -> void:
	auto = v
	if auto and not busy and not engine.over and not engine.awaiting_switch:
		_do_action({"kind": "move", "move": ""})


func _show_moves() -> void:
	_clear_menu()
	_menu_header("选择技能", true)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(g)
	var foe := engine.enemy()
	for mid in engine.player().moves:
		var mv := DB.move(mid)
		var eff := DB.type_mult(mv.type, foe.types()) if mv.cat != "status" else 1.0
		var hint := ""
		if mv.cat != "status":
			if eff == 0.0:
				hint = " 无效"
			elif eff > 1.0:
				hint = " 拔群!"
			elif eff < 1.0:
				hint = " 不太好"
		var pw := "变化" if mv.cat == "status" else "威力%d" % int(mv.power)
		var b := UI.accent_btn("%s\n%s %s%s" % [mv.name, DB.type_name(mv.type), pw, hint], _do_action.bind({"kind": "move", "move": mid}), 0, DB.type_color(mv.type).darkened(0.15))
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s  命中 %s" % ["物理" if mv.cat == "physical" else ("特殊" if mv.cat == "special" else "变化"), str(int(mv.acc)) if int(mv.acc) > 0 else "必中"]
		g.add_child(b)


func _show_bag() -> void:
	_clear_menu()
	_menu_header("背包", true)
	var list := UI.vbox(6)
	var any := false
	if engine.can_catch():
		var row := UI.hbox(6)
		for iid in Game.ball_ids():
			var n := Game.item_count(iid)
			if n <= 0:
				continue
			any = true
			var it := DB.item(iid)
			var p := BattleEngine.catch_chance(engine.enemy(), float(it.ball))
			var b := UI.btn("%s ×%d\n成功率 %d%%" % [it.name, n, int(round(p * 100.0))], _throw.bind(iid))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 14)
			row.add_child(b)
		list.add_child(row)
	var row2 := UI.hbox(6)
	for iid in ["potion", "super_potion", "max_potion", "revive"]:
		var n2 := Game.item_count(iid)
		if n2 <= 0:
			continue
		any = true
		var b2 := UI.btn("%s ×%d" % [DB.item(iid).name, n2], _choose_item_target.bind(iid))
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.add_theme_font_size_override("font_size", 14)
		row2.add_child(b2)
	list.add_child(row2)
	if not any:
		list.add_child(UI.lbl("背包里没有可以使用的道具", 15, UI.MUTED))
	menu.add_child(list)


func _throw(iid: String) -> void:
	if not Game.consume_item(iid):
		return
	_do_action({"kind": "ball", "item": iid, "ball": float(DB.item(iid).ball)})


func _choose_item_target(iid: String) -> void:
	_clear_menu()
	_menu_header("对谁使用 %s？" % DB.item(iid).name, true)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	menu.add_child(g)
	var revive: bool = DB.item(iid).kind == "revive"
	for i in engine.teams[PLAYER].size():
		var m: Monster = engine.teams[PLAYER][i]
		var b := UI.btn("%s Lv.%d\nHP %d/%d" % [m.display_name(), m.level, m.hp, m.max_hp()], _use_item.bind(iid, i))
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = (m.is_fainted() != revive) or (not revive and m.hp >= m.max_hp() and m.status == "")
		g.add_child(b)


func _use_item(iid: String, idx: int) -> void:
	if not Game.consume_item(iid):
		return
	_do_action({"kind": "item", "item": iid, "target": idx})


func _show_party(forced: bool) -> void:
	_clear_menu()
	_menu_header("选择下一只宝可梦" if forced else "替换宝可梦", not forced)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	menu.add_child(g)
	for i in engine.teams[PLAYER].size():
		var m: Monster = engine.teams[PLAYER][i]
		var b := UI.btn("%s Lv.%d\nHP %d/%d" % [m.display_name(), m.level, m.hp, m.max_hp()], _switch_to.bind(i, forced))
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = m.is_fainted() or i == engine.active[PLAYER]
		var r := DB.rarity(m.rarity)
		b.add_theme_color_override("font_color", r.color.lightened(0.3))
		g.add_child(b)


func _switch_to(idx: int, forced: bool) -> void:
	if forced:
		await _play(engine.force_switch(idx))
	else:
		_do_action({"kind": "switch", "index": idx})


func _on_run() -> void:
	if engine.can_run():
		_do_action({"kind": "run"})
	else:
		_do_action({"kind": "forfeit"})
