class_name BattleEngine
extends RefCounted
## 纯逻辑回合制战斗。do_turn() 返回事件数组交给 UI 依次播放；
## simulate() 用 AI 托管双方瞬间结算（放置狩猎 / 离线收益用）。

enum Kind { WILD, TRAINER, BOSS, TOWER }
const PLAYER := 0
const ENEMY := 1

var kind: int = Kind.WILD
var teams: Array = [[], []]
var active: Array = [0, 0]
var stages: Array = [{}, {}]
var events: Array = []
var over := false
var result := ""
var turn := 0
var enemy_name := ""
var awaiting_switch := false
var xp_enabled := true
var xp_mult := 1.0
var caught_monster: Monster = null
var pending_evolutions: Array = []
var participants: Dictionary = {}
var run_attempts := 0


func _init(player_team: Array, enemy_team: Array, battle_kind: int = Kind.WILD, trainer_name: String = "") -> void:
	teams = [player_team, enemy_team]
	kind = battle_kind
	enemy_name = trainer_name
	active[PLAYER] = maxi(0, _first_alive(PLAYER))
	active[ENEMY] = maxi(0, _first_alive(ENEMY))
	stages = [{}, {}]
	_mark_participant()


func mon(side: int) -> Monster:
	return teams[side][active[side]]


func player() -> Monster:
	return mon(PLAYER)


func enemy() -> Monster:
	return mon(ENEMY)


func can_catch() -> bool:
	return kind == Kind.WILD or kind == Kind.BOSS


func can_run() -> bool:
	return kind == Kind.WILD or kind == Kind.BOSS


func intro() -> Array:
	events = []
	match kind:
		Kind.WILD:
			_msg("野生的 %s 出现了！" % enemy().display_name())
		Kind.BOSS:
			_msg("传说中的 %s 降临了！" % enemy().display_name())
		_:
			_msg("%s 发起了挑战！" % enemy_name)
			_msg("%s 派出了 %s！" % [enemy_name, enemy().display_name()])
	_msg("去吧，%s！" % player().display_name())
	return events


# ---------------- 回合 ----------------

func do_turn(action: Dictionary) -> Array:
	events = []
	if over or awaiting_switch:
		return events
	turn += 1
	var actors := {PLAYER: player(), ENEMY: enemy()}
	var e_move := ai_choose_move(ENEMY)
	match str(action.get("kind", "move")):
		"run":
			if not can_run():
				_msg("不能从训练家对战中逃跑！")
				turn -= 1
				return events
			run_attempts += 1
			var chance := (float(_speed(PLAYER)) * 128.0 / float(maxi(1, _speed(ENEMY))) + 30.0 * run_attempts) / 256.0
			if kind == Kind.BOSS or randf() < chance:
				_msg("成功逃走了！")
				_finish("run")
				return events
			_msg("逃跑失败了！")
			_act(ENEMY, e_move, actors[ENEMY])
		"forfeit":
			_msg("你认输了……")
			_finish("lose")
			return events
		"switch":
			_switch_in(PLAYER, int(action.get("index", 0)), false)
			_act(ENEMY, e_move, actors[ENEMY])
		"item":
			_use_item(action)
			_act(ENEMY, e_move, actors[ENEMY])
		"ball":
			if _throw_ball(action):
				return events
			_act(ENEMY, e_move, actors[ENEMY])
		_:
			var p_move: String = str(action.get("move", ""))
			if p_move == "" or not player().moves.has(p_move):
				p_move = ai_choose_move(PLAYER)
			var plan := {PLAYER: p_move, ENEMY: e_move}
			for side in _order(p_move, e_move):
				if over:
					break
				_act(side, plan[side], actors[side])
	if not over:
		_end_of_turn()
	return events


func force_switch(idx: int) -> Array:
	events = []
	if not awaiting_switch:
		return events
	awaiting_switch = false
	_switch_in(PLAYER, idx, true)
	return events


func simulate(max_turns: int = 150) -> String:
	xp_enabled = false
	while not over and turn < max_turns:
		if awaiting_switch:
			force_switch(_first_alive(PLAYER))
			continue
		do_turn({"kind": "move", "move": ""})
	if not over:
		_finish("lose")
	return result


# ---------------- 行动 ----------------

