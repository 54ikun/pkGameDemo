extends Control
## 卡牌编辑器：修改物种的名称 / 属性 / 种族值 / 捕获率 / 进化 / 立绘路径，实时预览卡牌（各品质框）

var main
var list: ItemList
var search: LineEdit
var form: VBoxContainer
var preview_holder: CenterContainer
var sid := ""
var dirty := false
var ids: Array = []

var f_name: LineEdit
var f_dex: SpinBox
var f_t1: OptionButton
var f_t2: OptionButton
var f_stats := {}
var f_total: Label
var f_catch: SpinBox
var f_evo: OptionButton
var f_evo_lv: SpinBox
var f_legend: CheckBox
var f_image: LineEdit
var p_rarity: OptionButton
var p_shiny: CheckBox
var p_level: SpinBox
var type_keys: Array = []


func _ready() -> void:
	type_keys = DB.TYPES.keys()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 12)
	add_child(margin)
	var h := UI.hbox(12)
	margin.add_child(h)

	var left := UI.vbox(6)
	left.custom_minimum_size.x = 210
	h.add_child(left)
	left.add_child(UI.lbl("物种列表", 17, UI.ACCENT, true))
	search = LineEdit.new()
	search.placeholder_text = "搜索名称 / ID"
	search.text_changed.connect(func(_t): _fill_list())
	left.add_child(search)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_pick)
	left.add_child(list)

	var midp := UI.panel()
	midp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(midp)
	form = UI.vbox(8)
	midp.add_child(UI.scroll(form))

	var right := UI.vbox(10)
	right.custom_minimum_size.x = 270
	h.add_child(right)
	right.add_child(UI.lbl("卡牌预览", 17, UI.ACCENT, true))
	preview_holder = CenterContainer.new()
	preview_holder.custom_minimum_size = Vector2(260, 330)
	right.add_child(preview_holder)
	var pr := UI.hbox(6)
	p_rarity = OptionButton.new()
	for i in DB.RARITIES.size():
		p_rarity.add_item("品质框：" + DB.rarity(i).name, i)
	p_rarity.select(3)
	p_rarity.item_selected.connect(func(_i): _preview())
	pr.add_child(p_rarity)
	p_shiny = CheckBox.new()
	p_shiny.text = "闪光"
	p_shiny.toggled.connect(func(_v): _preview())
	pr.add_child(p_shiny)
	right.add_child(pr)
	var lr := UI.hbox(6)
	lr.add_child(UI.lbl("预览等级", 14))
	p_level = SpinBox.new()
	p_level.min_value = 1
	p_level.max_value = 100
	p_level.value = 50
	p_level.value_changed.connect(func(_v): _preview())
	lr.add_child(p_level)
	right.add_child(lr)
	var tip := UI.lbl("美术替换：\n· 立绘 assets/pokemon/<ID>.png\n· 品质框 assets/ui/frames/rarity_<品质>.png\n· 属性框 assets/ui/frames/type_<属性>.png\n放入图片后点「刷新图片」即可看到效果。", 12, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)

	tree_exiting.connect(_discard)
	_fill_list()
	if ids.size() > 0:
		list.select(0)
		_on_pick(0)


func _fill_list() -> void:
	list.clear()
	ids.clear()
	var q := search.text.strip_edges().to_lower()
	for s in DB.species_order:
		var sp := DB.species(s)
		var label := "%03d %s%s" % [int(sp.dex), sp.name, " *" if DB.has_override(s) else ""]
		if q != "" and not (label.to_lower().contains(q) or s.contains(q)):
			continue
		list.add_item(label)
		ids.append(s)


func _discard() -> void:
	if dirty:
		DB._rebuild_species()
		dirty = false


func _on_pick(i: int) -> void:
	_discard()
	sid = ids[i]
	_build_form()
	_preview()


func _row(label: String, ctrl: Control) -> HBoxContainer:
	var r := UI.hbox(8)
	var l := UI.lbl(label, 15, UI.MUTED)
	l.custom_minimum_size.x = 90
	r.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctrl)
	form.add_child(r)
	return r


