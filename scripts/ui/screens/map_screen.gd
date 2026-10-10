extends Control
## 地图：选择地区 → 野外遭遇 / 自动狩猎 / 挑战馆主

var main
var selected := 0
var map_view: MapView
var info: VBoxContainer
var log_label: RichTextLabel

const CATCH_OPTIONS := [[-1, "关闭自动捕捉"], [99, "仅新种类与闪光"], [1, "优良及以上 + 新种类"], [2, "稀有及以上 + 新种类"], [3, "史诗及以上 + 新种类"], [4, "传说及以上 + 新种类"]]


class MapView extends Control:
	signal region_clicked(idx: int)
	const BASE := Vector2(840, 560)
	const LAND := ["4f9a3c", "8b7355", "d9c78f", "6e7480", "7fbf6a", "5b4a7a", "9bb55a", "bfe3ef", "a2462e", "7b7466", "3d3360"]
	var selected := 0
	var hover := -1
	var bg: Texture2D
	var t := 0.0

	func _ready() -> void:
		bg = Art.ui("world_map")
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func node_pos(i: int) -> Vector2:
		var p: Array = DB.region(i).pos
		var sc := minf(size.x / BASE.x, size.y / BASE.y)
		var off := (size - BASE * sc) / 2.0
		return off + Vector2(float(p[0]), float(p[1])) * sc

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = _hit(e.position)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover >= 0 else Control.CURSOR_ARROW
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var h := _hit(e.position)
			if h >= 0:
				region_clicked.emit(h)

	func _hit(p: Vector2) -> int:
		for i in DB.regions.size():
			if node_pos(i).distance_to(p) < 26:
				return i
		return -1

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var f: Font = UI.font if UI.font else get_theme_default_font()
		if bg:
			var bsc := minf(size.x / BASE.x, size.y / BASE.y)
			draw_rect(r, Color("123a63"))
			draw_texture_rect(bg, Rect2((size - BASE * bsc) / 2.0, BASE * bsc), false)
		else:
			draw_texture_rect(Art.gradient(Color("1d5f8f"), Color("123a63")), r, false)
			for i in 14:
				var y := fmod(i * 47.0 + t * 6.0, size.y)
				draw_line(Vector2(fmod(i * 131.0, size.x), y), Vector2(fmod(i * 131.0, size.x) + 40, y), Color(1, 1, 1, 0.08), 2)
			var sc := minf(size.x / BASE.x, size.y / BASE.y)
			for i in DB.regions.size():
				draw_circle(node_pos(i) + Vector2(4, 6) * sc, 74 * sc, Color(0, 0, 0, 0.18))
			for i in DB.regions.size():
				var c2 := Color(LAND[i % LAND.size()])
				draw_circle(node_pos(i), 70 * sc, c2.darkened(0.15))
				draw_circle(node_pos(i), 63 * sc, c2)
		for i in range(1, DB.regions.size()):
			var a := node_pos(i - 1)
			var b := node_pos(i)
			var open := Game.region_unlocked(i)
			var col := Color(1, 0.95, 0.7, 0.9) if open else Color(1, 1, 1, 0.3)
			var n := int(a.distance_to(b) / 14.0)
			for k in n:
				if k % 2 == 0:
					draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 4.0)
		for i in DB.regions.size():
			var p := node_pos(i)
			var open := Game.region_unlocked(i)
			var beaten := Game.badges.has(DB.region(i).id)
			var rad := 20.0
			if i == selected:
				draw_circle(p, rad + 9 + sin(t * 4.0) * 2.0, Color(1, 0.8, 0.1, 0.45))
			if Game.hunting and Game.hunting_region == i:
				draw_arc(p, rad + 14 + fmod(t * 20.0, 12.0), 0, TAU, 32, Color(0.3, 1, 0.5, 0.8 - fmod(t * 20.0, 12.0) / 15.0), 3.0, true)
			var fill := Color("ffcb05") if beaten else (Color("e8ecf8") if open else Color("555b70"))
			draw_circle(p, rad + 3, Color("1b1b1b"))
			draw_circle(p, rad, fill)
			if i == hover:
				draw_circle(p, rad, Color(1, 1, 1, 0.25))
			var label := str(i + 1) if open else "锁"
			draw_string(f, Vector2(p.x - 30, p.y + 6), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 17, Color("1b1b1b"))
			var nm: String = DB.region(i).name
			draw_string(f, Vector2(p.x - 70 + 1, p.y + rad + 22 + 1), nm, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(p.x - 70, p.y + rad + 22), nm, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color.WHITE if open else Color(1, 1, 1, 0.5))


func _ready() -> void:
	selected = Game.hunting_region if Game.region_unlocked(Game.hunting_region) else 0
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 12)
	add_child(margin)
	var h := UI.hbox(12)
	margin.add_child(h)

	var mp := UI.panel(Color("0e2440"), 12, 4, UI.BORDER)
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mp)
	map_view = MapView.new()
	map_view.selected = selected
	map_view.region_clicked.connect(_on_region)
	mp.add_child(map_view)

	var right := UI.vbox(10)
	right.custom_minimum_size.x = 360
	h.add_child(right)
	var ip := UI.panel()
	ip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ip)
	info = UI.vbox(8)
	ip.add_child(info)
	var lp := UI.panel()
	lp.custom_minimum_size.y = 170
	right.add_child(lp)
	var lv := UI.vbox(4)
	lp.add_child(lv)
	lv.add_child(UI.lbl("狩猎记录", 15, UI.ACCENT, true))
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 13)
	lv.add_child(log_label)

	Game.hunt_result.connect(_on_hunt)
	_build_info()
	_rebuild_log()


func _on_region(i: int) -> void:
	selected = i
	map_view.selected = i
	_build_info()


