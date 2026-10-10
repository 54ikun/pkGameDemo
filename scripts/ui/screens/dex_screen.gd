extends Control
## 图鉴：所有物种卡牌（未遇见为剪影，遇见未捕获为暗色）

var main
var grid: GridContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 14)
	add_child(margin)
	var v := UI.vbox(10)
	margin.add_child(v)
	var h := UI.hbox(14)
	h.add_child(UI.lbl("宝可梦图鉴", 20, UI.ACCENT, true))
	var seen_n := 0
	var caught_n := 0
	for sid in DB.species_order:
		if Game.seen.has(sid):
			seen_n += 1
		if Game.caught.has(sid):
			caught_n += 1
	h.add_child(UI.lbl("已遇见 %d  ·  已捕获 %d  ·  共 %d 种" % [seen_n, caught_n, DB.species_order.size()], 15, UI.MUTED))
	v.add_child(h)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(UI.scroll(grid))
	for sid in DB.species_order:
		var c := MonsterCard.of_species(sid, 0, 0, 0.6)
		c.silhouette = not Game.seen.has(sid)
		c.dim = Game.seen.has(sid) and not Game.caught.has(sid)
		c.refresh()
		c.pressed.connect(_open.bind(sid))
		grid.add_child(c)
	resized.connect(_update_cols)
	_update_cols.call_deferred()


func _update_cols() -> void:
	grid.columns = maxi(1, int((size.x - 40) / (MonsterCard.W * 0.6 + 10)))


func _open(_card, sid: String) -> void:
	if not Game.seen.has(sid):
		Game.notify("还没有遇见过这只宝可梦", UI.MUTED)
		return
	var sp := DB.species(sid)
	var h := UI.hbox(18)
	h.add_child(MonsterCard.of_species(sid, 0, 0, 1.0))
	var v := UI.vbox(6)
	v.custom_minimum_size.x = 380
	h.add_child(v)
	v.add_child(UI.lbl("No.%03d  %s" % [int(sp.dex), sp.name], 20, Color.WHITE, true))
	var tags := UI.hbox(6)
	for t in sp.types:
		tags.add_child(UI.type_pill(t))
	if sp.get("legendary", false):
		tags.add_child(UI.pill("传说", Color("ff9f1c")))
	v.add_child(tags)
	v.add_child(UI.lbl("种族值总和 %d   ·   捕获率 %d" % [DB.base_total(sid), int(sp.catch_rate)], 14, UI.MUTED))
	var evo: Dictionary = sp.get("evolve", {})
	if not evo.is_empty():
		v.add_child(UI.lbl("Lv.%d 进化为 %s" % [int(evo.level), DB.species(evo.to).name], 14))
	var where := PackedStringArray()
	for r in DB.regions:
		for w in r.wild:
			if w[0] == sid:
				where.append(r.name)
	v.add_child(UI.lbl("出没地区：" + ("、".join(where) if where.size() > 0 else "野外未发现"), 14, UI.GOOD))
	var ms := PackedStringArray()
	for e in sp.learnset:
		ms.append("Lv.%d %s" % [int(e[0]), DB.move(e[1]).name])
	var ml := UI.lbl("可学技能：" + "、".join(ms), 13, UI.MUTED)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ml)
	main.popup(sp.name, h, [["关闭", null]], 640)