func _order(p_move: String, e_move: String) -> Array:
	var pp := int(DB.move(p_move).get("priority", 0))
	var ep := int(DB.move(e_move).get("priority", 0))
	if pp != ep:
		return [PLAYER, ENEMY] if pp > ep else [ENEMY, PLAYER]
	var ps := _speed(PLAYER)
	var es := _speed(ENEMY)
	if ps == es:
		return [PLAYER, ENEMY] if randf() < 0.5 else [ENEMY, PLAYER]
	return [PLAYER, ENEMY] if ps > es else [ENEMY, PLAYER]


func _speed(side: int) -> int:
	var m := mon(side)
	var s := m.stat("spe") * _stage_mult(int(stages[side].get("spe", 0)))
	if m.status == "paralysis":
		s *= 0.5
	return int(s)


func _act(side: int, mid: String, actor: Monster) -> void:
	var user := mon(side)
	if over or user != actor or user.is_fainted():
		return
	var target := mon(1 - side)
	if target.is_fainted():
		return
	match user.status:
		"sleep":
			user.sleep_turns -= 1
			if user.sleep_turns > 0:
				_msg("%s 正在呼呼大睡。" % user.display_name())
				return
			user.status = ""
			_ev({"type": "status", "side": side, "status": ""})
			_msg("%s 醒过来了！" % user.display_name())
		"freeze":
			if randf() < 0.25:
				user.status = ""
				_ev({"type": "status", "side": side, "status": ""})
				_msg("%s 的冰冻解除了！" % user.display_name())
			else:
				_msg("%s 被冻住了，无法行动！" % user.display_name())
				return
		"paralysis":
			if randf() < 0.25:
				_msg("%s 身体麻痹，无法行动！" % user.display_name())
				return

	var mv := DB.move(mid)
	_msg("%s 使用了 %s！" % [user.display_name(), mv.name])
	_ev({"type": "attack", "side": side, "move": mid, "mtype": mv.type, "cat": mv.cat})
	var acc := int(mv.get("acc", 100))
	if acc > 0 and randf() * 100.0 >= acc:
		_msg("但是没有命中！")
		_ev({"type": "miss", "side": 1 - side})
		return
	if mv.cat == "status":
		if not _apply_effects(side, mv, true):
			_msg("但是什么也没有发生……")
		return

	var eff := DB.type_mult(mv.type, target.types())
	if eff == 0.0:
		_msg("对 %s 好像没有效果……" % target.display_name())
		return
	var crit := randf() < (1.0 / 8.0 if int(mv.get("crit", 0)) > 0 else 1.0 / 24.0)
	var dmg := calc_damage(user, target, mv, side, eff, crit, true)
	target.hp = maxi(0, target.hp - dmg)
	_ev({"type": "damage", "side": 1 - side, "amount": dmg, "hp": target.hp, "max": target.max_hp(), "eff": eff, "crit": crit})
	if crit:
		_msg("击中了要害！")
	if eff > 1.0:
		_msg("效果拔群！")
	elif eff < 1.0:
		_msg("效果不太好……")

	for e in mv.get("effects", []):
		if e.kind == "drain" and user.hp > 0 and user.hp < user.max_hp():
			_heal(side, maxi(1, int(dmg * float(e.amount))), "%s 吸取了对手的体力！" % user.display_name())
		elif e.kind == "recoil":
			var r := maxi(1, int(dmg * float(e.amount)))
			user.hp = maxi(0, user.hp - r)
			_ev({"type": "damage", "side": side, "amount": r, "hp": user.hp, "max": user.max_hp(), "eff": 1.0, "crit": false})
			_msg("%s 受到了反作用力的伤害！" % user.display_name())

	if target.hp <= 0:
		_apply_effects(side, mv, false, true)
		_handle_faint(1 - side)
	else:
		_apply_effects(side, mv, false)
	if user.hp <= 0 and not over and mon(side) == user:
		_handle_faint(side)


