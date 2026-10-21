extends RefCounted

# أدوات واجهة مشتركة: الألوان والخط والأزرار

const BG := Color("#0d1420")
const PANEL := Color("#1a2331")
const PANEL_LIGHT := Color("#263246")
const GOLD := Color("#d4b06a")
const GOLD_DARK := Color("#a8864a")
const TEXT := Color("#f3ead8")
const MUTED := Color("#9aa7b8")
const DANGER := Color("#c0463a")
const SHARD := Color("#8a5cf0")


# خط النظام يدعم العربية على أندرويد وويندوز وغيرها
static func make_theme() -> Theme:
    var theme := Theme.new()
    var font := SystemFont.new()
    font.font_names = PackedStringArray([
        "Noto Naskh Arabic", "Noto Sans Arabic", "Droid Arabic Naskh",
        "Tahoma", "Segoe UI", "Arial", "sans-serif",
    ])
    theme.default_font = font
    theme.default_font_size = 20
    return theme


static func box(color: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_width: int = 0, margin: float = 12.0) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radius)
    if border_width > 0:
        sb.border_color = border
        sb.set_border_width_all(border_width)
    sb.set_content_margin_all(margin)
    return sb


static func full_rect(c: Control) -> void:
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


static func outline(l: Label, width: int = 6) -> void:
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    l.add_theme_constant_override("outline_size", width)


static func button(text: String, width: float = 260.0, height: float = 56.0, primary: bool = false, font_size: int = 22) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(width, height)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", font_size)

    var normal_color: Color = GOLD if primary else PANEL_LIGHT
    var hover_color: Color = Color("#e6c98a") if primary else Color("#34445e")
    var press_color: Color = GOLD_DARK if primary else Color("#18202d")
    var text_color: Color = Color("#151920") if primary else TEXT

    b.add_theme_stylebox_override("normal", box(normal_color, 10))
    b.add_theme_stylebox_override("hover", box(hover_color, 10))
    b.add_theme_stylebox_override("pressed", box(press_color, 10))
    b.add_theme_stylebox_override("disabled", box(Color(0.16, 0.19, 0.25, 0.8), 10))
    b.add_theme_color_override("font_color", text_color)
    b.add_theme_color_override("font_hover_color", text_color)
    b.add_theme_color_override("font_pressed_color", text_color)
    b.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.62))
    return b


static func bar(width: float, height: float, fill: Color) -> ProgressBar:
    var p := ProgressBar.new()
    p.show_percentage = false
    p.custom_minimum_size = Vector2(width, height)
    p.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.55), 6, Color(1, 1, 1, 0.18), 1, 0.0))
    p.add_theme_stylebox_override("fill", box(fill, 6, Color(0, 0, 0, 0), 0, 0.0))
    return p
