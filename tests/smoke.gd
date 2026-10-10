extends Node
## 冒烟测试（使用独立存档，不影响正式存档）：
##   Godot_console.exe --path . -- --smoke            逻辑 + 界面实例化
##   Godot_console.exe --path . -- --smoke --shots    额外把每个界面截图到 screenshots/

var main
var fails := 0
var shots := false


func _ready() -> void:
	main = get_parent()
	shots = OS.get_cmdline_user_args().has("--shots")
	Game.save_path = "user://smoke_save.json"
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)


func _run() -> void:
	_test_data()
	_test_monster()
	_test_battle()
	_test_flow()
	await _test_ui()
	print("\n==== 冒烟测试结束：%s（失败 %d 项）====" % ["通过" if fails == 0 else "未通过", fails])
	if FileAccess.file_exists(Game.save_path):
		DirAccess.remove_absolute(Game.save_path)
	get_tree().quit(1 if fails > 0 else 0)


func _test_data() -> void:
	print("== 数据校验 ==")
	check(DB.species_order.size() >= 60, "物种数量 %d" % DB.species_order.size())
	check(DB.moves_db.size() >= 80, "技能数量 %d" % DB.moves_db.size())
	var bad: Array = []
	for sid in DB.species_order:
		var sp := DB.species(sid)
		for t in sp.types:
			if not DB.TYPES.has(t):
				bad.append("%s 属性 %s" % [sid, t])
		for e in sp.learnset:
			if not DB.moves_db.has(e[1]):
				bad.append("%s 技能 %s" % [sid, e[1]])
		var evo: Dictionary = sp.get("evolve", {})
		if not evo.is_empty() and not DB.species_db.has(evo.to):
			bad.append("%s 进化 %s" % [sid, evo.to])
		for s in DB.STATS:
			if not sp.base.has(s):
				bad.append("%s 缺少种族值 %s" % [sid, s])
	for mid in DB.moves_db:
		if not DB.TYPES.has(DB.move(mid).type):
			bad.append("技能 %s 属性" % mid)
	for r in DB.regions:
		for w in r.wild:
			if not DB.species_db.has(w[0]):
				bad.append("%s 野生 %s" % [r.id, w[0]])
		for e in r.boss.team:
			if not DB.species_db.has(e[0]):
				bad.append("%s 馆主 %s" % [r.id, e[0]])
		for iid in r.boss.get("items", {}):
			if not DB.items_db.has(iid):
				bad.append("%s 奖励 %s" % [r.id, iid])
	for lg in DB.legends:
		if not DB.species_db.has(lg.species):
			bad.append("传说 %s" % lg.species)
	check(bad.is_empty(), "数据引用完整 %s" % str(bad))
	check(DB.type_mult("water", ["fire", "rock"]) == 4.0, "属性克制 水→火岩 = 4x")
	check(DB.type_mult("electric", ["ground"]) == 0.0, "属性克制 电→地面 = 0x")


func _test_monster() -> void:
	print("== 个体 / 成长 ==")
	var m := Monster.create("charmander", 15, 2)
	check(m.moves.size() >= 1 and m.moves.size() <= 4, "初始技能 %s" % str(m.moves))
	check(m.hp == m.max_hp() and m.max_hp() > 20, "HP %d" % m.max_hp())
	var res := m.gain_xp(DB.xp_for_level(16) - m.xp)
	check(m.level == 16 and res.evolve == "charmeleon", "升到 16 级并可进化 -> %s" % res.evolve)
	m.evolve()
	check(m.species_id == "charmeleon", "进化为火恐龙")
	var c := Monster.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(c.species_id == m.species_id and c.level == m.level and c.stat("atk") == m.stat("atk"), "存档序列化往返一致")
	var hi := Monster.create("pidgey", 50, 5)
	var lo := Monster.create("pidgey", 50, 0)
	hi.ivs = lo.ivs.duplicate()
	hi.nature = lo.nature
	check(hi.power() > lo.power(), "神话品质战力 %d > 普通 %d" % [hi.power(), lo.power()])