func _spin(lo: float, hi: float, v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = v
	s.value_changed.connect(func(_x): _apply())
	return s


func _build_form() -> void:
	UI.clear(form)
	var sp := DB.species(sid)
	form.add_child(UI.lbl("编辑：%s（ID: %s）" % [sp.name, sid], 19, UI.ACCENT, true))
	f_name = LineEdit.new()
	f_name.text = sp.name
	f_name.text_changed.connect(func(_t): _apply())
	_row("名称", f_name)
	f_dex = _spin(0, 9999, int(sp.dex))
	_row("图鉴编号", f_dex)
	f_t1 = OptionButton.new()
	f_t2 = OptionButton.new()
	f_t2.add_item("（无）", 0)
	for i in type_keys.size():
		f_t1.add_item(DB.type_name(type_keys[i]), i)
		f_t2.add_item(DB.type_name(type_keys[i]), i + 1)
	f_t1.select(type_keys.find(sp.types[0]))
	f_t2.select(type_keys.find(sp.types[1]) + 1 if sp.types.size() > 1 else 0)
	f_t1.item_selected.connect(func(_i): _apply())
	f_t2.item_selected.connect(func(_i): _apply())
	_row("属性 1", f_t1)
	_row("属性 2", f_t2)

	form.add_child(UI.lbl("种族值（决定能力上限，1~255）", 15, UI.TEXT, true))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 10)
	f_stats = {}
	for s in DB.STATS:
		g.add_child(UI.lbl(DB.STAT_NAMES[s], 14, UI.MUTED))
		var sb := _spin(1, 255, int(sp.base[s]))
		f_stats[s] = sb
		g.add_child(sb)
	form.add_child(g)
	f_total = UI.lbl("", 14, UI.ACCENT)
	form.add_child(f_total)

	f_catch = _spin(1, 255, int(sp.catch_rate))
	_row("捕获率", f_catch)
	f_evo = OptionButton.new()
	f_evo.add_item("（不进化）", 0)
	var evo: Dictionary = sp.get("evolve", {})
	for i in DB.species_order.size():
		var o: String = DB.species_order[i]
		f_evo.add_item(DB.species(o).name, i + 1)
		if evo.get("to", "") == o:
			f_evo.select(i + 1)
	f_evo.item_selected.connect(func(_i): _apply())
	_row("进化为", f_evo)
	f_evo_lv = _spin(2, 100, int(evo.get("level", 30)))
	_row("进化等级", f_evo_lv)
	f_legend = CheckBox.new()
	f_legend.text = "传说宝可梦（不会被自动捕捉、不出现在对战塔）"
	f_legend.button_pressed = sp.get("legendary", false)
	f_legend.toggled.connect(func(_v): _apply())
	_row("稀有度", f_legend)
	f_image = LineEdit.new()
	f_image.placeholder_text = "留空则使用 res://assets/pokemon/%s.png" % sid
	f_image.text = str(sp.get("image", ""))
	f_image.text_changed.connect(func(_t): _apply())
	_row("立绘路径", f_image)

	var bh := UI.hbox(8)
	bh.add_child(UI.accent_btn("保存修改", _save))
	bh.add_child(UI.btn("还原默认", _reset))
	bh.add_child(UI.btn("刷新图片", func():
		Art.clear_cache()
		_preview()))
	var exp := UI.btn("写回 data/species.json", _export)
	exp.disabled = not OS.has_feature("editor")
	exp.tooltip_text = "仅在 Godot 编辑器中运行时可用，会把当前所有物种数据（含修改）写回项目文件"
	bh.add_child(exp)
	form.add_child(bh)
	var note := UI.lbl("保存后写入 user://mods/species_overrides.json，所有同物种的个体立即生效（重新计算能力值）。技能表、地区出没表请直接编辑 data/ 目录下的 JSON。", 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(note)
	_update_total()


func _collect() -> Dictionary:
	var types: Array = [type_keys[f_t1.get_selected_id()]]
	var t2 := f_t2.get_selected_id()
	if t2 > 0 and type_keys[t2 - 1] != types[0]:
		types.append(type_keys[t2 - 1])
	var base := {}
	for s in DB.STATS:
		base[s] = int(f_stats[s].value)
	var d := {
		"name": f_name.text.strip_edges() if f_name.text.strip_edges() != "" else sid,
		"dex": int(f_dex.value), "types": types, "base": base, "catch_rate": int(f_catch.value),
		"legendary": f_legend.button_pressed, "image": f_image.text.strip_edges(),
	}
	var ei := f_evo.get_selected_id()
	if ei > 0:
		d["evolve"] = {"to": DB.species_order[ei - 1], "level": int(f_evo_lv.value)}
	else:
		d["evolve"] = {}
	return d


func _apply() -> void:
	if sid == "" or f_image == null:
		return
	var d := _collect()
	var sp: Dictionary = DB.species_db[sid]
	for k in d:
		sp[k] = d[k]
	dirty = true
	_update_total()
	_preview()


func _update_total() -> void:
	var t := 0
	for s in DB.STATS:
		t += int(f_stats[s].value)
	f_total.text = "种族值总和：%d" % t


func _preview() -> void:
	if preview_holder == null or sid == "":
		return
	UI.clear(preview_holder)
	var c := MonsterCard.of_species(sid, p_rarity.get_selected_id(), int(p_level.value), 1.3, p_shiny.button_pressed)
	preview_holder.add_child(c)


func _save() -> void:
	DB.save_species_override(sid, _collect())
	dirty = false
	Game.changed.emit()
	Game.notify("已保存「%s」的卡牌数据" % DB.species(sid).name, UI.GOOD)
	var keep := sid
	_fill_list()
	var idx := ids.find(keep)
	if idx >= 0:
		list.select(idx)


func _reset() -> void:
	DB.reset_species_override(sid)
	dirty = false
	Game.changed.emit()
	Game.notify("已还原默认数据", UI.GOOD)
	_build_form()
	_preview()
	var keep := sid
	_fill_list()
	var idx := ids.find(keep)
	if idx >= 0:
		list.select(idx)


func _export() -> void:
	if DB.export_species_to_project():
		Game.notify("已写回 res://data/species.json", UI.GOOD)
	else:
		Game.notify("写回失败（仅编辑器内可用）", UI.BAD)
