class_name Art
extends RefCounted
## 美术资源加载。约定路径（放入 PNG 即自动生效，缺失时使用程序绘制的占位图）：
##   精灵立绘    res://assets/pokemon/<物种id>.png        例：pikachu.png
##   闪光立绘    res://assets/pokemon/<物种id>_shiny.png  （可选，缺省时对普通立绘做金色调色）
##   品质框      res://assets/ui/frames/rarity_<品质id>.png  例：rarity_epic.png
##   属性底框    res://assets/ui/frames/type_<属性id>.png    例：type_fire.png
##   其它 UI     res://assets/ui/<名称>.png                   例：world_map.png / battle_bg.png
## 也支持 user://images/ 下的同名文件（导出后的版本可以在此放图替换）。

static var _cache := {}
static var _grad_cache := {}


static func load_tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


static func _find(rel: String) -> Texture2D:
	var t := load_tex("user://images/" + rel)
	if t:
		return t
	return load_tex("res://assets/" + rel)


static func clear_cache() -> void:
	_cache.clear()


static func portrait(sid: String, shiny: bool = false) -> Texture2D:
	var sp := DB.species(sid)
	if sp.has("image") and str(sp.image) != "":
		var custom := load_tex(str(sp.image))
		if custom:
			return custom
	if shiny:
		var s := _find("pokemon/%s_shiny.png" % sid)
		if s:
			return s
	return _find("pokemon/%s.png" % sid)


static func has_shiny_image(sid: String) -> bool:
	return _find("pokemon/%s_shiny.png" % sid) != null


static func frame_rarity(r: int) -> Texture2D:
	return _find("ui/frames/rarity_%s.png" % DB.rarity(r).id)


static func frame_type(t: String) -> Texture2D:
	return _find("ui/frames/type_%s.png" % t)


static func ui(name: String) -> Texture2D:
	return _find("ui/%s.png" % name)


static func item_icon(iid: String) -> Texture2D:
	return _find("items/%s.png" % iid)


static func gradient(c1: Color, c2: Color) -> GradientTexture2D:
	var key := c1.to_html() + c2.to_html()
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill_from = Vector2(0.2, 0.0)
	gt.fill_to = Vector2(0.8, 1.0)
	_grad_cache[key] = gt
	return gt


## 在任意 CanvasItem 上画一个精灵球
static func draw_ball(ci: CanvasItem, center: Vector2, r: float, top: Color = Color("e3350d")) -> void:
	ci.draw_circle(center, r, Color("1b1b1b"))
	ci.draw_circle(center, r * 0.88, Color("f2f2f2"))
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		pts.append(center + Vector2(cos(a), sin(a)) * r * 0.88)
	ci.draw_colored_polygon(pts, top)
	ci.draw_rect(Rect2(center.x - r * 0.88, center.y - r * 0.08, r * 1.76, r * 0.16), Color("1b1b1b"))
	ci.draw_circle(center, r * 0.3, Color("1b1b1b"))
	ci.draw_circle(center, r * 0.18, Color("f2f2f2"))


static func ball_color(iid: String) -> Color:
	match iid:
		"great_ball":
			return Color("2f6fd6")
		"ultra_ball":
			return Color("2b2b2b")
		"master_ball":
			return Color("8a3fd1")
	return Color("e3350d")


static func draw_star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI / 2 + i * PI / 4.0
		var rr := r if i % 2 == 0 else r * 0.38
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)
