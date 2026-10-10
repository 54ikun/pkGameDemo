extends Node
## 玩家存档与全局流程：队伍 / 仓库 / 背包 / 金币 / 徽章 / 对战塔 / 传说 / 自动狩猎 / 离线收益

signal changed
signal toast(text: String, color: Color)
signal hunt_result(info: Dictionary)

var save_path := "user://save.json"
const SAVE_VERSION := 1
const TEAM_MAX := 6
const HUNT_INTERVAL := 4.0
const OFFLINE_CAP := 12 * 3600
const OFFLINE_HUNT_SECONDS := 20.0
const OFFLINE_MAX_SIMS := 200

var trainer_name := "训练家"
var gold := 0
var items: Dictionary = {}
var team: Array = []
var box: Array = []
var badges: Array = []
var legends_done: Dictionary = {}
var tower_floor := 1
var tower_best := 0
var seen: Dictionary = {}
var caught: Dictionary = {}
var next_uid := 1
var hunting_region := 0
var hunting := false
var auto_catch_min := 2
var auto_ball := "poke_ball"
var stats := {"battles": 0, "wins": 0, "caught": 0, "hunts": 0}
var in_battle := false
var started := false
var last_save_time := 0
var hunt_log: Array = []
var offline_report: Dictionary = {}

var _hunt_timer: Timer
var _autosave_timer: Timer


func _ready() -> void:
	_hunt_timer = Timer.new()
	_hunt_timer.wait_time = HUNT_INTERVAL
	_hunt_timer.timeout.connect(_on_hunt_tick)
	add_child(_hunt_timer)
	_hunt_timer.start()
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 30.0
	_autosave_timer.timeout.connect(_on_autosave)
	add_child(_autosave_timer)
	_autosave_timer.start()


func _on_autosave() -> void:
	if started and not in_battle:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started:
		save_game()


func notify(text: String, color: Color = Color("e8ecf8")) -> void:
	toast.emit(text, color)


# ---------------- 新游戏 / 存读档 ----------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func reset_state() -> void:
	trainer_name = "训练家"
	gold = 0
	items = {}
	team = []
	box = []
	badges = []
	legends_done = {}
	tower_floor = 1
	tower_best = 0
	seen = {}
	caught = {}
	next_uid = 1
	hunting_region = 0
	hunting = false
	auto_catch_min = 2
	auto_ball = "poke_ball"
	stats = {"battles": 0, "wins": 0, "caught": 0, "hunts": 0}
	hunt_log = []
	offline_report = {}


func new_game(tname: String, starter: Monster) -> void:
	reset_state()
	trainer_name = tname if tname.strip_edges() != "" else "训练家"
	gold = 3000
	items = {"poke_ball": 10, "potion": 5}
	add_monster(starter)
	stats.caught = 0
	started = true
	save_game()
	changed.emit()


func save_game() -> void:
	last_save_time = int(Time.get_unix_time_from_system())
	var data := {
		"version": SAVE_VERSION, "trainer_name": trainer_name, "gold": gold, "items": items,
		"team": team.map(func(m): return m.to_dict()), "box": box.map(func(m): return m.to_dict()),
		"badges": badges, "legends_done": legends_done, "tower_floor": tower_floor, "tower_best": tower_best,
		"seen": seen, "caught": caught, "next_uid": next_uid, "hunting_region": hunting_region,
		"hunting": hunting, "auto_catch_min": auto_catch_min, "auto_ball": auto_ball, "stats": stats,
		"last_save_time": last_save_time,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	reset_state()
	trainer_name = str(data.get("trainer_name", "训练家"))
	gold = int(data.get("gold", 0))
	items = {}
	var it: Dictionary = data.get("items", {})
	for k in it:
		items[k] = int(it[k])
	team = []
	for d in data.get("team", []):
		team.append(Monster.from_dict(d))
	box = []
	for d in data.get("box", []):
		box.append(Monster.from_dict(d))
	badges = data.get("badges", [])
	legends_done = data.get("legends_done", {})
	tower_floor = int(data.get("tower_floor", 1))
	tower_best = int(data.get("tower_best", 0))
	seen = data.get("seen", {})
	caught = data.get("caught", {})
	next_uid = int(data.get("next_uid", 1))
	hunting_region = int(data.get("hunting_region", 0))
	hunting = bool(data.get("hunting", false))
	auto_catch_min = int(data.get("auto_catch_min", 2))
	auto_ball = str(data.get("auto_ball", "poke_ball"))
	var st: Dictionary = data.get("stats", {})
	for k in stats:
		stats[k] = int(st.get(k, 0))
	last_save_time = int(data.get("last_save_time", 0))
	if team.is_empty():
		return false
	started = true
	_compute_offline()
	changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)
	started = false
	reset_state()


