extends Node
## 静态游戏数据：物种 / 技能 / 道具 / 地区 / 属性克制 / 品质 / 性格。
## 物种、技能、道具、地区都来自 res://data/*.json，可直接改 JSON 调数值；
## 卡牌编辑器保存的物种修改会写入 user://mods/species_overrides.json 并覆盖默认值。

const OVERRIDE_PATH := "user://mods/species_overrides.json"
const STATS: Array[String] = ["hp", "atk", "def", "spa", "spd", "spe"]
const STAT_NAMES := {"hp": "HP", "atk": "攻击", "def": "防御", "spa": "特攻", "spd": "特防", "spe": "速度"}
const STAT_SHORT := {"hp": "HP", "atk": "攻", "def": "防", "spa": "特攻", "spd": "特防", "spe": "速"}
const STATUS_NAMES := {"burn": "灼伤", "poison": "中毒", "paralysis": "麻痹", "sleep": "睡眠", "freeze": "冰冻"}
const SHINY_CHANCE := 1.0 / 256.0
const SHINY_MULT := 1.10

var TYPES := {
	"normal": {"name": "一般", "color": Color("a8a77a")},
	"fire": {"name": "火", "color": Color("ee8130")},
	"water": {"name": "水", "color": Color("6390f0")},
	"electric": {"name": "电", "color": Color("f7d02c")},
	"grass": {"name": "草", "color": Color("7ac74c")},
	"ice": {"name": "冰", "color": Color("96d9d6")},
	"fighting": {"name": "格斗", "color": Color("c22e28")},
	"poison": {"name": "毒", "color": Color("a33ea1")},
	"ground": {"name": "地面", "color": Color("e2bf65")},
	"flying": {"name": "飞行", "color": Color("a98ff3")},
	"psychic": {"name": "超能力", "color": Color("f95587")},
	"bug": {"name": "虫", "color": Color("a6b91a")},
	"rock": {"name": "岩石", "color": Color("b6a136")},
	"ghost": {"name": "幽灵", "color": Color("735797")},
	"dragon": {"name": "龙", "color": Color("6f35fc")},
	"dark": {"name": "恶", "color": Color("705746")},
	"steel": {"name": "钢", "color": Color("b7b7ce")},
	"fairy": {"name": "妖精", "color": Color("d685ad")},
}

## 攻击属性 -> {防御属性: 倍率}，未列出的为 1 倍
var CHART := {
	"normal": {"rock": 0.5, "steel": 0.5, "ghost": 0.0},
	"fire": {"grass": 2.0, "ice": 2.0, "bug": 2.0, "steel": 2.0, "fire": 0.5, "water": 0.5, "rock": 0.5, "dragon": 0.5},
	"water": {"fire": 2.0, "ground": 2.0, "rock": 2.0, "water": 0.5, "grass": 0.5, "dragon": 0.5},
	"electric": {"water": 2.0, "flying": 2.0, "electric": 0.5, "grass": 0.5, "dragon": 0.5, "ground": 0.0},
	"grass": {"water": 2.0, "ground": 2.0, "rock": 2.0, "fire": 0.5, "grass": 0.5, "poison": 0.5, "flying": 0.5, "bug": 0.5, "dragon": 0.5, "steel": 0.5},
	"ice": {"grass": 2.0, "ground": 2.0, "flying": 2.0, "dragon": 2.0, "fire": 0.5, "water": 0.5, "ice": 0.5, "steel": 0.5},
	"fighting": {"normal": 2.0, "ice": 2.0, "rock": 2.0, "dark": 2.0, "steel": 2.0, "poison": 0.5, "flying": 0.5, "psychic": 0.5, "bug": 0.5, "fairy": 0.5, "ghost": 0.0},
	"poison": {"grass": 2.0, "fairy": 2.0, "poison": 0.5, "ground": 0.5, "rock": 0.5, "ghost": 0.5, "steel": 0.0},
	"ground": {"fire": 2.0, "electric": 2.0, "poison": 2.0, "rock": 2.0, "steel": 2.0, "grass": 0.5, "bug": 0.5, "flying": 0.0},
	"flying": {"grass": 2.0, "fighting": 2.0, "bug": 2.0, "electric": 0.5, "rock": 0.5, "steel": 0.5},
	"psychic": {"fighting": 2.0, "poison": 2.0, "psychic": 0.5, "steel": 0.5, "dark": 0.0},
	"bug": {"grass": 2.0, "psychic": 2.0, "dark": 2.0, "fire": 0.5, "fighting": 0.5, "poison": 0.5, "flying": 0.5, "ghost": 0.5, "steel": 0.5, "fairy": 0.5},
	"rock": {"fire": 2.0, "ice": 2.0, "flying": 2.0, "bug": 2.0, "fighting": 0.5, "ground": 0.5, "steel": 0.5},
	"ghost": {"psychic": 2.0, "ghost": 2.0, "dark": 0.5, "normal": 0.0},
	"dragon": {"dragon": 2.0, "steel": 0.5, "fairy": 0.0},
	"dark": {"psychic": 2.0, "ghost": 2.0, "fighting": 0.5, "dark": 0.5, "fairy": 0.5},
	"steel": {"ice": 2.0, "rock": 2.0, "fairy": 2.0, "fire": 0.5, "water": 0.5, "electric": 0.5, "steel": 0.5},
	"fairy": {"fighting": 2.0, "dragon": 2.0, "dark": 2.0, "fire": 0.5, "poison": 0.5, "steel": 0.5},
}

