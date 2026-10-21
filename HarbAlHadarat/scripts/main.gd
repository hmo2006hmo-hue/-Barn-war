extends Control

# القائمة الرئيسية: ابدأ القصة، متابعة، معركة حرة، إعدادات، عن اللعبة، خروج

const Rig = preload("res://scripts/rig.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Session = preload("res://scripts/session.gd")
const UI = preload("res://scripts/ui_kit.gd")
const Story = preload("res://scripts/story.gd")

const GAME_SCENE := "res://scenes/game.tscn"

var characters: Array = []
var screens: Dictionary = {}
var current_screen: String = ""

var bg: Control
var continue_button: Button
var status_label: Label
var char_name_label: Label
var char_info_label: Label

var preview_holder: Node3D
var preview_rig = null


func _ready() -> void:
    Session.load_data()
    var catalog: Dictionary = Catalog.scan()
    characters = catalog["characters"]

    layout_direction = Control.LAYOUT_DIRECTION_LTR
    theme = UI.make_theme()

    _build_background()
    _build_preview()
    _build_title()
    _build_panel()
    _show_screen("main")
    _set_preview(_hero_path())

    if characters.is_empty():
        status_label.text = "لم يُعثر على شخصيات داخل assets/characters"


func _process(delta: float) -> void:
    if preview_holder != null:
        preview_holder.rotation.y += delta * 0.55
    if preview_rig != null:
        preview_rig.animate(delta, false, false, -1.0)


func _notification(what: int) -> void:
    # زر الرجوع في أندرويد
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if current_screen != "main":
            _show_screen("main")
        else:
            get_tree().quit()


# --------------------------------------------------
# الخلفية: سماء الغروب وزقورة
# --------------------------------------------------

func _build_background() -> void:
    bg = Control.new()
    UI.full_rect(bg)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.draw.connect(_draw_background)
    bg.resized.connect(bg.queue_redraw)
    add_child(bg)


func _draw_background() -> void:
    var w: float = bg.size.x
    var h: float = bg.size.y
    var top := Color("#0a1020")
    var mid := Color("#2b2542")
    var low := Color("#9a6238")

    bg.draw_polygon(
        PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.62), Vector2(0, h * 0.62)]),
        PackedColorArray([top, top, mid, mid]))
    bg.draw_polygon(
        PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h * 0.84), Vector2(0, h * 0.84)]),
        PackedColorArray([mid, mid, low, low]))
    bg.draw_rect(Rect2(0.0, h * 0.84, w, h * 0.16), Color("#17120f"))

    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    for i in 70:
        var p := Vector2(rng.randf() * w, rng.randf() * h * 0.5)
        bg.draw_circle(p, rng.randf_range(0.7, 1.7), Color(1, 1, 1, rng.randf_range(0.25, 0.75)))

    bg.draw_circle(Vector2(w * 0.3, h * 0.78), h * 0.12, Color(0.98, 0.78, 0.48, 0.9))

    # زقورة بخمس طبقات
    var base_y: float = h * 0.84
    var tier_h: float = h * 0.055
    var cx: float = w * 0.46
    var width: float = w * 0.34
    var silhouette := Color(0.07, 0.055, 0.07, 0.96)
    for t in 5:
        var tw: float = width * (1.0 - float(t) * 0.18)
        bg.draw_rect(Rect2(cx - tw * 0.5, base_y - tier_h * float(t + 1), tw, tier_h), silhouette)
    bg.draw_rect(Rect2(cx - width * 0.05, base_y - tier_h * 5.0 - tier_h * 0.9, width * 0.1, tier_h * 0.9), silhouette)


# --------------------------------------------------
# معاينة ثلاثية الأبعاد للشخصية
# --------------------------------------------------

func _build_preview() -> void:
    var container := SubViewportContainer.new()
    container.stretch = true
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.anchor_left = 0.0
    container.anchor_top = 0.0
    container.anchor_right = 0.56
    container.anchor_bottom = 1.0
    container.offset_left = 0.0
    container.offset_top = 0.0
    container.offset_right = 0.0
    container.offset_bottom = 0.0
    add_child(container)

    var viewport := SubViewport.new()
    viewport.transparent_bg = true
    viewport.own_world_3d = true
    container.add_child(viewport)

    var stage := Node3D.new()
    viewport.add_child(stage)

    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.52, 0.6)
    env.ambient_light_energy = 0.7
    world_env.environment = env
    stage.add_child(world_env)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
    key.light_energy = 1.5
    stage.add_child(key)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
    fill.light_energy = 0.6
    stage.add_child(fill)

    var cam := Camera3D.new()
    cam.fov = 38.0
    cam.position = Vector3(0.0, 1.2, 4.2)
    cam.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
    cam.current = true
    stage.add_child(cam)

    preview_holder = Node3D.new()
    stage.add_child(preview_holder)


