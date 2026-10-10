extends Control
## 主界面：顶栏 + 左侧导航 + 内容区；负责打开战斗 / 详情 / 弹窗 / 提示

const StarterScreen := preload("res://scripts/ui/starter_screen.gd")
const BattleScreen := preload("res://scripts/ui/battle_screen.gd")
const MonsterDetail := preload("res://scripts/ui/monster_detail.gd")
const SCREENS := {
	"map": preload("res://scripts/ui/screens/map_screen.gd"),
	"team": preload("res://scripts/ui/screens/team_screen.gd"),
	"bag": preload("res://scripts/ui/screens/bag_screen.gd"),
	"shop": preload("res://scripts/ui/screens/shop_screen.gd"),
	"dex": preload("res://scripts/ui/screens/dex_screen.gd"),
	"challenge": preload("res://scripts/ui/screens/challenge_screen.gd"),
	"editor": preload("res://scripts/ui/screens/editor_screen.gd"),
}
const NAV := [["map", "地图狩猎"], ["team", "队伍仓库"], ["challenge", "挑战"], ["bag", "背包"], ["shop", "商店"], ["dex", "图鉴"], ["editor", "卡牌编辑器"]]

var hub: Control
var content: Control
var overlay: Control
var toast_box: VBoxContainer
var nav_buttons := {}
var current := ""
var battle: Control
var lbl_gold: Label
var lbl_balls: Label
var lbl_badges: Label
var lbl_power: Label
var lbl_hunt: Label


func _ready() -> void:
	var th := UI.build_theme()
	theme = th
	get_tree().root.theme = th
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var bgt := Art.ui("background")
	if bgt:
		var tr := TextureRect.new()
		tr.texture = bgt
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate = Color(1, 1, 1, 0.35)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)

	Game.toast.connect(_on_toast)
	Game.changed.connect(_update_top)
	Game.hunt_result.connect(_on_hunt)

	var args := OS.get_cmdline_user_args()
	if args.has("--smoke"):
		var smoke: Node = load("res://tests/smoke.gd").new()
		add_child(smoke)
		return
	if Game.load_game():
		_build_hub()
	else:
		_show_starter()


func _show_starter() -> void:
	if hub:
		hub.queue_free()
		hub = null
	var s: Control = StarterScreen.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.done.connect(_on_starter_done.bind(s))
	add_child(s)


func _on_starter_done(s: Control) -> void:
	s.queue_free()
	_build_hub()


func _build_hub() -> void:
	hub = Control.new()
	hub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hub)
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hub.add_child(root)

	# 顶栏
	var top := UI.panel(UI.PANEL, 0, 10, UI.BORDER)
	top.custom_minimum_size.y = 58
	root.add_child(top)
	var th := UI.hbox(18)
	top.add_child(th)
	var logo := UI.lbl("宝可梦·狩猎对决", 22, UI.ACCENT, true)
	th.add_child(logo)
	th.add_child(UI.lbl("训练家 " + Game.trainer_name, 15, UI.MUTED))
	lbl_hunt = UI.lbl("", 14, UI.GOOD)
	th.add_child(lbl_hunt)
	th.add_child(UI.spacer())
	lbl_power = UI.lbl("", 15, UI.TEXT)
	th.add_child(lbl_power)
	lbl_badges = UI.lbl("", 15, UI.TEXT)
	th.add_child(lbl_badges)
	lbl_balls = UI.lbl("", 15, UI.TEXT)
	th.add_child(lbl_balls)
	lbl_gold = UI.lbl("", 16, UI.ACCENT, true)
	th.add_child(lbl_gold)
	var heal_cb := func():
		Game.heal_all()
		Game.notify("队伍已全部恢复健康！", UI.GOOD)
		_refresh()
	th.add_child(UI.accent_btn("宝可梦中心", heal_cb, 0, UI.GOOD))
	var save_cb := func():
		Game.save_game()
		Game.notify("游戏已保存")
	th.add_child(UI.btn("保存", save_cb))
	th.add_child(UI.btn("设置", _open_settings))

	var body := UI.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var nav := UI.panel(UI.PANEL.darkened(0.15), 0, 10, Color.TRANSPARENT)
	nav.custom_minimum_size.x = 150
	body.add_child(nav)
	var nv := UI.vbox(8)
	nav.add_child(nv)
	for e in NAV:
		var b := UI.btn(e[1], show_screen.bind(e[0]))
		b.custom_minimum_size.y = 44
		b.toggle_mode = true
		nv.add_child(b)
		nav_buttons[e[0]] = b
	nv.add_child(UI.spacer(false))
	nv.add_child(UI.lbl("v0.1 Demo", 12, UI.MUTED))

	content = Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub.add_child(overlay)

	toast_box = UI.vbox(6)
	toast_box.anchor_left = 1.0
	toast_box.anchor_top = 1.0
	toast_box.anchor_right = 1.0
	toast_box.anchor_bottom = 1.0
	toast_box.offset_left = -390
	toast_box.offset_right = -16
	toast_box.offset_top = -420
	toast_box.offset_bottom = -16
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub.add_child(toast_box)

	show_screen("map")
	_update_top()
	if not Game.offline_report.is_empty():
		_show_offline_report()


