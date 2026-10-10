class_name UI
extends RefCounted
## 主题与常用控件构造工具

static var BG := Color("10162a")
static var PANEL := Color("1a2240")
static var PANEL2 := Color("253058")
static var BORDER := Color("33407a")
static var ACCENT := Color("ffcb05")
static var BLUE := Color("3d7dca")
static var TEXT := Color("e8ecf8")
static var MUTED := Color("8f9bc0")
static var GOOD := Color("4cd07d")
static var BAD := Color("ff5d6c")

static var font: Font
static var font_bold: Font


static func build_theme() -> Theme:
	var names := PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei", "sans-serif"])
	var f := SystemFont.new()
	f.font_names = names
	font = f
	var fb := SystemFont.new()
	fb.font_names = names
	fb.font_weight = 700
	font_bold = fb

	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 16

	var bn := style(PANEL2, 8, BORDER, 1)
	bn.content_margin_left = 14
	bn.content_margin_right = 14
	bn.content_margin_top = 6
	bn.content_margin_bottom = 6
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = PANEL2.lightened(0.12)
	bh.border_color = ACCENT.darkened(0.2)
	var bp := bn.duplicate() as StyleBoxFlat
	bp.bg_color = ACCENT.darkened(0.25)
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = PANEL.darkened(0.1)
	bd.border_color = PANEL2
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("hover_pressed", cls, bp)
		t.set_stylebox("disabled", cls, bd)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color("1a1a1a"))
		t.set_color("font_hover_pressed_color", cls, Color("1a1a1a"))
		t.set_color("font_disabled_color", cls, MUTED.darkened(0.3))

	var panel := style(PANEL, 12, BORDER, 1)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var pop := style(PANEL2, 8, BORDER, 1)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("panel", "TooltipPanel", pop)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("hover", "PopupMenu", style(PANEL2.lightened(0.1), 6))

	t.set_color("font_color", "Label", TEXT)
	var le := style(BG, 6, BORDER, 1)
	le.content_margin_left = 8
	le.content_margin_right = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", style(BG, 6, ACCENT, 1))
	t.set_color("font_color", "LineEdit", TEXT)

	t.set_stylebox("background", "ProgressBar", style(Color(0, 0, 0, 0.45), 4))
	t.set_stylebox("fill", "ProgressBar", style(GOOD, 4))

	t.set_stylebox("panel", "TabContainer", style(PANEL, 10, BORDER, 1))
	var tab_sel := style(PANEL2, 8)
	tab_sel.content_margin_left = 16
	tab_sel.content_margin_right = 16
	tab_sel.content_margin_top = 6
	tab_sel.content_margin_bottom = 6
	var tab_un := tab_sel.duplicate() as StyleBoxFlat
	tab_un.bg_color = PANEL.darkened(0.2)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_sel)
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)

	t.set_stylebox("panel", "ItemList", style(BG, 8, BORDER, 1))
	t.set_stylebox("selected", "ItemList", style(PANEL2, 4))
	t.set_stylebox("selected_focus", "ItemList", style(PANEL2.lightened(0.1), 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", ACCENT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func style(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.anti_aliasing = true
	return s


static func lbl(text: String, size: int = 16, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	return l


static func btn(text: String, cb: Callable = Callable(), min_w: int = 0, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	if cb.is_valid():
		b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func accent_btn(text: String, cb: Callable = Callable(), min_w: int = 0, color: Color = ACCENT) -> Button:
	var b := btn(text, cb, min_w)
	var n := style(color, 8)
	n.content_margin_left = 14
	n.content_margin_right = 14
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = color.lightened(0.15)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = color.darkened(0.2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	var fc := Color("1a1a1a") if color.get_luminance() > 0.5 else Color.WHITE
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(color: Color = PANEL, radius: int = 12, pad: int = 12, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(color, radius, border, 1 if border.a > 0 else 0)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", s)
	return p


static func spacer(h: bool = true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func pill(text: String, color: Color, size: int = 13) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(color, 10)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	var fc := Color("1a1a1a") if color.get_luminance() > 0.55 else Color.WHITE
	var l := lbl(text, size, fc, true)
	p.add_child(l)
	return p


static func type_pill(t: String, size: int = 13) -> PanelContainer:
	return pill(DB.type_name(t), DB.type_color(t), size)


static func rarity_pill(r: int, size: int = 13) -> PanelContainer:
	var rd := DB.rarity(r)
	return pill(rd.name, rd.color, size)


static func bar(value: float, max_value: float, color: Color, w: int = 200, h: int = 12) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_stylebox_override("fill", style(color, 4))
	return b


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return GOOD
	if ratio > 0.2:
		return ACCENT
	return BAD


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func scroll(child: Control, horizontal: bool = false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func fmt_num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func fmt_time(sec: int) -> String:
	var h := int(sec / 3600.0)
	var m := int((sec % 3600) / 60.0)
	if h > 0:
		return "%d小时%d分钟" % [h, m]
	return "%d分钟" % m