func _set_preview(path: String) -> void:
    if preview_rig != null and preview_rig.pivot != null and is_instance_valid(preview_rig.pivot):
        preview_rig.pivot.queue_free()
    preview_rig = Rig.new()
    preview_rig.setup(path, preview_holder, 1.75)


func _hero_path() -> String:
    var entry: Dictionary = Catalog.find_by_kingdom(characters, Story.HERO_KINGDOM)
    return String(entry.get("path", ""))


# --------------------------------------------------
# العنوان واللوحة
# --------------------------------------------------

func _build_title() -> void:
    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    box.offset_top = 26.0
    box.offset_bottom = 170.0
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_theme_constant_override("separation", 2)
    add_child(box)

    var title := UI.label("حرب الحضارات", 58, UI.GOLD)
    UI.outline(title, 8)
    box.add_child(title)

    var subtitle := UI.label("العهد القديم لا يموت", 24, UI.TEXT)
    UI.outline(subtitle, 5)
    box.add_child(subtitle)

    var kingdoms := UI.label("سومر   •   أكد   •   آشور   •   بابل", 18, UI.GOLD_DARK)
    UI.outline(kingdoms, 4)
    box.add_child(kingdoms)


func _build_panel() -> void:
    var panel := PanelContainer.new()
    panel.anchor_left = 0.6
    panel.anchor_right = 0.97
    panel.anchor_top = 0.27
    panel.anchor_bottom = 0.95
    panel.offset_left = 0.0
    panel.offset_right = 0.0
    panel.offset_top = 0.0
    panel.offset_bottom = 0.0
    panel.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.13, 0.19, 0.88), 16, Color(0.83, 0.69, 0.41, 0.45), 2, 18.0))
    add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    panel.add_child(column)

    screens["main"] = _build_main_screen()
    screens["free"] = _build_free_screen()
    screens["settings"] = _build_settings_screen()
    screens["about"] = _build_about_screen()
    for key in screens:
        column.add_child(screens[key])

    status_label = UI.label("", 15, UI.GOLD)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status_label)


func _show_screen(screen_name: String) -> void:
    var was_free: bool = current_screen == "free"
    current_screen = screen_name
    for key in screens:
        (screens[key] as Control).visible = (key == screen_name)
    status_label.text = ""
    if screen_name == "free":
        _select_character(Session.char_index)
    elif was_free:
        _set_preview(_hero_path())


func _screen_box(title_text: String) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 10)
    box.add_child(UI.label(title_text, 26, UI.GOLD))
    return box


func _build_main_screen() -> VBoxContainer:
    var box := _screen_box("القائمة الرئيسية")

    var story := UI.button("ابدأ القصة", 0.0, 60.0, true, 24)
    story.pressed.connect(_on_story)
    box.add_child(story)

    continue_button = UI.button("متابعة القصة", 0.0, 52.0)
    continue_button.disabled = not Session.has_progress()
    continue_button.pressed.connect(_on_continue)
    box.add_child(continue_button)

    var free := UI.button("معركة حرة", 0.0, 52.0)
    free.pressed.connect(func(): _show_screen("free"))
    box.add_child(free)

    var settings := UI.button("الإعدادات", 0.0, 52.0)
    settings.pressed.connect(func(): _show_screen("settings"))
    box.add_child(settings)

    var about := UI.button("عن اللعبة", 0.0, 52.0)
    about.pressed.connect(func(): _show_screen("about"))
    box.add_child(about)

    var quit := UI.button("خروج", 0.0, 46.0)
    quit.pressed.connect(func(): get_tree().quit())
    box.add_child(quit)
    return box


