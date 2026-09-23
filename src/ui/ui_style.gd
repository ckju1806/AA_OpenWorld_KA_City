class_name UiStyle
extends RefCounted
## Eigenes Oberflächen-Design "Fächer-City": dunkle, halbtransparente Tafeln mit orangem Akzent.

const ACCENT: Color = Color(0.95, 0.62, 0.25)
const ACCENT_DARK: Color = Color(0.55, 0.3, 0.12)
const TEXT: Color = Color(0.96, 0.94, 0.9)
const TEXT_DIM: Color = Color(0.78, 0.76, 0.72)
const PANEL: Color = Color(0.07, 0.065, 0.08, 0.78)
const GOOD: Color = Color(0.45, 0.85, 0.5)
const BAD: Color = Color(0.95, 0.35, 0.3)
const POLICE_BLUE: Color = Color(0.25, 0.5, 1.0)


static func panel_box(accent_left: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	if accent_left:
		sb.border_width_left = 4
		sb.border_color = ACCENT
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func label(text: String, size: int, color: Color = TEXT, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


static func panel(accent_left: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(accent_left))
	return p


static func bar(fill: Color, height: float = 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.14, 0.16, 0.9)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fg := bg.duplicate() as StyleBoxFlat
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(420, 58)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.09, 0.11, 0.85)
	normal.border_width_left = 4
	normal.border_color = ACCENT_DARK
	normal.content_margin_left = 20
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.13, 0.08, 0.95)
	hover.border_color = ACCENT
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.3, 0.18, 0.08, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.08, 0.09, 0.6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void: AudioManager.play_2d("ui_click", -6.0))
	return b


## Geldbetrag mit deutschem Tausenderpunkt.
static func money(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	var c: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if v < 0 else "") + out + " €"