func _build_info() -> void:
	UI.clear(info)
	var r := DB.region(selected)
	var open := Game.region_unlocked(selected)
	var beaten := Game.badges.has(r.id)
	var t := UI.hbox(8)
	t.add_child(UI.lbl("%d. %s" % [selected + 1, r.name], 22, UI.ACCENT, true))
	t.add_child(UI.spacer())
	t.add_child(UI.pill("Lv.%d-%d" % [int(r.min), int(r.max)], UI.BLUE, 13))
	info.add_child(t)
	var d := UI.lbl(r.desc, 14, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(d)
	if not open:
		info.add_child(UI.lbl("尚未解锁：击败上一个地区的馆主「%s」后开放" % DB.region(selected - 1).boss.name, 14, UI.BAD))
		return

	info.add_child(UI.lbl("出没的宝可梦", 15, UI.TEXT, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var total := 0.0
	for w in r.wild:
		total += float(w[1])
	for w in r.wild:
		var sid: String = w[0]
		var cell := UI.vbox(0)
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(48, 48)
		p.setup(sid, false, not Game.seen.has(sid))
		cell.add_child(p)
		var pct := UI.lbl("%d%%" % int(round(float(w[1]) * 100.0 / total)), 11, UI.GOOD if Game.caught.has(sid) else UI.MUTED)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(pct)
		cell.tooltip_text = DB.species(sid).name if Game.seen.has(sid) else "???"
		flow.add_child(cell)
	info.add_child(flow)

	var bp := UI.panel(UI.PANEL2, 8, 8, Color.TRANSPARENT)
	var bv := UI.vbox(4)
	bp.add_child(bv)
	var bt := UI.hbox(6)
	bt.add_child(UI.lbl("馆主：" + r.boss.name, 15, UI.TEXT, true))
	bt.add_child(UI.spacer())
	bt.add_child(UI.pill("已击败" if beaten else "未击败", UI.GOOD if beaten else UI.BAD, 12))
	bv.add_child(bt)
	var team_txt := PackedStringArray()
	for e in r.boss.team:
		team_txt.append("%s Lv.%d" % [DB.species(e[0]).name, int(e[1])])
	var tl := UI.lbl("、".join(team_txt), 13, UI.MUTED)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(tl)
	info.add_child(bp)

	var b1 := UI.hbox(8)
	var wild_btn := UI.accent_btn("野外遭遇", main.open_battle.bind({"type": "wild", "region": selected}), 0, Color("e8533f"))
	wild_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.add_child(wild_btn)
	var gym_btn := UI.accent_btn("挑战馆主" if not beaten else "再次挑战", main.open_battle.bind({"type": "gym", "region": selected}), 0, Color("8a4fd8"))
	gym_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.add_child(gym_btn)
	info.add_child(b1)

	var here := Game.hunting and Game.hunting_region == selected
	var hunt_btn := UI.accent_btn("停止自动狩猎" if here else "在此自动狩猎", _toggle_hunt, 0, UI.BAD if here else UI.GOOD)
	info.add_child(hunt_btn)
	var hint := UI.lbl("自动狩猎每 %d 秒结算一场战斗（不消耗 HP），离线最多累积 12 小时收益。" % int(Game.HUNT_INTERVAL), 12, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(hint)

	var oc := UI.hbox(6)
	var opt := OptionButton.new()
	for i in CATCH_OPTIONS.size():
		opt.add_item(CATCH_OPTIONS[i][1], i)
		if int(CATCH_OPTIONS[i][0]) == Game.auto_catch_min:
			opt.select(i)
	opt.item_selected.connect(func(i: int): Game.auto_catch_min = int(CATCH_OPTIONS[i][0]))
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oc.add_child(opt)
	var bopt := OptionButton.new()
	var balls := ["poke_ball", "great_ball", "ultra_ball"]
	for i in balls.size():
		bopt.add_item(DB.item(balls[i]).name, i)
		if balls[i] == Game.auto_ball:
			bopt.select(i)
	bopt.item_selected.connect(func(i: int): Game.auto_ball = balls[i])
	oc.add_child(bopt)
	info.add_child(oc)


func _toggle_hunt() -> void:
	var here := Game.hunting and Game.hunting_region == selected
	Game.set_hunting(not here, selected)
	Game.notify("开始在【%s】自动狩猎" % DB.region(selected).name if not here else "已停止自动狩猎", UI.GOOD)
	_build_info()


func _on_hunt(_info: Dictionary) -> void:
	_rebuild_log()


func _rebuild_log() -> void:
	log_label.clear()
	if Game.hunt_log.is_empty():
		log_label.append_text("[color=#8f9bc0]还没有狩猎记录。选择地区并点击「在此自动狩猎」，队伍会自动战斗、获得经验和金币。[/color]")
		return
	for i in mini(12, Game.hunt_log.size()):
		var e: Dictionary = Game.hunt_log[i]
		var w: Monster = e.wild
		var rc: String = DB.rarity(w.rarity).color.to_html(false)
		var line := "[color=#%s]%s[/color] Lv.%d %s" % [rc, DB.rarity(w.rarity).name, w.level, w.display_name()]
		if w.shiny:
			line += " [color=#ffe14a]✦闪光[/color]"
		if e.win:
			line += "  [color=#4cd07d]胜利[/color] +%d经验 +%d金" % [int(e.xp), int(e.gold)]
		else:
			line += "  [color=#ff5d6c]失败[/color]"
		if e.caught:
			line += "  [color=#ffcb05]捕获成功！[/color]"
		elif int(e.balls) > 0:
			line += "  [color=#8f9bc0]逃走了（用掉%d个球）[/color]" % int(e.balls)
		log_label.append_text(line + "\n")