func _apply_effects(side: int, mv: Dictionary, verbose: bool, self_only: bool = false) -> bool:
	var any := false
	for e in mv.get("effects", []):
		var k: String = str(e.get("kind", ""))
		if k == "drain" or k == "recoil":
			continue
		if randf() * 100.0 >= float(e.get("chance", 100)):
			continue
		match k:
			"stat":
				var tside := side if str(e.get("target", "foe")) == "self" else 1 - side
				if self_only and tside != side:
					continue
				if mon(tside).is_fainted():
					continue
				for st in e.stats:
					if _change_stage(tside, st, int(e.stats[st]), verbose):
						any = true
			"status":
				if self_only or mon(1 - side).is_fainted():
					continue
				if _inflict(1 - side, str(e.status), verbose):
					any = true
			"heal":
				var u := mon(side)
				if u.hp >= u.max_hp():
					_msg("%s 的 HP 已经是满的了！" % u.display_name())
					continue
				_heal(side, int(u.max_hp() * float(e.amount)), "%s 恢复了体力！" % u.display_name())
				any = true
	return any


func _change_stage(side: int, st: String, delta: int, verbose: bool) -> bool:
	var m := mon(side)
	var cur := int(stages[side].get(st, 0))
	var nv := clampi(cur + delta, -6, 6)
	if nv == cur:
		if verbose:
			_msg("%s 的%s已经无法再%s了！" % [m.display_name(), DB.STAT_NAMES[st], "提高" if delta > 0 else "降低"])
		return false
	stages[side][st] = nv
	var word := ""
	if delta >= 2:
		word = "大幅提高了"
	elif delta > 0:
		word = "提高了"
	elif delta <= -2:
		word = "大幅降低了"
	else:
		word = "降低了"
	_msg("%s 的%s%s！" % [m.display_name(), DB.STAT_NAMES[st], word])
	_ev({"type": "stat", "side": side, "stat": st, "delta": delta})
	return true


func _inflict(side: int, st: String, verbose: bool) -> bool:
	var t := mon(side)
	var ty := t.types()
	var immune := (st == "burn" and ty.has("fire")) or (st == "paralysis" and ty.has("electric")) \
		or (st == "poison" and (ty.has("poison") or ty.has("steel"))) or (st == "freeze" and ty.has("ice"))
	if t.status != "" or immune:
		if verbose:
			_msg("但是失败了！")
		return false
	t.status = st
	if st == "sleep":
		t.sleep_turns = randi_range(2, 4)
	_ev({"type": "status", "side": side, "status": st})
	var txt := {"burn": "被灼伤了", "poison": "中毒了", "paralysis": "麻痹了，可能会无法行动", "sleep": "睡着了", "freeze": "被冻住了"}
	_msg("%s %s！" % [t.display_name(), txt.get(st, st)])
	return true


func _heal(side: int, amount: int, text: String) -> void:
	var m := mon(side)
	m.hp = mini(m.max_hp(), m.hp + amount)
	_ev({"type": "heal", "side": side, "hp": m.hp, "max": m.max_hp()})
	_msg(text)


func _end_of_turn() -> void:
	for side in [PLAYER, ENEMY]:
		if over:
			return
		var m := mon(side)
		if m.is_fainted():
			continue
		if m.status == "burn" or m.status == "poison":
			var d := maxi(1, int(m.max_hp() * (1.0 / 16.0 if m.status == "burn" else 1.0 / 8.0)))
			m.hp = maxi(0, m.hp - d)
			_ev({"type": "damage", "side": side, "amount": d, "hp": m.hp, "max": m.max_hp(), "eff": 1.0, "crit": false})
			_msg("%s 受到了%s的伤害！" % [m.display_name(), DB.STATUS_NAMES[m.status]])
			if m.hp <= 0:
				_handle_faint(side)


func _handle_faint(side: int) -> void:
	var m := mon(side)
	_ev({"type": "faint", "side": side})
	_msg("%s 倒下了！" % m.display_name())
	if side == ENEMY:
		_award_xp(m)
		var nxt := _first_alive(ENEMY)
		if nxt < 0:
			_finish("win")
			return
		active[ENEMY] = nxt
		stages[ENEMY] = {}
		participants = {}
		_mark_participant()
		_ev({"type": "switch_in", "side": ENEMY})
		_msg("%s 派出了 %s！" % [enemy_name, enemy().display_name()])
	else:
		if _first_alive(PLAYER) < 0:
			_msg("你没有可以战斗的宝可梦了……")
			_finish("lose")
			return
		awaiting_switch = true
		_ev({"type": "need_switch"})


