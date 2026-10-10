extends Control
## 商店：购买精灵球 / 药品 / 神奇糖果

const BagScreen := preload("res://scripts/ui/screens/bag_screen.gd")

var main
var gold_lbl: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 14)
	add_child(margin)
	var v := UI.vbox(10)
	margin.add_child(v)
	var h := UI.hbox(10)
	h.add_child(UI.lbl("友好商店", 20, UI.ACCENT, true))
	h.add_child(UI.spacer())
	gold_lbl = UI.lbl("", 18, UI.ACCENT, true)
	h.add_child(gold_lbl)
	v.add_child(h)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	v.add_child(UI.scroll(g))
	for iid in DB.items_db:
		var it := DB.item(iid)
		if not it.get("shop", true) or int(it.price) <= 0:
			continue
		g.add_child(_row(iid))
	_update()


func _update() -> void:
	gold_lbl.text = "金币 " + UI.fmt_num(Game.gold)


func _row(iid: String) -> Control:
	var it := DB.item(iid)
	var p := UI.panel(UI.PANEL, 10, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(12)
	p.add_child(h)
	h.add_child(BagScreen.icon(iid, 48))
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.lbl(it.name, 17, Color.WHITE, true))
	var d := UI.lbl(it.desc, 12, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(d)
	var own := UI.lbl("单价 %s   持有 %d" % [UI.fmt_num(int(it.price)), Game.item_count(iid)], 13, UI.ACCENT)
	info.add_child(own)
	h.add_child(info)
	var bv := UI.vbox(4)
	for n in [1, 10]:
		bv.add_child(UI.btn("买 %d" % n, func():
			if Game.buy(iid, n):
				Game.notify("购买了 %s ×%d" % [it.name, n], UI.GOOD)
				own.text = "单价 %s   持有 %d" % [UI.fmt_num(int(it.price)), Game.item_count(iid)]
				_update()
			else:
				Game.notify("金币不足！", UI.BAD), 80))
	h.add_child(bv)
	return p
