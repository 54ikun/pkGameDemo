extends Control
## 挑战：道馆馆主 / 对战塔（无尽层数）/ 传说宝可梦降临（可捕捉）

var main


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 14)
	add_child(margin)
	var tabs := TabContainer.new()
	margin.add_child(tabs)
	var gyms := _gyms()
	gyms.name = "道馆挑战"
	tabs.add_child(gyms)
	var tower := _tower()
	tower.name = "对战塔"
	tabs.add_child(tower)
	var legend := _legends()
	legend.name = "传说降临"
	tabs.add_child(legend)


func _gyms() -> Control:
	var list := UI.vbox(8)
	for i in DB.regions.size():
		var r := DB.region(i)
		var open := Game.region_unlocked(i)
		var beaten := Game.badges.has(r.id)
		var p := UI.panel(UI.PANEL2 if open else UI.PANEL.darkened(0.2), 10, 10, Color.TRANSPARENT)
		var h := UI.hbox(12)
		p.add_child(h)
		var badge := UI.pill(str(i + 1), UI.ACCENT if beaten else (UI.BLUE if open else Color("555b70")), 16)
		badge.custom_minimum_size = Vector2(40, 0)
		h.add_child(badge)
		var info := UI.vbox(2)
		info.custom_minimum_size.x = 260
		info.add_child(UI.lbl(r.boss.name, 17, Color.WHITE if open else UI.MUTED, true))
		info.add_child(UI.lbl("%s  ·  推荐 Lv.%d+" % [r.name, int(r.max)], 13, UI.MUTED))
		h.add_child(info)
		var icons := UI.hbox(4)
		icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for e in r.boss.team:
			var cell := UI.vbox(0)
			var pt := Portrait.new()
			pt.custom_minimum_size = Vector2(44, 44)
			pt.setup(e[0], false, not open)
			cell.add_child(pt)
			var l := UI.lbl("Lv.%d" % int(e[1]), 11, UI.MUTED)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(l)
			icons.add_child(cell)
		h.add_child(icons)
		var reward := PackedStringArray(["%s金" % UI.fmt_num(int(r.boss.gold))])
		for iid in r.boss.get("items", {}):
			reward.append("%s×%d" % [DB.item(iid).name, int(r.boss.items[iid])])
		h.add_child(UI.lbl("首胜奖励：" + " ".join(reward), 12, UI.ACCENT))
		if beaten:
			h.add_child(UI.pill("已获得徽章", UI.GOOD, 12))
		var b := UI.accent_btn("挑战" if not beaten else "再战", main.open_battle.bind({"type": "gym", "region": i}), 90, Color("8a4fd8"))
		b.disabled = not open
		h.add_child(b)
		list.add_child(p)
	return UI.scroll(list)


func _tower() -> Control:
	var c := CenterContainer.new()
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var t := UI.lbl("对战塔 · 第 %d 层" % Game.tower_floor, 34, UI.ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var lv := Game.tower_level(Game.tower_floor)
	var cnt := 2 if Game.tower_floor < 5 else 3
	var lines := [
		"历史最高：第 %d 层" % Game.tower_best,
		"本层守卫：%d 只随机宝可梦，等级 Lv.%d，品质随层数提升" % [cnt, lv],
		"奖励：%s 金币；每 5 层额外获得神奇糖果，每 10 层获得高级球 ×3" % UI.fmt_num(150 * Game.tower_floor),
		"失败不会掉层，治疗后可以无限重试。",
	]
	for l in lines:
		var lb := UI.lbl(l, 16, UI.TEXT)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lb)
	var b := UI.accent_btn("挑战第 %d 层" % Game.tower_floor, main.open_battle.bind({"type": "tower"}), 260, Color("e8533f"))
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size.y = 52
	var bc := CenterContainer.new()
	bc.add_child(b)
	v.add_child(bc)
	return c


func _legends() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	for i in DB.legends.size():
		var lg: Dictionary = DB.legends[i]
		var open := Game.legend_unlocked(i)
		var state: String = Game.legends_done.get(lg.species, "")
		var v := UI.vbox(6)
		var card := MonsterCard.of_species(lg.species, int(lg.rarity), int(lg.level), 0.85)
		card.silhouette = not open
		card.refresh()
		v.add_child(card)
		var d := UI.lbl(lg.desc if open else "需要 %d 枚徽章" % int(lg.badges), 12, UI.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = MonsterCard.W * 0.85
		v.add_child(d)
		if state == "caught":
			v.add_child(UI.pill("已捕获", UI.GOOD))
		elif state == "defeated":
			v.add_child(UI.pill("已击退（可再次挑战捕捉）", UI.BLUE, 11))
		var b := UI.accent_btn("挑战" if state != "caught" else "再次挑战", main.open_battle.bind({"type": "legend", "legend": i}), 0, Color("8a4fd8"))
		b.disabled = not open
		v.add_child(b)
		flow.add_child(v)
	var outer := UI.vbox(10)
	var tip := UI.lbl("传说宝可梦可以用精灵球捕捉（捕获率极低，削弱 HP 并使其陷入异常状态会更容易，大师球必定成功）。击败冠军可获得大师球。", 14, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(tip)
	outer.add_child(flow)
	return UI.scroll(outer)