func _build_free_screen() -> VBoxContainer:
    var box := _screen_box("معركة حرة: اختر مقاتلك")

    char_name_label = UI.label("", 26, UI.TEXT)
    char_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(char_name_label)

    char_info_label = UI.label("", 18, UI.MUTED)
    box.add_child(char_info_label)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(row)

    # الاتجاه يتبع القراءة العربية: التالي إلى اليسار والسابق إلى اليمين
    var next_button := UI.button("◀ التالي", 150.0, 50.0)
    next_button.pressed.connect(func(): _select_character(Session.char_index + 1))
    row.add_child(next_button)

    var prev_button := UI.button("السابق ▶", 150.0, 50.0)
    prev_button.pressed.connect(func(): _select_character(Session.char_index - 1))
    row.add_child(prev_button)

    var start := UI.button("ابدأ المعركة", 0.0, 58.0, true, 24)
    start.pressed.connect(_on_free_start)
    box.add_child(start)

    var back := UI.button("رجوع", 0.0, 46.0)
    back.pressed.connect(func(): _show_screen("main"))
    box.add_child(back)
    return box


func _select_character(index: int) -> void:
    if characters.is_empty():
        char_name_label.text = "الشخصية المؤقتة"
        char_info_label.text = ""
        return
    Session.char_index = posmod(index, characters.size())
    var entry: Dictionary = characters[Session.char_index]
    char_name_label.text = String(entry["name"])
    char_info_label.text = String(entry["kingdom"]) + "  •  " + String(entry["role"])
    _set_preview(String(entry["path"]))


func _build_settings_screen() -> VBoxContainer:
    var box := _screen_box("الإعدادات")

    var shadows := CheckButton.new()
    shadows.text = "الظلال (تبطئ الأجهزة الضعيفة)"
    shadows.button_pressed = Session.shadows
    shadows.focus_mode = Control.FOCUS_NONE
    shadows.add_theme_font_size_override("font_size", 20)
    shadows.toggled.connect(_on_shadows_toggled)
    box.add_child(shadows)

    box.add_child(UI.label("حساسية الكاميرا", 18, UI.TEXT))
    var slider := HSlider.new()
    slider.min_value = 0.5
    slider.max_value = 2.0
    slider.step = 0.1
    slider.value = Session.sensitivity
    slider.custom_minimum_size = Vector2(0.0, 28.0)
    slider.focus_mode = Control.FOCUS_NONE
    slider.value_changed.connect(_on_sensitivity_changed)
    box.add_child(slider)

    var reset := UI.button("مسح تقدّم القصة", 0.0, 48.0)
    reset.pressed.connect(_on_reset_progress)
    box.add_child(reset)

    var back := UI.button("رجوع", 0.0, 46.0)
    back.pressed.connect(func(): _show_screen("main"))
    box.add_child(back)
    return box


func _on_shadows_toggled(on: bool) -> void:
    Session.shadows = on
    Session.save_data()


func _on_sensitivity_changed(value: float) -> void:
    Session.sensitivity = value
    Session.save_data()


func _on_reset_progress() -> void:
    Session.story_checkpoint = 0
    Session.save_data()
    continue_button.disabled = true
    status_label.text = "تم مسح تقدّم القصة."


func _build_about_screen() -> VBoxContainer:
    var box := _screen_box("عن اللعبة")

    var info := UI.label(
        "لعبة أكشن ومغامرة في عالم بلاد الرافدين البديل.\n\n"
        + "اللمس: اسحب في النصف الأيسر للحركة، والأيمن لتدوير الكاميرا، واستخدم أزرار الهجوم والركض والشظية.\n"
        + "الحاسوب: WASD للحركة، Shift للركض، مسافة أو النقر للهجوم، F للشظية، الزر الأيمن للفأرة لتدوير الكاميرا، Esc للإيقاف.\n\n"
        + "نسخة تجريبية: الفصل الأول (نَمار).",
        16, UI.TEXT)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.custom_minimum_size = Vector2(380.0, 0.0)
    box.add_child(info)

    var back := UI.button("رجوع", 0.0, 46.0)
    back.pressed.connect(func(): _show_screen("main"))
    box.add_child(back)
    return box


# --------------------------------------------------
# التنقل
# --------------------------------------------------

func _on_story() -> void:
    Session.mode = "story"
    Session.story_checkpoint = 0
    Session.save_data()
    _go_game()


func _on_continue() -> void:
    Session.mode = "story"
    _go_game()


func _on_free_start() -> void:
    Session.mode = "free"
    Session.save_data()
    _go_game()


func _go_game() -> void:
    var error: int = get_tree().change_scene_to_file(GAME_SCENE)
    if error != OK:
        status_label.text = "تعذر فتح مشهد اللعب. تحقق من الملف scenes/game.tscn"