func show_screen(id: String) -> void:
	current = id
	for k in nav_buttons:
		nav_buttons[k].set_pressed_no_signal(k == id)
	UI.clear(content)
	var scr: Control = SCREENS[id].new()
	scr.set("main", self)
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scr)


func _refresh() -> void:
	if current != "":
		show_screen(current)


func _update_top() -> void:
	if lbl_gold == null:
		return
	lbl_gold.text = "金币 " + UI.fmt_num(Game.gold)
	lbl_balls.text = "精灵球 %d" % Game.total_balls()
	lbl_badges.text = "徽章 %d/%d" % [Game.badges.size(), DB.regions.size()]
	lbl_power.text = "队伍战力 " + UI.fmt_num(Game.team_power())
	if Game.hunting and Game.region_unlocked(Game.hunting_region):
		lbl_hunt.text = "● 自动狩猎中：" + DB.region(Game.hunting_region).name
	else:
		lbl_hunt.text = ""


# ---------------- 战斗 ----------------

func open_battle(ctx: Dictionary) -> void:
	if battle:
		return
	var eng := Game.create_battle(ctx)
	if eng == null:
		return
	battle = BattleScreen.new()
	battle.set("engine", eng)
	battle.set("ctx", ctx)
	battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle.connect("finished", _on_battle_finished)
	hub.add_child(battle)
	hub.move_child(overlay, -1)
	hub.move_child(toast_box, -1)


func _on_battle_finished(report: Dictionary) -> void:
	if battle:
		battle.queue_free()
		battle = null
	_refresh()
	_update_top()
	var box := UI.vbox(6)
	for l in report.get("lines", []):
		box.add_child(UI.lbl(l, 16))
	for ev in report.get("evolved", []):
		var row := UI.hbox(12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(MonsterCard.of_species(ev[2], 0, 0, 0.55))
		row.add_child(UI.lbl("→", 30, UI.ACCENT, true))
		row.add_child(MonsterCard.of_species(ev[3], 0, 0, 0.55))
		box.add_child(UI.lbl("恭喜！%s 进化成了 %s！" % [ev[0], ev[1]], 18, UI.ACCENT, true))
		box.add_child(row)
	if box.get_child_count() > 0:
		popup("战斗结算", box)


# ---------------- 弹窗 / 详情 / 提示 ----------------

func open_monster(m: Monster) -> void:
	var d: Control = MonsterDetail.new()
	d.set("monster", m)
	d.set("main", self)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.connect("closed", _refresh)
	overlay.add_child(d)


## 通用模态弹窗。buttons: [[文字, Callable 或 null], ...]
func popup(title: String, body: Control, buttons: Array = [["确定", null]], min_w: int = 460) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p := UI.panel(UI.PANEL, 14, 20, UI.ACCENT.darkened(0.3))
	p.custom_minimum_size.x = min_w
	center.add_child(p)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl(title, 22, UI.ACCENT, true))
	v.add_child(body)
	var bh := UI.hbox(10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bh)
	for i in buttons.size():
		var b: Array = buttons[i]
		var btn := UI.accent_btn(b[0], Callable(), 100) if i == 0 else UI.btn(b[0], Callable(), 100)
		btn.pressed.connect(_on_popup_button.bind(layer, b[1]))
		bh.add_child(btn)
	var host: Node = overlay if overlay else self
	host.add_child(layer)
	return layer