func _compute_offline() -> void:
	offline_report = {}
	if not hunting or last_save_time <= 0 or not region_unlocked(hunting_region):
		return
	var elapsed := mini(OFFLINE_CAP, int(Time.get_unix_time_from_system()) - last_save_time)
	var n := int(elapsed / OFFLINE_HUNT_SECONDS)
	if n < 1:
		return
	var sims := mini(n, OFFLINE_MAX_SIMS)
	var scale := float(n) / float(sims)
	var total_xp := 0
	var total_gold := 0
	var wins := 0
	var caught_names: Array = []
	for i in sims:
		var r := run_hunt(hunting_region, false)
		if r.win:
			wins += 1
			total_xp += int(r.xp)
			total_gold += int(r.gold)
		if r.caught:
			caught_names.append(r.wild.display_name())
	total_xp = int(total_xp * scale)
	total_gold = int(total_gold * scale)
	gold += total_gold
	var xp_res := give_team_xp(total_xp)
	offline_report = {
		"seconds": elapsed, "hunts": n, "wins": int(wins * scale), "xp": total_xp, "gold": total_gold,
		"caught": caught_names, "levelups": xp_res.levelups, "evolved": xp_res.evolved,
	}


# ---------------- 宝可梦管理 ----------------

func add_monster(m: Monster) -> String:
	if m.uid == 0:
		m.uid = next_uid
		next_uid += 1
	seen[m.species_id] = true
	caught[m.species_id] = true
	stats.caught += 1
	var where := "box"
	if team.size() < TEAM_MAX:
		team.append(m)
		where = "team"
	else:
		box.append(m)
	changed.emit()
	return where


func mark_seen(sid: String) -> void:
	seen[sid] = true


func all_monsters() -> Array:
	return team + box


func in_team(m: Monster) -> bool:
	return team.has(m)


func move_to_team(m: Monster) -> bool:
	if team.has(m) or team.size() >= TEAM_MAX:
		return false
	box.erase(m)
	team.append(m)
	changed.emit()
	return true


func move_to_box(m: Monster) -> bool:
	if not team.has(m) or team.size() <= 1:
		return false
	team.erase(m)
	box.push_front(m)
	changed.emit()
	return true


func set_lead(m: Monster) -> void:
	if not team.has(m):
		if not move_to_team(m):
			return
	team.erase(m)
	team.push_front(m)
	changed.emit()


func release(m: Monster) -> bool:
	if team.has(m):
		if team.size() <= 1:
			return false
		team.erase(m)
	else:
		box.erase(m)
	gold += 50 + m.level * 10
	changed.emit()
	return true


func heal_all() -> void:
	for m in team:
		m.heal_full()
	changed.emit()


func lead() -> Monster:
	for m in team:
		if not m.is_fainted():
			return m
	return null


func team_power() -> int:
	var t := 0
	for m in team:
		t += m.power()
	return t


## 队伍经验：首发获得全部，其他队员获得一半（学习装置）
func give_team_xp(amount: int) -> Dictionary:
	var out := {"levelups": [], "evolved": []}
	if amount <= 0 or team.is_empty():
		return out
	for i in team.size():
		var m: Monster = team[i]
		var got := amount if i == 0 else int(amount * 0.5)
		var res := m.gain_xp(got)
		if res.levels > 0:
			out.levelups.append("%s → Lv.%d" % [m.display_name(), m.level])
		if res.evolve != "":
			var old_name := m.display_name()
			m.evolve()
			out.evolved.append([old_name, m.display_name()])
			caught[m.species_id] = true
			seen[m.species_id] = true
	changed.emit()
	return out


