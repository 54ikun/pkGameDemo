extends Control
## 开局：输入训练家名字，选择初始宝可梦（品质随机，至少稀有，可重抽 3 次）

signal done

const STARTERS := ["bulbasaur", "charmander", "squirtle", "pikachu"]

var mons: Array = []
var cards: Array = []
var chosen := -1
var rerolls := 3
var name_edit: LineEdit
var info: Label
var card_row: HBoxContainer
var reroll_btn: Button
var go_btn: Button


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var title := UI.lbl("宝可梦 · 狩猎对决", 40, UI.ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UI.lbl("每一只宝可梦都拥有独一无二的个体值、性格与品质。选择你的第一位伙伴吧！", 17, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var nh := UI.hbox(10)
	nh.alignment = BoxContainer.ALIGNMENT_CENTER
	nh.add_child(UI.lbl("训练家名字：", 17))
	name_edit = LineEdit.new()
	name_edit.text = "小智"
	name_edit.custom_minimum_size = Vector2(220, 36)
	name_edit.max_length = 12
	nh.add_child(name_edit)
	v.add_child(nh)

	card_row = UI.hbox(26)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(card_row)

	info = UI.lbl("点击卡牌选择你的伙伴", 16, UI.TEXT)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.custom_minimum_size.y = 50
	v.add_child(info)

	var bh := UI.hbox(16)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	reroll_btn = UI.btn("", _reroll, 200)
	bh.add_child(reroll_btn)
	go_btn = UI.accent_btn("就决定是你了！", _confirm, 220)
	go_btn.disabled = true
	bh.add_child(go_btn)
	v.add_child(bh)
	_roll()


func _roll() -> void:
	mons.clear()
	for sid in STARTERS:
		var m := Monster.create(sid, 5, maxi(2, DB.roll_rarity(0.4)))
		mons.append(m)
	UI.clear(card_row)
	cards.clear()
	for i in mons.size():
		var c := MonsterCard.of_monster(mons[i], 1.05)
		c.pressed.connect(_select.bind(i))
		card_row.add_child(c)
		cards.append(c)
	reroll_btn.text = "重新抽取品质（剩余 %d 次）" % rerolls
	reroll_btn.disabled = rerolls <= 0
	if chosen >= 0:
		_select(null, chosen)


func _reroll() -> void:
	if rerolls <= 0:
		return
	rerolls -= 1
	_roll()


func _select(_card, i: int) -> void:
	chosen = i
	for j in cards.size():
		cards[j].selected = j == i
		cards[j].queue_redraw()
	var m: Monster = mons[i]
	var nat: Array = DB.NATURES[m.nature]
	var nat_txt: String = nat[0]
	if nat[1] != "":
		nat_txt += "（%s↑ %s↓）" % [DB.STAT_NAMES[nat[1]], DB.STAT_NAMES[nat[2]]]
	info.text = "%s  ·  品质【%s】%s  ·  性格 %s  ·  个体值 %d%%  ·  战力 %d" % [
		m.display_name(), DB.rarity(m.rarity).name, "✦闪光" if m.shiny else "", nat_txt, m.iv_percent(), m.power()]
	go_btn.disabled = false


func _confirm() -> void:
	if chosen < 0:
		return
	Game.new_game(name_edit.text, mons[chosen])
	Game.set_hunting(false, 0)
	done.emit()
