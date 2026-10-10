class_name Monster
extends RefCounted
## 宝可梦个体：物种 + 等级 + 个体值(IV 0~31) + 性格 + 品质 + 闪光 + 技能

var uid: int = 0
var species_id: String = ""
var nickname: String = ""
var level: int = 1
var xp: int = 0
var ivs: Dictionary = {}
var nature: int = 0
var rarity: int = 0
var shiny: bool = false
var moves: Array = []
var hp: int = 1
var status: String = ""
var sleep_turns: int = 0
var caught_time: int = 0


static func create(sid: String, lv: int, rar: int = -1, is_shiny: bool = false, luck: float = 0.0) -> Monster:
	var m := Monster.new()
	m.species_id = sid
	m.level = clampi(lv, 1, 100)
	m.xp = DB.xp_for_level(m.level)
	for s in DB.STATS:
		m.ivs[s] = randi_range(0, 31)
	m.nature = randi() % DB.NATURES.size()
	m.rarity = rar if rar >= 0 else DB.roll_rarity(luck)
	m.shiny = is_shiny or randf() < DB.SHINY_CHANCE
	m.moves = m.default_moves()
	m.hp = m.max_hp()
	m.caught_time = int(Time.get_unix_time_from_system())
	return m


static func from_dict(d: Dictionary) -> Monster:
	var m := Monster.new()
	m.uid = int(d.get("uid", 0))
	m.species_id = str(d.get("species", "pidgey"))
	if DB.species(m.species_id).is_empty():
		m.species_id = "pidgey"
	m.nickname = str(d.get("nickname", ""))
	m.level = int(d.get("level", 1))
	m.xp = int(d.get("xp", DB.xp_for_level(m.level)))
	var iv: Dictionary = d.get("ivs", {})
	for s in DB.STATS:
		m.ivs[s] = int(iv.get(s, 15))
	m.nature = int(d.get("nature", 0))
	m.rarity = int(d.get("rarity", 0))
	m.shiny = bool(d.get("shiny", false))
	m.moves = []
	for mv in d.get("moves", []):
		m.moves.append(str(mv))
	if m.moves.is_empty():
		m.moves = m.default_moves()
	m.hp = clampi(int(d.get("hp", 1)), 0, m.max_hp())
	m.status = str(d.get("status", ""))
	m.caught_time = int(d.get("caught_time", 0))
	return m


func to_dict() -> Dictionary:
	return {
		"uid": uid, "species": species_id, "nickname": nickname, "level": level, "xp": xp,
		"ivs": ivs.duplicate(), "nature": nature, "rarity": rarity, "shiny": shiny,
		"moves": moves.duplicate(), "hp": hp, "status": status, "caught_time": caught_time,
	}


func clone() -> Monster:
	return Monster.from_dict(to_dict())


# ---------------- 基础信息 ----------------

func species() -> Dictionary:
	return DB.species(species_id)


func display_name() -> String:
	return nickname if nickname != "" else str(species().get("name", species_id))


func types() -> Array:
	return species().get("types", ["normal"])


func nature_name() -> String:
	return DB.NATURES[nature % DB.NATURES.size()][0]


func stat(s: String) -> int:
	var b := int(species().get("base", {}).get(s, 50))
	var iv := int(ivs.get(s, 0))
	var v: float
	if s == "hp":
		v = floor((2 * b + iv) * level / 100.0) + level + 10
	else:
		v = (floor((2 * b + iv) * level / 100.0) + 5) * DB.nature_mult(nature, s)
	v *= DB.rarity_mult(rarity) * (DB.SHINY_MULT if shiny else 1.0)
	return int(v)


func max_hp() -> int:
	return stat("hp")


func power() -> int:
	var t := 0
	for s in DB.STATS:
		t += stat(s)
	return t


func iv_percent() -> int:
	var t := 0
	for s in DB.STATS:
		t += int(ivs.get(s, 0))
	return int(round(t * 100.0 / 186.0))


func is_fainted() -> bool:
	return hp <= 0


func heal_full() -> void:
	hp = max_hp()
	status = ""
	sleep_turns = 0


func xp_progress() -> float:
	if level >= 100:
		return 1.0
	var a := DB.xp_for_level(level)
	var b := DB.xp_for_level(level + 1)
	return clampf(float(xp - a) / float(maxi(1, b - a)), 0.0, 1.0)


# ---------------- 技能 ----------------

func learnset() -> Array:
	return species().get("learnset", [])


func learnable_moves() -> Array:
	var out: Array = []
	for e in learnset():
		if int(e[0]) <= level and not out.has(e[1]):
			out.append(e[1])
	return out


func moves_at_level(lv: int) -> Array:
	var out: Array = []
	for e in learnset():
		if int(e[0]) == lv:
			out.append(e[1])
	return out


func default_moves() -> Array:
	var all := learnable_moves()
	if all.is_empty():
		return ["tackle"]
	return all.slice(maxi(0, all.size() - 4))


func move_value(mid: String) -> float:
	var mv := DB.move(mid)
	if mv.cat == "status":
		return 30.0
	var v := float(mv.power) * float(mv.acc if int(mv.acc) > 0 else 100) / 100.0
	if types().has(mv.type):
		v *= 1.5
	return v


## 学习新技能：不足 4 个直接学会；已满时若比最弱的技能强则自动替换
func learn_move(mid: String) -> Dictionary:
	if moves.has(mid):
		return {}
	if moves.size() < 4:
		moves.append(mid)
		return {"learned": mid}
	var worst := 0
	for i in moves.size():
		if move_value(moves[i]) < move_value(moves[worst]):
			worst = i
	if move_value(mid) > move_value(moves[worst]):
		var old: String = moves[worst]
		moves[worst] = mid
		return {"learned": mid, "replaced": old}
	return {"skipped": mid}


# ---------------- 经验 / 进化 ----------------

func gain_xp(amount: int) -> Dictionary:
	var res := {"levels": 0, "learned": [], "evolve": ""}
	if level >= 100 or amount <= 0:
		return res
	xp += amount
	while level < 100 and xp >= DB.xp_for_level(level + 1):
		_level_up(res)
	if level >= 100:
		xp = DB.xp_for_level(100)
	res.evolve = evolution_target()
	return res


func add_level() -> Dictionary:
	var res := {"levels": 0, "learned": [], "evolve": ""}
	if level >= 100:
		return res
	xp = DB.xp_for_level(level + 1)
	_level_up(res)
	res.evolve = evolution_target()
	return res


func _level_up(res: Dictionary) -> void:
	var old_max := max_hp()
	level += 1
	res.levels += 1
	if hp > 0:
		hp = mini(max_hp(), hp + max_hp() - old_max)
	for mid in moves_at_level(level):
		var r := learn_move(mid)
		if r.has("learned"):
			res.learned.append(r)


func evolution_target() -> String:
	var evo: Dictionary = species().get("evolve", {})
	if evo.is_empty() or not DB.species_db.has(evo.get("to", "")):
		return ""
	if level >= int(evo.get("level", 999)):
		return evo.to
	return ""


func evolve() -> String:
	var target := evolution_target()
	if target == "":
		return ""
	var ratio := float(hp) / float(maxi(1, max_hp()))
	species_id = target
	hp = int(ceil(max_hp() * ratio))
	for mid in moves_at_level(level):
		learn_move(mid)
	return target