# ---------------- 道具 ----------------

func item_count(iid: String) -> int:
	return int(items.get(iid, 0))


func add_item(iid: String, n: int = 1) -> void:
	items[iid] = item_count(iid) + n
	if items[iid] <= 0:
		items.erase(iid)
	changed.emit()


func consume_item(iid: String) -> bool:
	if item_count(iid) <= 0:
		return false
	add_item(iid, -1)
	return true


func buy(iid: String, n: int) -> bool:
	var cost := int(DB.item(iid).price) * n
	if cost <= 0 or gold < cost:
		return false
	gold -= cost
	add_item(iid, n)
	return true


func ball_ids() -> Array:
	var out: Array = []
	for iid in DB.items_db:
		if DB.item(iid).kind == "ball":
			out.append(iid)
	return out


func total_balls() -> int:
	var t := 0
	for b in ball_ids():
		t += item_count(b)
	return t


## 在野外 / 背包中对宝可梦使用道具
func use_item_on(iid: String, m: Monster) -> Dictionary:
	var it := DB.item(iid)
	if item_count(iid) <= 0:
		return {"ok": false, "text": "没有这个道具了"}
	match str(it.kind):
		"heal":
			if m.is_fainted():
				return {"ok": false, "text": "%s 已经濒死，请使用活力碎片" % m.display_name()}
			if m.hp >= m.max_hp() and m.status == "":
				return {"ok": false, "text": "%s 的 HP 是满的" % m.display_name()}
			m.hp = mini(m.max_hp(), m.hp + int(ceil(m.max_hp() * float(it.amount))))
			if float(it.amount) >= 1.0:
				m.status = ""
			consume_item(iid)
			return {"ok": true, "text": "%s 恢复了体力" % m.display_name()}
		"revive":
			if not m.is_fainted():
				return {"ok": false, "text": "%s 没有濒死" % m.display_name()}
			m.hp = maxi(1, int(m.max_hp() * float(it.amount)))
			consume_item(iid)
			return {"ok": true, "text": "%s 复活了" % m.display_name()}
		"candy":
			if m.level >= 100:
				return {"ok": false, "text": "%s 已经满级" % m.display_name()}
			consume_item(iid)
			var res := m.add_level()
			var txt := "%s 升到了 Lv.%d！" % [m.display_name(), m.level]
			for l in res.learned:
				txt += " 学会了%s" % DB.move(l.learned).name
			if res.evolve != "":
				var old := m.display_name()
				m.evolve()
				caught[m.species_id] = true
				seen[m.species_id] = true
				txt += "  %s 进化成了 %s！" % [old, m.display_name()]
			changed.emit()
			return {"ok": true, "text": txt}
	return {"ok": false, "text": "这个道具不能在这里使用"}


# ---------------- 地区 / 敌人生成 ----------------

func region_unlocked(i: int) -> bool:
	if i <= 0:
		return i == 0
	if i >= DB.regions.size():
		return false
	return badges.has(DB.regions[i - 1].id)


func make_wild(i: int) -> Monster:
	var r := DB.region(i)
	var total := 0.0
	for w in r.wild:
		total += float(w[1])
	var pick := randf() * total
	var sid: String = r.wild[0][0]
	for w in r.wild:
		pick -= float(w[1])
		if pick <= 0.0:
			sid = w[0]
			break
	var m := Monster.create(sid, randi_range(int(r.min), int(r.max)), -1, false, i * 0.04)
	return m


func make_trainer_mon(sid: String, lv: int, rar: int) -> Monster:
	var m := Monster.create(sid, lv, rar)
	for s in DB.STATS:
		m.ivs[s] = randi_range(18, 31)
	m.shiny = false
	m.heal_full()
	return m


func make_boss_team(i: int) -> Array:
	var r := DB.region(i)
	var rar := clampi(1 + int(i / 2.0), 1, 5)
	var out: Array = []
	for e in r.boss.team:
		out.append(make_trainer_mon(e[0], int(e[1]), rar))
	return out