func _switch_in(side: int, idx: int, forced: bool) -> void:
	if idx < 0 or idx >= teams[side].size() or teams[side][idx].is_fainted():
		return
	if not forced:
		_msg("回来吧，%s！" % mon(side).display_name())
	active[side] = idx
	stages[side] = {}
	if side == PLAYER:
		_mark_participant()
	_ev({"type": "switch_in", "side": side})
	_msg("去吧，%s！" % mon(side).display_name())


func _use_item(action: Dictionary) -> void:
	var it := DB.item(str(action.get("item", "")))
	var idx := int(action.get("target", active[PLAYER]))
	var m: Monster = teams[PLAYER][idx]
	match str(it.get("kind", "")):
		"heal":
			if float(it.amount) >= 1.0:
				m.status = ""
			m.hp = mini(m.max_hp(), m.hp + int(ceil(m.max_hp() * float(it.amount))))
		"revive":
			m.hp = maxi(1, int(m.max_hp() * float(it.amount)))
			m.status = ""
	_msg("对 %s 使用了%s！" % [m.display_name(), it.name])
	if idx == active[PLAYER]:
		_ev({"type": "heal", "side": PLAYER, "hp": m.hp, "max": m.max_hp()})
		_ev({"type": "status", "side": PLAYER, "status": m.status})


func _throw_ball(action: Dictionary) -> bool:
	var ball := str(action.get("item", "poke_ball"))
	var bm := float(action.get("ball", 1.0))
	var t := enemy()
	_msg("你扔出了%s！" % DB.item(ball).name)
	_ev({"type": "ball_throw", "item": ball})
	if not can_catch():
		_msg("训练家挡开了精灵球！不能抢夺别人的宝可梦！")
		_ev({"type": "break_free", "blocked": true})
		return false
	var shakes := 0
	var caught := false
	if bm >= 255.0:
		shakes = 3
		caught = true
	else:
		var s := pow(catch_chance(t, bm), 0.25)
		for i in 4:
			if randf() < s:
				shakes += 1
			else:
				break
		caught = shakes >= 4
		shakes = mini(shakes, 3)
	_ev({"type": "shake", "count": shakes})
	if caught:
		_ev({"type": "caught"})
		_msg("太好了！成功捕获了 %s！" % t.display_name())
		caught_monster = t
		_finish("caught")
		return true
	_ev({"type": "break_free"})
	_msg(["哎呀！宝可梦挣脱了！", "可恶！差一点就抓到了！", "啊！看起来马上就能抓到了！", "可恶！只差一点点了！"][shakes])
	return false


static func catch_chance(t: Monster, bm: float) -> float:
	var rate := float(t.species().get("catch_rate", 45))
	var mhp := float(maxi(1, t.max_hp()))
	var a := (3.0 * mhp - 2.0 * t.hp) * rate * bm / (3.0 * mhp)
	if t.status == "sleep" or t.status == "freeze":
		a *= 2.0
	elif t.status != "":
		a *= 1.5
	a /= (1.0 + t.rarity * 0.25)
	if t.shiny:
		a *= 0.8
	return clampf(a / 255.0, 0.0, 1.0)


# ---------------- 伤害 / 经验 ----------------

func calc_damage(user: Monster, target: Monster, mv: Dictionary, side: int, eff: float, crit: bool, rand: bool) -> int:
	var physical: bool = mv.cat == "physical"
	var a_stat := "atk" if physical else "spa"
	var d_stat := "def" if physical else "spd"
	var a_stage := int(stages[side].get(a_stat, 0))
	var d_stage := int(stages[1 - side].get(d_stat, 0))
	if crit:
		a_stage = maxi(a_stage, 0)
		d_stage = mini(d_stage, 0)
	var a := user.stat(a_stat) * _stage_mult(a_stage)
	var d := maxf(1.0, target.stat(d_stat) * _stage_mult(d_stage))
	var base := ((2.0 * user.level / 5.0 + 2.0) * float(mv.power) * a / d) / 50.0 + 2.0
	var m := eff
	if user.types().has(mv.type):
		m *= 1.5
	if crit:
		m *= 1.5
	if physical and user.status == "burn":
		m *= 0.5
	if rand:
		m *= randf_range(0.85, 1.0)
	return maxi(1, int(base * m))


