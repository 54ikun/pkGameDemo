extends Control
## 宝可梦详情：大卡牌 + 个体值/能力值 + 技能配置 + 进化 / 糖果 / 队伍操作 / 放生

signal closed

var monster: Monster
var main
var panel: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = UI.panel(UI.PANEL, 16, 18, DB.rarity(monster.rarity).color.darkened(0.2))
	center.add_child(panel)
	_build()


func _close() -> void:
	closed.emit()
	queue_free()


func _build() -> void:
	UI.clear(panel)
	var m := monster
	var root := UI.vbox(12)
	panel.add_child(root)
	var cols := UI.hbox(20)
	root.add_child(cols)

	# 左：卡牌 + 改名
	var left := UI.vbox(10)
	cols.add_child(left)
	var card := MonsterCard.of_monster(m, 1.3)
	card.show_hp = false
	left.add_child(card)
	var rn := UI.hbox(6)
	var le := LineEdit.new()
	le.placeholder_text = "给它起个昵称"
	le.text = m.nickname
	le.max_length = 10
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rn.add_child(le)
	rn.add_child(UI.btn("改名", func():
		m.nickname = le.text.strip_edges()
		Game.changed.emit()
		_build()))
	left.add_child(rn)

	# 中：信息
	var mid := UI.vbox(8)
	mid.custom_minimum_size.x = 360
	cols.add_child(mid)
	var t1 := UI.hbox(8)
	t1.add_child(UI.lbl(m.display_name(), 26, Color.WHITE, true))
	t1.add_child(UI.lbl("Lv.%d" % m.level, 20, UI.ACCENT, true))
	mid.add_child(t1)
	var tags := UI.hbox(6)
	tags.add_child(UI.rarity_pill(m.rarity, 14))
	for t in m.types():
		tags.add_child(UI.type_pill(t, 14))
	if m.shiny:
		tags.add_child(UI.pill("✦ 闪光", Color("ffe14a"), 14))
	if Game.team.find(m) == 0:
		tags.add_child(UI.pill("首发", UI.ACCENT, 14))
	mid.add_child(tags)
	var nat: Array = DB.NATURES[m.nature]
	var nat_txt: String = "性格：%s" % nat[0]
	if nat[1] != "":
		nat_txt += "（%s↑  %s↓）" % [DB.STAT_NAMES[nat[1]], DB.STAT_NAMES[nat[2]]]
	mid.add_child(UI.lbl(nat_txt, 15))
	mid.add_child(UI.lbl("个体值 %d%%   ·   战力 %s   ·   品质加成 +%d%%" % [m.iv_percent(), UI.fmt_num(m.power()), int(round((DB.rarity_mult(m.rarity) * (DB.SHINY_MULT if m.shiny else 1.0) - 1.0) * 100))], 15, UI.MUTED))
	var xr := UI.hbox(8)
	xr.add_child(UI.lbl("经验", 14, UI.MUTED))
	var xb := UI.bar(m.xp_progress(), 1.0, Color("4aa3ff"), 220, 10)
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xr.add_child(xb)
	var need := "已满级" if m.level >= 100 else "还需 %s" % UI.fmt_num(DB.xp_for_level(m.level + 1) - m.xp)
	xr.add_child(UI.lbl(need, 13, UI.MUTED))
	mid.add_child(xr)
	var hr := UI.hbox(8)
	hr.add_child(UI.lbl("HP", 14, UI.MUTED))
	var hb := UI.bar(m.hp, m.max_hp(), UI.hp_color(float(m.hp) / maxf(1, m.max_hp())), 220, 10)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(hb)
	hr.add_child(UI.lbl("%d/%d" % [m.hp, m.max_hp()], 13, UI.MUTED))
	mid.add_child(hr)

	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	for h in ["能力", "种族值", "个体值", "", "能力值"]:
		g.add_child(UI.lbl(h, 13, UI.MUTED))
	for s in DB.STATS:
		var col := UI.TEXT
		var arrow := ""
		if nat[1] == s:
			col = Color("ff8a7a")
			arrow = "↑"
		elif nat[2] == s:
			col = Color("7ab8ff")
			arrow = "↓"
		g.add_child(UI.lbl(DB.STAT_NAMES[s] + arrow, 15, col))
		g.add_child(UI.lbl(str(int(m.species().base[s])), 15))
		var iv := int(m.ivs[s])
		g.add_child(UI.lbl(str(iv), 15, UI.ACCENT if iv >= 30 else UI.TEXT))
		g.add_child(UI.bar(iv, 31, Color("ffcb05") if iv >= 25 else Color("7a88b8"), 70, 8))
		g.add_child(UI.lbl(str(m.stat(s)), 15, col, true))
	mid.add_child(g)
	var evo: Dictionary = m.species().get("evolve", {})
	if not evo.is_empty():
		var en: String = DB.species(evo.to).get("name", evo.to)
		if m.evolution_target() != "":
			mid.add_child(UI.accent_btn("可以进化为 %s！立即进化" % en, _evolve))
		else:
			mid.add_child(UI.lbl("Lv.%d 时进化为 %s" % [int(evo.level), en], 14, UI.MUTED))
	else:
		mid.add_child(UI.lbl("最终形态", 14, UI.MUTED))

	# 右：技能
	var right := UI.vbox(6)
	right.custom_minimum_size.x = 290
	cols.add_child(right)
	right.add_child(UI.lbl("出战技能（%d/4）" % m.moves.size(), 17, UI.ACCENT, true))
	for mid_id in m.moves:
		right.add_child(_move_row(mid_id, true))
	right.add_child(UI.lbl("已领悟的其它技能", 15, UI.MUTED, true))
	var others := UI.vbox(4)
	for mid_id in m.learnable_moves():
		if not m.moves.has(mid_id):
			others.add_child(_move_row(mid_id, false))
	if others.get_child_count() == 0:
		others.add_child(UI.lbl("暂无", 13, UI.MUTED))
	var sc := UI.scroll(others)
	sc.custom_minimum_size.y = 150
	right.add_child(sc)
	var nxt := ""
	for e in m.learnset():
		if int(e[0]) > m.level:
			nxt = "下一个技能：Lv.%d %s" % [int(e[0]), DB.move(e[1]).name]
			break
	if nxt != "":
		right.add_child(UI.lbl(nxt, 13, UI.MUTED))

	# 底部按钮
	var bh := UI.hbox(10)
	root.add_child(bh)
	var in_team := Game.in_team(m)
	if Game.team.find(m) != 0:
		bh.add_child(UI.btn("设为首发", func():
			Game.set_lead(m)
			_build()))
	if in_team:
		var b := UI.btn("放入仓库", func():
			if Game.move_to_box(m):
				_build())
		b.disabled = Game.team.size() <= 1
		bh.add_child(b)
	else:
		var b2 := UI.btn("加入队伍", func():
			if Game.move_to_team(m):
				_build()
			else:
				Game.notify("队伍已满（最多 6 只）", UI.BAD))
		bh.add_child(b2)
	var candy := Game.item_count("rare_candy")
	var cb := UI.btn("神奇糖果（%d）" % candy, _use.bind("rare_candy"))
	cb.disabled = candy <= 0 or m.level >= 100
	bh.add_child(cb)
	for iid in ["potion", "super_potion", "max_potion", "revive"]:
		if Game.item_count(iid) > 0:
			bh.add_child(UI.btn("%s（%d）" % [DB.item(iid).name, Game.item_count(iid)], _use.bind(iid)))
			break
	bh.add_child(UI.spacer())
	var rel := UI.btn("放生", _release)
	rel.add_theme_color_override("font_color", UI.BAD)
	bh.add_child(rel)
	bh.add_child(UI.accent_btn("关闭", _close, 100))