func _final_form(sid: String, lv: int) -> String:
	var cur := sid
	for _i in 3:
		var evo: Dictionary = DB.species(cur).get("evolve", {})
		if evo.is_empty() or lv < int(evo.get("level", 999)):
			break
		cur = evo.to
	return cur


func tower_level(f: int) -> int:
	return clampi(3 + f * 2, 5, 100)


func make_tower_team(f: int) -> Array:
	var pool: Array = []
	for sid in DB.species_order:
		if not DB.species(sid).get("legendary", false):
			pool.append(sid)
	var lv := tower_level(f)
	var count := 2 if f < 5 else 3
	var out: Array = []
	for _i in count:
		var sid: String = _final_form(pool.pick_random(), lv)
		var rar := DB.roll_rarity(f * 0.05)
		out.append(make_trainer_mon(sid, lv, rar))
	return out


func legend_unlocked(idx: int) -> bool:
	return badges.size() >= int(DB.legends[idx].badges)


# ---------------- 对战 ----------------

func can_battle() -> bool:
	if lead() == null:
		notify("队伍里的宝可梦都失去战斗能力了，先去治疗吧！", Color("ff5d6c"))
		return false
	return true


func create_battle(ctx: Dictionary) -> BattleEngine:
	if not can_battle():
		return null
	var eng: BattleEngine
	match str(ctx.type):
		"wild":
			var w := make_wild(int(ctx.region))
			mark_seen(w.species_id)
			eng = BattleEngine.new(team, [w], BattleEngine.Kind.WILD)
		"gym":
			var r := DB.region(int(ctx.region))
			eng = BattleEngine.new(team, make_boss_team(int(ctx.region)), BattleEngine.Kind.TRAINER, r.boss.name)
		"tower":
			eng = BattleEngine.new(team, make_tower_team(tower_floor), BattleEngine.Kind.TOWER, "对战塔 第%d层守卫" % tower_floor)
		"legend":
			var lg: Dictionary = DB.legends[int(ctx.legend)]
			var m := make_trainer_mon(lg.species, int(lg.level), int(lg.rarity))
			mark_seen(m.species_id)
			eng = BattleEngine.new(team, [m], BattleEngine.Kind.BOSS)
	if eng:
		for m in eng.teams[BattleEngine.ENEMY]:
			mark_seen(m.species_id)
		in_battle = true
	return eng


## 战斗结束结算，返回 {lines: [文本], evolved: [[旧名, 新名]]}
func finish_battle(eng: BattleEngine, ctx: Dictionary) -> Dictionary:
	in_battle = false
	stats.battles += 1
	var lines: Array = []
	for m in team:
		m.status = ""
		m.sleep_turns = 0
	if eng.result == "caught" and eng.caught_monster:
		var cm := eng.caught_monster
		cm.status = ""
		var where := add_monster(cm)
		lines.append("%s 已加入%s" % [cm.display_name(), "队伍" if where == "team" else "仓库"])
		if ctx.type == "legend":
			legends_done[cm.species_id] = "caught"
	if eng.result == "win":
		stats.wins += 1
		match str(ctx.type):
			"wild":
				var e := eng.teams[BattleEngine.ENEMY][0] as Monster
				var g := int(e.level * 8 * (1.0 + e.rarity * 0.2))
				gold += g
				lines.append("获得了 %d 金币" % g)
			"gym":
				var ri := int(ctx.region)
				var r := DB.region(ri)
				if not badges.has(r.id):
					badges.append(r.id)
					gold += int(r.boss.gold)
					lines.append("击败了 %s！获得徽章与 %d 金币" % [r.boss.name, int(r.boss.gold)])
					for iid in r.boss.get("items", {}):
						add_item(iid, int(r.boss.items[iid]))
						lines.append("获得了 %s ×%d" % [DB.item(iid).name, int(r.boss.items[iid])])
					if ri + 1 < DB.regions.size():
						lines.append("新地区【%s】已解锁！" % DB.region(ri + 1).name)
				else:
					var g2 := int(r.boss.gold * 0.3)
					gold += g2
					lines.append("再次击败馆主，获得 %d 金币" % g2)
			"tower":
				var g3 := 150 * tower_floor
				gold += g3
				lines.append("突破对战塔第 %d 层！获得 %d 金币" % [tower_floor, g3])
				if tower_floor % 5 == 0:
					add_item("rare_candy", 1)
					lines.append("里程碑奖励：神奇糖果 ×1")
				if tower_floor % 10 == 0:
					add_item("ultra_ball", 3)
					lines.append("里程碑奖励：高级球 ×3")
				tower_best = maxi(tower_best, tower_floor)
				tower_floor += 1
			"legend":
				var lg: Dictionary = DB.legends[int(ctx.legend)]
				if legends_done.get(lg.species, "") != "caught":
					legends_done[lg.species] = "defeated"
				gold += int(lg.gold)
				lines.append("击退了传说宝可梦！获得 %d 金币" % int(lg.gold))
	elif eng.result == "lose":
		lines.append("你输掉了对战……快去治疗宝可梦吧")
	var evolved: Array = []
	for m in eng.pending_evolutions:
		if team.has(m) and m.evolution_target() != "":
			var old_name: String = m.display_name()
			var old_sid: String = m.species_id
			m.evolve()
			caught[m.species_id] = true
			seen[m.species_id] = true
			evolved.append([old_name, m.display_name(), old_sid, m.species_id])
	save_game()
	changed.emit()
	return {"lines": lines, "evolved": evolved}