## 品质（品质框颜色 / 能力加成 / 出现权重 / 捕获难度）
var RARITIES := [
	{"id": "common", "name": "普通", "color": Color("9aa3ad"), "mult": 1.00, "weight": 500.0},
	{"id": "uncommon", "name": "优良", "color": Color("4cc35a"), "mult": 1.05, "weight": 280.0},
	{"id": "rare", "name": "稀有", "color": Color("3d8bff"), "mult": 1.10, "weight": 130.0},
	{"id": "epic", "name": "史诗", "color": Color("b05cff"), "mult": 1.16, "weight": 60.0},
	{"id": "legendary", "name": "传说", "color": Color("ff9f1c"), "mult": 1.23, "weight": 25.0},
	{"id": "mythic", "name": "神话", "color": Color("ff3b5c"), "mult": 1.30, "weight": 5.0},
]

## [名称, 提升属性, 降低属性]
const NATURES := [
	["勤奋", "", ""], ["怕寂寞", "atk", "def"], ["勇敢", "atk", "spe"], ["固执", "atk", "spa"], ["顽皮", "atk", "spd"],
	["大胆", "def", "atk"], ["坦率", "", ""], ["悠闲", "def", "spe"], ["淘气", "def", "spa"], ["乐天", "def", "spd"],
	["胆小", "spe", "atk"], ["急躁", "spe", "def"], ["认真", "", ""], ["爽朗", "spe", "spa"], ["天真", "spe", "spd"],
	["内敛", "spa", "atk"], ["慢吞吞", "spa", "def"], ["冷静", "spa", "spe"], ["害羞", "", ""], ["马虎", "spa", "spd"],
	["温和", "spd", "atk"], ["温顺", "spd", "def"], ["自大", "spd", "spe"], ["慎重", "spd", "spa"], ["浮躁", "", ""],
]

var species_db: Dictionary = {}
var species_default: Dictionary = {}
var moves_db: Dictionary = {}
var items_db: Dictionary = {}
var regions: Array = []
var legends: Array = []
var species_order: Array = []


func _ready() -> void:
	reload()


func reload() -> void:
	moves_db = _load_json("res://data/moves.json", {})
	items_db = _load_json("res://data/items.json", {})
	var world: Dictionary = _load_json("res://data/world.json", {})
	regions = world.get("regions", [])
	legends = world.get("legends", [])
	species_default = _load_json("res://data/species.json", {})
	_rebuild_species()


func _rebuild_species() -> void:
	species_db = species_default.duplicate(true)
	var overrides: Dictionary = _load_json(OVERRIDE_PATH, {})
	for sid in overrides:
		if species_db.has(sid):
			for k in overrides[sid]:
				species_db[sid][k] = overrides[sid][k]
	for sid in species_db:
		var sp: Dictionary = species_db[sid]
		sp["id"] = sid
		if sp.has("learnset_ref") and species_db.has(sp.learnset_ref):
			var ls: Array = species_db[sp.learnset_ref].get("learnset", []).duplicate(true)
			ls.append_array(sp.get("learnset_extra", []))
			ls.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
			sp["learnset"] = ls
		if not sp.has("learnset"):
			sp["learnset"] = [[1, "tackle"]]
	species_order = species_db.keys()
	species_order.sort_custom(func(a, b): return int(species_db[a].dex) < int(species_db[b].dex))