func _move_row(mid_id: String, equipped: bool) -> Control:
	var mv := DB.move(mid_id)
	var p := UI.panel(UI.PANEL2, 8, 6, Color.TRANSPARENT)
	var h := UI.hbox(6)
	p.add_child(h)
	h.add_child(UI.type_pill(mv.type, 12))
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.lbl(mv.name, 15, Color.WHITE, true))
	var cat := {"physical": "物理", "special": "特殊", "status": "变化"}
	var detail := "%s  威力 %s  命中 %s" % [cat.get(mv.cat, ""), "-" if int(mv.power) == 0 else str(int(mv.power)), "必中" if int(mv.acc) == 0 else str(int(mv.acc))]
	info.add_child(UI.lbl(detail, 12, UI.MUTED))
	h.add_child(info)
	if equipped:
		var b := UI.btn("卸下", func():
			monster.moves.erase(mid_id)
			_build(), 0, 13)
		b.disabled = monster.moves.size() <= 1
		h.add_child(b)
	else:
		var b2 := UI.btn("装备", func():
			if monster.moves.size() < 4:
				monster.moves.append(mid_id)
				_build()
			else:
				Game.notify("最多装备 4 个技能，请先卸下一个", UI.BAD), 0, 13)
		h.add_child(b2)
	return p


func _use(iid: String) -> void:
	var r := Game.use_item_on(iid, monster)
	Game.notify(r.text, UI.GOOD if r.ok else UI.BAD)
	_build()


func _evolve() -> void:
	var old := monster.display_name()
	monster.evolve()
	Game.caught[monster.species_id] = true
	Game.seen[monster.species_id] = true
	Game.changed.emit()
	Game.notify("%s 进化成了 %s！" % [old, monster.display_name()], UI.ACCENT)
	_build()


func _release() -> void:
	if Game.team.size() <= 1 and Game.in_team(monster):
		Game.notify("队伍里至少要保留一只宝可梦", UI.BAD)
		return
	main.confirm("放生", "确定要放生 %s 吗？放生后无法找回（获得 %d 金币）。" % [monster.display_name(), 50 + monster.level * 10], func():
		Game.release(monster)
		_close())
