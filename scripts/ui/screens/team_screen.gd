extends Control
## 队伍（最多 6 只）+ 仓库（排序 / 点击查看详情）

var main
var grid: GridContainer
var sort_mode := 0

const SORTS := ["按战力", "按等级", "按品质", "按图鉴编号", "按捕获时间"]


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 14)
	add_child(margin)
	var v := UI.vbox(10)
	margin.add_child(v)

	var h := UI.hbox(10)
	h.add_child(UI.lbl("我的队伍（%d/%d）" % [Game.team.size(), Game.TEAM_MAX], 20, UI.ACCENT, true))
	h.add_child(UI.lbl("首发宝可梦在自动狩猎中获得全部经验，其余队员获得一半。点击卡牌查看详情。", 13, UI.MUTED))
	v.add_child(h)
	var tr := UI.hbox(12)
	for i in Game.team.size():
		var c := MonsterCard.of_monster(Game.team[i], 0.82)
		c.show_hp = true
		c.badge = "首发" if i == 0 else ""
		c.refresh()
		c.pressed.connect(_open.bind(Game.team[i]))
		tr.add_child(c)
	v.add_child(tr)

	var h2 := UI.hbox(10)
	h2.add_child(UI.lbl("仓库（%d）" % Game.box.size(), 20, UI.ACCENT, true))
	h2.add_child(UI.spacer())
	var opt := OptionButton.new()
	for s in SORTS:
		opt.add_item(s)
	opt.select(sort_mode)
	opt.item_selected.connect(func(i: int):
		sort_mode = i
		_fill_box())
	h2.add_child(opt)
	v.add_child(h2)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var sc := UI.scroll(grid)
	v.add_child(sc)
	resized.connect(_update_cols)
	_fill_box()
	_update_cols.call_deferred()


func _update_cols() -> void:
	if grid:
		grid.columns = maxi(1, int((size.x - 40) / (MonsterCard.W * 0.62 + 10)))


func _fill_box() -> void:
	UI.clear(grid)
	var list: Array = Game.box.duplicate()
	match sort_mode:
		0:
			list.sort_custom(func(a, b): return a.power() > b.power())
		1:
			list.sort_custom(func(a, b): return a.level > b.level)
		2:
			list.sort_custom(func(a, b): return a.rarity * 2 + int(a.shiny) * 20 > b.rarity * 2 + int(b.shiny) * 20)
		3:
			list.sort_custom(func(a, b): return int(a.species().dex) < int(b.species().dex))
		4:
			list.sort_custom(func(a, b): return a.uid > b.uid)
	if list.is_empty():
		grid.add_child(UI.lbl("仓库是空的。队伍满 6 只后，新捕获的宝可梦会放进这里。", 14, UI.MUTED))
	for m in list:
		var c := MonsterCard.of_monster(m, 0.62)
		c.pressed.connect(_open.bind(m))
		grid.add_child(c)


func _open(_card, m: Monster) -> void:
	main.open_monster(m)