# ---------------- 自动狩猎 ----------------

func set_hunting(on: bool, region_idx: int = -1) -> void:
	if region_idx >= 0:
		hunting_region = region_idx
	hunting = on
	changed.emit()


func _on_hunt_tick() -> void:
	if not started or not hunting or in_battle or team.is_empty():
		return
	if not region_unlocked(hunting_region):
		hunting = false
		return
	var r := run_hunt(hunting_region, true)
	hunt_log.push_front(r)
	if hunt_log.size() > 30:
		hunt_log.pop_back()
	hunt_result.emit(r)


## 放置狩猎：用队伍的满血副本与野生宝可梦瞬间模拟一场战斗
func run_hunt(region_idx: int, apply_rewards: bool) -> Dictionary:
	var wild := make_wild(region_idx)
	mark_seen(wild.species_id)
	var clones: Array = []
	for m in team:
		var c: Monster = m.clone()
		c.heal_full()
		clones.append(c)
	var eng := BattleEngine.new(clones, [wild.clone()], BattleEngine.Kind.WILD)
	var res := eng.simulate()
	var info := {"wild": wild, "win": res == "win", "xp": 0, "gold": 0, "caught": false, "levelups": [], "evolved": [], "balls": 0}
	stats.hunts += 1
	if res == "win":
		info.xp = eng.xp_reward(wild)
		info.gold = int(wild.level * 6 * (1.0 + wild.rarity * 0.2))
		if apply_rewards:
			gold += int(info.gold)
			var xr := give_team_xp(int(info.xp))
			info.levelups = xr.levelups
			info.evolved = xr.evolved
		if _should_auto_catch(wild):
			wild.hp = maxi(1, int(wild.max_hp() * 0.2))
			for _try in 3:
				var ball := _pick_auto_ball()
				if ball == "":
					break
				consume_item(ball)
				info.balls += 1
				if randf() < BattleEngine.catch_chance(wild, float(DB.item(ball).ball)):
					wild.heal_full()
					add_monster(wild)
					info.caught = true
					break
	changed.emit()
	return info


func _should_auto_catch(m: Monster) -> bool:
	if auto_catch_min < 0 or m.species().get("legendary", false):
		return false
	return m.shiny or m.rarity >= auto_catch_min or not caught.has(m.species_id)


func _pick_auto_ball() -> String:
	if auto_ball != "master_ball" and item_count(auto_ball) > 0:
		return auto_ball
	for b in ["poke_ball", "great_ball", "ultra_ball"]:
		if item_count(b) > 0:
			return b
	return ""