func _stage_mult(s: int) -> float:
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)


func xp_reward(defeated: Monster) -> int:
	var x := float(DB.base_exp(defeated.species_id)) * defeated.level / 7.0
	if kind != Kind.WILD:
		x *= 1.5
	x *= 1.0 + defeated.rarity * 0.1
	return maxi(1, int(x * xp_mult))


func _award_xp(defeated: Monster) -> void:
	if not xp_enabled:
		return
	var amount := xp_reward(defeated)
	var shared := false
	for m in teams[PLAYER]:
		if m.is_fainted() or m.level >= 100:
			continue
		var full: bool = participants.has(m.uid)
		var got := amount if full else maxi(1, int(amount * 0.5))
		if not full:
			shared = true
		var res: Dictionary = m.gain_xp(got)
		if full:
			_msg("%s 获得了 %d 点经验值！" % [m.display_name(), got])
		_ev({"type": "xp", "uid": m.uid, "amount": got})
		if res.levels > 0:
			_msg("%s 升到了 Lv.%d！" % [m.display_name(), m.level])
			_ev({"type": "level_up", "uid": m.uid, "level": m.level})
		for l in res.learned:
			if l.has("replaced"):
				_msg("%s 忘记了%s，学会了%s！" % [m.display_name(), DB.move(l.replaced).name, DB.move(l.learned).name])
			else:
				_msg("%s 学会了%s！" % [m.display_name(), DB.move(l.learned).name])
		if res.evolve != "" and not pending_evolutions.has(m):
			pending_evolutions.append(m)
	if shared:
		_msg("学习装置让队伍中其他宝可梦也获得了经验值。")


# ---------------- AI ----------------

func ai_choose_move(side: int) -> String:
	var user := mon(side)
	var target := mon(1 - side)
	var best := ""
	var best_score := -1.0
	for mid in user.moves:
		var mv := DB.move(mid)
		var score := 0.0
		if mv.cat == "status":
			score = _status_score(side, mv)
		else:
			var eff := DB.type_mult(mv.type, target.types())
			var acc := float(mv.acc if int(mv.acc) > 0 else 100) / 100.0
			var est := float(calc_damage(user, target, mv, side, eff, false, false)) * 0.92
			score = est * acc
			if est >= target.hp:
				score += 1000.0 * acc
		score *= randf_range(0.85, 1.15)
		if score > best_score:
			best_score = score
			best = mid
	if best == "":
		best = user.moves[0] if not user.moves.is_empty() else "tackle"
	return best


func _status_score(side: int, mv: Dictionary) -> float:
	var user := mon(side)
	var target := mon(1 - side)
	var score := 0.0
	for e in mv.get("effects", []):
		match str(e.get("kind", "")):
			"stat":
				var self_t := str(e.get("target", "foe")) == "self"
				var tside := side if self_t else 1 - side
				for st in e.stats:
					var cur := int(stages[tside].get(st, 0))
					if self_t and cur < 2 and user.hp > user.max_hp() * 0.5:
						score += target.max_hp() * 0.18
					elif not self_t and cur > -2:
						score += target.max_hp() * 0.08
			"status":
				if target.status == "":
					score += target.max_hp() * (0.4 if e.status == "sleep" else 0.28)
			"heal":
				if user.hp < user.max_hp() * 0.45:
					score += user.max_hp() * 0.5
	return score * float(mv.acc if int(mv.acc) > 0 else 100) / 100.0


# ---------------- 工具 ----------------

func _first_alive(side: int) -> int:
	for i in teams[side].size():
		if not teams[side][i].is_fainted():
			return i
	return -1


func alive_count(side: int) -> int:
	var c := 0
	for m in teams[side]:
		if not m.is_fainted():
			c += 1
	return c


func _mark_participant() -> void:
	if teams[PLAYER].size() > 0:
		participants[player().uid] = true


func _finish(r: String) -> void:
	over = true
	result = r
	_ev({"type": "end", "result": r})


func _msg(t: String) -> void:
	events.append({"type": "msg", "text": t})


func _ev(d: Dictionary) -> void:
	events.append(d)
