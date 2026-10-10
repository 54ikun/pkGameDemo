class_name MonsterCard
extends Control
## 宝可梦卡牌：外层【品质框】（颜色/贴图随品质变化）+ 内层【属性框】（随属性变化）
## + 立绘槽（放图即替换）+ 名称/等级/属性/能力值。
## 可显示一只具体的个体（setup_monster），也可显示物种模板（setup_species，用于图鉴/编辑器）。

signal pressed(card: MonsterCard)

const W := 180.0
const H := 250.0

var monster: Monster
var species_id := ""
var rarity := 0
var shiny := false
var level := 0
var card_scale := 1.0
var selected := false
var silhouette := false
var dim := false
var badge := ""
var show_hp := false

var _portrait: Portrait
var _hover := false


static func of_monster(m: Monster, sc: float = 1.0) -> MonsterCard:
	var c := MonsterCard.new()
	c.card_scale = sc
	c.setup_monster(m)
	return c


static func of_species(sid: String, rar: int = 0, lv: int = 0, sc: float = 1.0, is_shiny: bool = false) -> MonsterCard:
	var c := MonsterCard.new()
	c.card_scale = sc
	c.setup_species(sid, rar, lv, is_shiny)
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_portrait = Portrait.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(v: bool) -> void:
	_hover = v
	queue_redraw()


func setup_monster(m: Monster) -> void:
	monster = m
	species_id = m.species_id
	rarity = m.rarity
	shiny = m.shiny
	level = m.level
	refresh()


func setup_species(sid: String, rar: int = 0, lv: int = 0, is_shiny: bool = false) -> void:
	monster = null
	species_id = sid
	rarity = rar
	level = lv
	shiny = is_shiny
	refresh()