func _load_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var txt := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(txt)
	if data == null:
		push_error("JSON 解析失败: " + path)
		return fallback
	return data


# ---------------- 查询 ----------------

func species(sid: String) -> Dictionary:
	return species_db.get(sid, {})


func move(mid: String) -> Dictionary:
	return moves_db.get(mid, {"name": mid, "type": "normal", "cat": "physical", "power": 40, "acc": 100})


func item(iid: String) -> Dictionary:
	return items_db.get(iid, {"name": iid, "kind": "", "price": 0, "desc": ""})


func region(idx: int) -> Dictionary:
	if idx < 0 or idx >= regions.size():
		return {}
	return regions[idx]


func region_index(rid: String) -> int:
	for i in regions.size():
		if regions[i].id == rid:
			return i
	return -1


func type_name(t: String) -> String:
	return TYPES.get(t, {"name": t}).name


func type_color(t: String) -> Color:
	return TYPES.get(t, {"color": Color.GRAY}).color


func rarity(i: int) -> Dictionary:
	return RARITIES[clampi(i, 0, RARITIES.size() - 1)]


func rarity_mult(i: int) -> float:
	return float(rarity(i).mult)


func roll_rarity(luck: float = 0.0) -> int:
	## luck > 0 时提高高品质权重（对战塔、Boss 等）
	var total := 0.0
	var weights: Array = []
	for i in RARITIES.size():
		var w: float = RARITIES[i].weight * pow(1.0 + luck, i)
		weights.append(w)
		total += w
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


func nature_mult(n: int, stat: String) -> float:
	var nat: Array = NATURES[n % NATURES.size()]
	if nat[1] == stat:
		return 1.1
	if nat[2] == stat:
		return 0.9
	return 1.0


func type_mult(atk_type: String, def_types: Array) -> float:
	var m := 1.0
	var row: Dictionary = CHART.get(atk_type, {})
	for t in def_types:
		m *= float(row.get(t, 1.0))
	return m


func xp_for_level(lv: int) -> int:
	if lv <= 1:
		return 0
	return lv * lv * lv


func base_total(sid: String) -> int:
	var b: Dictionary = species(sid).get("base", {})
	var t := 0
	for s in STATS:
		t += int(b.get(s, 0))
	return t


func base_exp(sid: String) -> int:
	var sp := species(sid)
	if sp.has("base_exp"):
		return int(sp.base_exp)
	return int(base_total(sid) / 4.0)


# ---------------- 卡牌编辑器：物种覆盖 ----------------

func save_species_override(sid: String, data: Dictionary) -> void:
	var overrides: Dictionary = _load_json(OVERRIDE_PATH, {})
	overrides[sid] = data
	DirAccess.make_dir_recursive_absolute("user://mods")
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(overrides, "  "))
	f.close()
	_rebuild_species()


func reset_species_override(sid: String) -> void:
	var overrides: Dictionary = _load_json(OVERRIDE_PATH, {})
	overrides.erase(sid)
	DirAccess.make_dir_recursive_absolute("user://mods")
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(overrides, "  "))
	f.close()
	_rebuild_species()


func has_override(sid: String) -> bool:
	var overrides: Dictionary = _load_json(OVERRIDE_PATH, {})
	return overrides.has(sid)


## 把当前（含覆盖）的物种数据写回 res://data/species.json，仅在编辑器内运行时可用
func export_species_to_project() -> bool:
	if not OS.has_feature("editor"):
		return false
	var out := {}
	for sid in species_order:
		var sp: Dictionary = species_db[sid].duplicate(true)
		sp.erase("id")
		if sp.has("learnset_ref"):
			sp.erase("learnset")
		out[sid] = sp
	var f := FileAccess.open("res://data/species.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(out, "  ", false))
	f.close()
	return true