func _on_popup_button(layer: Control, cb: Variant) -> void:
	layer.queue_free()
	if cb is Callable and cb.is_valid():
		cb.call()


func message(title: String, text: String) -> void:
	var l := UI.lbl(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	popup(title, l)


func confirm(title: String, text: String, on_yes: Callable) -> void:
	var l := UI.lbl(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	popup(title, l, [["确定", on_yes], ["取消", null]])


func _on_toast(text: String, color: Color) -> void:
	if toast_box == null:
		return
	var p := UI.panel(Color(0.08, 0.1, 0.2, 0.92), 8, 10, color.darkened(0.2))
	var l := UI.lbl(text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 330
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 5:
		toast_box.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _on_hunt(info: Dictionary) -> void:
	var w: Monster = info.wild
	if info.caught:
		Game.notify("自动狩猎捕获了 %s【%s】%s！" % [w.display_name(), DB.rarity(w.rarity).name, " ✦闪光" if w.shiny else ""], DB.rarity(w.rarity).color.lightened(0.2))
	for e in info.evolved:
		Game.notify("%s 进化成了 %s！" % [e[0], e[1]], UI.ACCENT)
	for l in info.levelups:
		if info.levelups.size() <= 2:
			Game.notify("升级：" + l, UI.GOOD)
	if info.caught or not info.evolved.is_empty():
		if current == "team" and battle == null and overlay.get_child_count() == 0:
			_refresh()
	_update_top()


func _show_offline_report() -> void:
	var r := Game.offline_report
	var v := UI.vbox(6)
	v.add_child(UI.lbl("你离开了 %s，队伍在【%s】持续狩猎：" % [UI.fmt_time(int(r.seconds)), DB.region(Game.hunting_region).name], 16))
	v.add_child(UI.lbl("狩猎 %d 次，胜利约 %d 次" % [int(r.hunts), int(r.wins)], 16))
	v.add_child(UI.lbl("获得经验 %s，金币 %s" % [UI.fmt_num(int(r.xp)), UI.fmt_num(int(r.gold))], 16, UI.ACCENT))
	if not r.caught.is_empty():
		v.add_child(UI.lbl("捕获：" + "、".join(PackedStringArray(r.caught)), 15, UI.GOOD))
	for l in r.levelups:
		v.add_child(UI.lbl("升级：" + l, 14, UI.GOOD))
	for e in r.evolved:
		v.add_child(UI.lbl("%s 进化成了 %s！" % [e[0], e[1]], 15, UI.ACCENT))
	popup("离线收益", v)
	Game.offline_report = {}


func _open_settings() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.lbl("存档位置：" + ProjectSettings.globalize_path(Game.save_path), 13, UI.MUTED))
	v.add_child(UI.lbl("物种修改：" + ProjectSettings.globalize_path(DB.OVERRIDE_PATH), 13, UI.MUTED))
	var reset_cb := func():
		confirm("确认删除存档", "将删除当前所有进度并重新选择初始宝可梦，确定吗？", _do_reset)
	v.add_child(UI.btn("重新开始（删除存档）", reset_cb))
	var cheat_cb := func():
		Game.gold += 10000
		Game.add_item("master_ball", 5)
		Game.notify("作弊成功！", UI.ACCENT)
	v.add_child(UI.btn("测试：获得 10000 金币与 5 个大师球", cheat_cb))
	popup("设置", v)


func _do_reset() -> void:
	Game.delete_save()
	if battle:
		battle.queue_free()
		battle = null
	if hub:
		hub.queue_free()
		hub = null
	toast_box = null
	overlay = null
	lbl_gold = null
	_show_starter()