func _test_battle() -> void:
	print("== 战斗引擎 ==")
	var ok := 0
	var wins := 0
	for i in 200:
		var a := Monster.create(DB.species_order.pick_random(), 30)
		var b := Monster.create(DB.species_order.pick_random(), 30)
		var e := BattleEngine.new([a], [b], BattleEngine.Kind.WILD)
		var r := e.simulate()
		if e.over and r in ["win", "lose"]:
			ok += 1
		if r == "win":
			wins += 1
	check(ok == 200, "200 场随机模拟全部正常结束（胜 %d）" % wins)
	var weak := Monster.create("caterpie", 5, 0)
	weak.shiny = false
	check(BattleEngine.catch_chance(weak, 1.0) > 0.3, "绿毛虫满血捕获率 %.2f" % BattleEngine.catch_chance(weak, 1.0))
	var mt := Monster.create("mewtwo", 70, 5)
	check(BattleEngine.catch_chance(mt, 1.0) < 0.02, "超梦满血捕获率 %.4f" % BattleEngine.catch_chance(mt, 1.0))
	var p := Monster.create("pikachu", 20, 0)
	var w := Monster.create("pidgey", 5, 0)
	var eng := BattleEngine.new([p], [w], BattleEngine.Kind.WILD)
	eng.intro()
	var evs := eng.do_turn({"kind": "ball", "item": "master_ball", "ball": 255.0})
	check(eng.result == "caught" and eng.caught_monster == w, "大师球必定捕获（事件 %d 个）" % evs.size())
	var t1 := [Monster.create("geodude", 12), Monster.create("onix", 12)]
	var t2 := [Monster.create("pidgey", 10), Monster.create("rattata", 10)]
	var eng2 := BattleEngine.new(t1, t2, BattleEngine.Kind.TRAINER, "测试训练家")
	var turns := 0
	while not eng2.over and turns < 100:
		if eng2.awaiting_switch:
			eng2.force_switch(eng2._first_alive(0))
		else:
			eng2.do_turn({"kind": "move", "move": eng2.player().moves[0]})
		turns += 1
	check(eng2.over, "训练家多宝可梦战斗正常结束：%s（%d 回合）" % [eng2.result, turns])
	var r3 := BattleEngine.new([Monster.create("pidgey", 5)], [Monster.create("rattata", 5)], BattleEngine.Kind.TRAINER, "x")
	r3.do_turn({"kind": "run"})
	check(not r3.over, "训练家对战不能逃跑")


func _test_flow() -> void:
	print("== 游戏流程 ==")
	Game.new_game("测试员", Monster.create("pikachu", 8, 2))
	check(Game.team.size() == 1 and Game.gold == 3000, "新游戏初始化")
	var xp0: int = Game.team[0].xp
	var wins := 0
	for i in 20:
		var r := Game.run_hunt(0, true)
		if r.win:
			wins += 1
	check(Game.team[0].xp > xp0, "自动狩猎 20 次（胜 %d，经验 %d -> %d）" % [wins, xp0, Game.team[0].xp])
	check(Game.buy("poke_ball", 5), "商店购买")
	var strong := Monster.create("dragonite", 60, 3)
	Game.add_monster(strong)
	Game.set_lead(strong)
	var ctx := {"type": "gym", "region": 0}
	var eng := Game.create_battle(ctx)
	check(eng != null, "创建道馆战斗")
	eng.xp_enabled = true
	while not eng.over:
		if eng.awaiting_switch:
			eng.force_switch(eng._first_alive(0))
		else:
			eng.do_turn({"kind": "move", "move": ""})
	var rep := Game.finish_battle(eng, ctx)
	check(eng.result == "win" and Game.badges.has("viridian_forest"), "击败馆主获得徽章：%s" % str(rep.lines))
	check(Game.region_unlocked(1), "解锁第二个地区")
	var tctx := {"type": "tower"}
	var teng := Game.create_battle(tctx)
	teng.simulate()
	Game.finish_battle(teng, tctx)
	check(Game.tower_floor == (2 if teng.result == "win" else 1), "对战塔结算：%s 当前层 %d" % [teng.result, Game.tower_floor])
	var cand := Monster.create("magikarp", 19, 0)
	Game.add_monster(cand)
	Game.add_item("rare_candy", 1)
	var ur := Game.use_item_on("rare_candy", cand)
	check(cand.species_id == "gyarados", "神奇糖果升级并进化：%s" % ur.text)
	Game.save_game()
	var n := Game.all_monsters().size()
	check(Game.load_game() and Game.all_monsters().size() == n, "存档读档（%d 只宝可梦）" % n)
	Game.heal_all()


func _shot(nm: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s.png" % nm)
	print("  截图 screenshots/%s.png" % nm)


func _test_ui() -> void:
	print("== 界面 ==")
	var st: Control = load("res://scripts/ui/starter_screen.gd").new()
	st.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_child(st)
	await _shot("00_starter")
	st.queue_free()
	main._build_hub()
	for id in ["map", "team", "challenge", "bag", "shop", "dex", "editor"]:
		main.show_screen(id)
		await _shot("screen_" + id)
		check(main.content.get_child_count() > 0, "界面 %s" % id)
	main.show_screen("team")
	main.open_monster(Game.team[0])
	await _shot("detail")
	for c in main.overlay.get_children():
		c.queue_free()
	main.show_screen("map")
	main.open_battle({"type": "wild", "region": 1})
	check(main.battle != null, "打开战斗界面")
	await get_tree().create_timer(3.5).timeout
	await _shot("battle_start")
	if main.battle and not main.battle.busy:
		main.battle._show_moves()
		await _shot("battle_moves")
		main.battle._do_action({"kind": "move", "move": ""})
		await get_tree().create_timer(1.6).timeout
		await _shot("battle_attack")
	var waited := 0.0
	while main.battle and main.battle.busy and waited < 15.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if main.battle and not main.battle.engine.over:
		Game.add_item("great_ball", 1)
		main.battle._throw("great_ball")
		await get_tree().create_timer(1.3).timeout
		await _shot("battle_ball")
	var w2 := 0.0
	while main.battle and w2 < 60.0:
		if not main.battle.busy and not main.battle.engine.over:
			main.battle.auto = true
			main.battle._after_play()
		await get_tree().create_timer(0.5).timeout
		w2 += 0.5
	check(main.battle == null, "战斗流程完整结束并返回主界面")
	await _shot("after_battle")
