class_name Portrait
extends Control
## 精灵立绘：有图片显示图片，没有图片时按属性颜色绘制占位图

var species_id := ""
var shiny := false
var silhouette := false
var flip_h := false
var _tex: Texture2D


func setup(sid: String, is_shiny: bool = false, is_silhouette: bool = false) -> Portrait:
	species_id = sid
	shiny = is_shiny
	silhouette = is_silhouette
	_tex = Art.portrait(sid, is_shiny)
	queue_redraw()
	return self


func _draw() -> void:
	if species_id == "" or size.x < 2:
		return
	if _tex:
		var ts := _tex.get_size()
		var sc := minf(size.x / ts.x, size.y / ts.y)
		var ds := ts * sc
		var pos := (size - ds) / 2.0
		var mod := Color.WHITE
		if silhouette:
			mod = Color(0, 0, 0, 0.85)
		elif shiny and not Art.has_shiny_image(species_id):
			mod = Color(1.0, 0.86, 0.55)
		if flip_h:
			draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(_tex, Rect2(pos, ds), false, mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_placeholder()
	if shiny and not silhouette:
		var r := minf(size.x, size.y) * 0.08
		Art.draw_star(self, Vector2(size.x - r * 1.6, r * 1.6), r, Color("fff27a"))
		Art.draw_star(self, Vector2(size.x - r * 3.2, r * 3.4), r * 0.55, Color("fff27a"))


func _draw_placeholder() -> void:
	var sp := DB.species(species_id)
	var types: Array = sp.get("types", ["normal"])
	var c1 := DB.type_color(types[0])
	var c2 := DB.type_color(types[1]) if types.size() > 1 else c1.darkened(0.3)
	if silhouette:
		c1 = Color(0.08, 0.09, 0.14)
		c2 = Color(0.15, 0.16, 0.22)
	elif shiny:
		c1 = c1.lerp(Color("ffd84a"), 0.45)
	var center := size / 2.0
	var rad := minf(size.x, size.y) * 0.4
	draw_set_transform(center + Vector2(0, rad * 0.95), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, rad * 0.9, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(center, rad, c2.darkened(0.2))
	draw_circle(center, rad * 0.86, c1)
	draw_circle(center + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.35, Color(1, 1, 1, 0.18))
	draw_arc(center, rad * 0.93, 0, TAU, 48, c2, maxf(2.0, rad * 0.1), true)
	var txt := "?" if silhouette else str(sp.get("name", "?")).substr(0, 1)
	var fs := int(rad * 0.95)
	var f: Font = UI.font if UI.font else get_theme_default_font()
	draw_string(f, Vector2(0, center.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1, 0.92) if not silhouette else Color(0.5, 0.55, 0.7))