func refresh() -> void:
	if monster:
		species_id = monster.species_id
		rarity = monster.rarity
		shiny = monster.shiny
		level = monster.level
	var s := card_scale
	custom_minimum_size = Vector2(W, H) * s
	size = custom_minimum_size
	_portrait.position = Vector2(13, 38) * s
	_portrait.size = Vector2(W - 26, 124) * s
	_portrait.setup(species_id, shiny, silhouette)
	tooltip_text = ""
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _draw() -> void:
	if species_id == "":
		return
	var s := card_scale
	var sp := DB.species(species_id)
	var rd := DB.rarity(rarity)
	var rc: Color = rd.color
	var rect := Rect2(Vector2.ZERO, Vector2(W, H) * s)
	var f: Font = UI.font if UI.font else get_theme_default_font()
	var fb: Font = UI.font_bold if UI.font_bold else f

	if selected:
		draw_style_box(UI.style(Color.TRANSPARENT, int(16 * s), UI.ACCENT, maxi(2, int(4 * s))), rect.grow(4 * s))
	if rarity >= 3 and not silhouette:
		for i in 3:
			draw_style_box(UI.style(Color(rc, 0.10 + i * 0.04), int(16 * s)), rect.grow((3 - i) * 2.0 * s))

	# 品质框（无贴图时用纯色描边；有贴图时在属性框之后叠加绘制）
	var ftex: Texture2D = null if silhouette else Art.frame_rarity(rarity)
	var frame_col := Color(0.25, 0.27, 0.35) if silhouette else rc
	draw_style_box(UI.style(frame_col.darkened(0.45), int(14 * s), frame_col, 0 if ftex else maxi(2, int(3 * s))), rect)

	# 属性框
	var inner := rect.grow(-7 * s)
	var types: Array = sp.get("types", ["normal"])
	var ttex := Art.frame_type(types[0])
	if silhouette:
		draw_style_box(UI.style(Color(0.12, 0.13, 0.2), int(9 * s)), inner)
	elif ttex:
		draw_texture_rect(ttex, inner, false)
	else:
		var c1 := DB.type_color(types[0])
		var c2 := DB.type_color(types[1]) if types.size() > 1 else c1.darkened(0.55)
		draw_texture_rect(Art.gradient(c1.darkened(0.05), c2.darkened(0.35)), inner, false)
		var wc := inner.position + Vector2(inner.size.x * 0.5, 100 * s)
		draw_arc(wc, 58 * s, 0, TAU, 48, Color(1, 1, 1, 0.10), 6 * s, true)
		draw_line(wc - Vector2(58 * s, 0), wc + Vector2(58 * s, 0), Color(1, 1, 1, 0.10), 6 * s)
		draw_arc(wc, 16 * s, 0, TAU, 24, Color(1, 1, 1, 0.10), 5 * s, true)
	if ftex:
		draw_texture_rect(ftex, rect, false)

	# 标题栏
	var hdr := Rect2(inner.position, Vector2(inner.size.x, 26 * s))
	draw_rect(hdr, Color(0, 0, 0, 0.38))
	var name_txt := "???" if silhouette else (monster.display_name() if monster else str(sp.get("name", species_id)))
	draw_string(fb, inner.position + Vector2(6 * s, 19 * s), name_txt, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 54 * s, int(15 * s), Color.WHITE)
	if level > 0:
		draw_string(f, Vector2(inner.position.x, inner.position.y + 19 * s), "Lv.%d" % level, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 6 * s, int(13 * s), UI.ACCENT)
	elif not silhouette:
		draw_string(f, Vector2(inner.position.x, inner.position.y + 19 * s), "No.%03d" % int(sp.get("dex", 0)), HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 6 * s, int(12 * s), Color(1, 1, 1, 0.7))

	# 品质角标
	if not silhouette:
		var rtxt: String = rd.name + ("·闪" if shiny else "")
		var rw := f.get_string_size(rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s)).x + 10 * s
		var rr := Rect2(inner.position + Vector2(4 * s, 30 * s), Vector2(rw, 16 * s))
		draw_style_box(UI.style(rc, int(8 * s)), rr)
		draw_string(fb, rr.position + Vector2(0, 12 * s), rtxt, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(11 * s), Color("151515") if rc.get_luminance() > 0.55 else Color.WHITE)
	if badge != "":
		var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s)).x + 10 * s
		var br := Rect2(Vector2(inner.end.x - bw - 4 * s, inner.position.y + 30 * s), Vector2(bw, 16 * s))
		draw_style_box(UI.style(UI.ACCENT, int(8 * s)), br)
		draw_string(fb, br.position + Vector2(0, 12 * s), badge, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, int(11 * s), Color("151515"))

	# 属性标签
	var tx := inner.position.x + 6 * s
	var ty := inner.position.y + 160 * s
	if not silhouette:
		for t in types:
			var tn := DB.type_name(t)
			var tw := f.get_string_size(tn, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s)).x + 14 * s
			var tr := Rect2(tx, ty, tw, 17 * s)
			var tc := DB.type_color(t)
			draw_style_box(UI.style(tc.darkened(0.1), int(8 * s), Color(1, 1, 1, 0.5), maxi(1, int(s))), tr)
			draw_string(fb, tr.position + Vector2(0, 13 * s), tn, HORIZONTAL_ALIGNMENT_CENTER, tw, int(12 * s), Color.WHITE)
			tx += tw + 4 * s
		if monster:
			var ivt := "IV %d%%" % monster.iv_percent()
			draw_string(f, Vector2(inner.position.x, ty + 13 * s), ivt, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 6 * s, int(11 * s), Color(1, 1, 1, 0.85))

	# 能力值面板
	var sr := Rect2(inner.position.x + 4 * s, inner.position.y + 181 * s, inner.size.x - 8 * s, inner.size.y - 185 * s)
	draw_style_box(UI.style(Color(0, 0, 0, 0.42), int(6 * s)), sr)
	if show_hp and monster:
		var ratio := float(monster.hp) / float(maxi(1, monster.max_hp()))
		var hb := Rect2(sr.position.x + 6 * s, sr.position.y + 6 * s, sr.size.x - 12 * s, 7 * s)
		draw_rect(hb, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * ratio, hb.size.y)), UI.hp_color(ratio))
		var st := "HP %d/%d" % [monster.hp, monster.max_hp()]
		if monster.status != "":
			st += "  " + DB.STATUS_NAMES.get(monster.status, "")
		draw_string(f, Vector2(sr.position.x, sr.position.y + 30 * s), st, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(12 * s), Color.WHITE)
		draw_string(f, Vector2(sr.position.x, sr.position.y + 46 * s), "战力 %d" % monster.power(), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(11 * s), UI.ACCENT)
	else:
		var cw := sr.size.x / 3.0
		for i in 6:
			var key: String = DB.STATS[i]
			var val := "?"
			if not silhouette:
				val = str(monster.stat(key)) if monster else str(int(sp.get("base", {}).get(key, 0)))
			var cx := sr.position.x + (i % 3) * cw
			var cy := sr.position.y + (16 if i < 3 else 36) * s
			draw_string(f, Vector2(cx + 4 * s, cy), DB.STAT_SHORT[key], HORIZONTAL_ALIGNMENT_LEFT, cw, int(10 * s), Color(1, 1, 1, 0.6))
			draw_string(fb, Vector2(cx, cy), val, HORIZONTAL_ALIGNMENT_RIGHT, cw - 5 * s, int(12 * s), Color.WHITE)
		if monster and monster.hp < monster.max_hp():
			var ratio2 := float(monster.hp) / float(maxi(1, monster.max_hp()))
			draw_rect(Rect2(sr.position.x + 4 * s, sr.end.y - 6 * s, (sr.size.x - 8 * s) * ratio2, 3 * s), UI.hp_color(ratio2))

	if _hover:
		draw_style_box(UI.style(Color(1, 1, 1, 0.07), int(14 * s)), rect)
	if dim:
		draw_style_box(UI.style(Color(0, 0, 0, 0.5), int(14 * s)), rect)
	if monster and monster.is_fainted():
		draw_style_box(UI.style(Color(0.3, 0, 0, 0.45), int(14 * s)), rect)
		draw_string(fb, Vector2(0, rect.size.y * 0.45), "濒死", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(22 * s), UI.BAD)
