extends Control
## 背包：查看道具，并对队伍中的宝可梦使用

var main


class ItemIcon extends Control:
	var iid := ""

	func _draw() -> void:
		var tex := Art.item_icon(iid)
		if tex:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			return
		var it := DB.item(iid)
		var c := size / 2.0
		match str(it.kind):
			"ball":
				Art.draw_ball(self, c, size.x * 0.4, Art.ball_color(iid))
			"heal", "revive":
				draw_rect(Rect2(c.x - size.x * 0.22, c.y - size.y * 0.3, size.x * 0.44, size.y * 0.62), Color("7b5cff") if iid != "potion" else Color("b04ad8"))
				draw_rect(Rect2(c.x - size.x * 0.12, c.y - size.y * 0.42, size.x * 0.24, size.y * 0.14), Color("dddddd"))
				if it.kind == "revive":
					Art.draw_star(self, c, size.x * 0.25, Color("ffe14a"))
			"candy":
				draw_circle(c, size.x * 0.3, Color("6ad0ff"))
				draw_circle(c + Vector2(-4, -4), size.x * 0.1, Color(1, 1, 1, 0.6))


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 14)
	add_child(margin)
	var v := UI.vbox(10)
	margin.add_child(v)
	v.add_child(UI.lbl("背包", 20, UI.ACCENT, true))
	var list := UI.vbox(8)
	v.add_child(UI.scroll(list))
	var keys: Array = DB.items_db.keys()
	var any := false
	for iid in keys:
		var n := Game.item_count(iid)
		if n <= 0:
			continue
		any = true
		list.add_child(_row(iid, n))
	if not any:
		list.add_child(UI.lbl("背包空空如也，去商店看看吧。", 15, UI.MUTED))


static func icon(iid: String, sz: int = 44) -> Control:
	var ic := ItemIcon.new()
	ic.iid = iid
	ic.custom_minimum_size = Vector2(sz, sz)
	return ic


func _row(iid: String, n: int) -> Control:
	var it := DB.item(iid)
	var p := UI.panel(UI.PANEL, 10, 10)
	var h := UI.hbox(12)
	p.add_child(h)
	h.add_child(icon(iid))
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.lbl(it.name, 17, Color.WHITE, true))
	info.add_child(UI.lbl(it.desc, 13, UI.MUTED))
	h.add_child(info)
	h.add_child(UI.lbl("×%d" % n, 18, UI.ACCENT, true))
	if it.kind in ["heal", "revive", "candy"]:
		h.add_child(UI.btn("使用", _pick_target.bind(iid), 90))
	return p


func _pick_target(iid: String) -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	var layer: Control = main.popup("对谁使用 %s？" % DB.item(iid).name, g, [["取消", null]], 600)
	for m in Game.team:
		var b := UI.btn("%s  Lv.%d\nHP %d/%d" % [m.display_name(), m.level, m.hp, m.max_hp()], Callable(), 180)
		b.pressed.connect(_use_on.bind(iid, m, layer))
		g.add_child(b)


func _use_on(iid: String, m: Monster, layer: Control) -> void:
	var r := Game.use_item_on(iid, m)
	Game.notify(r.text, UI.GOOD if r.ok else UI.BAD)
	layer.queue_free()
	main.show_screen("bag")
