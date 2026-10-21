extends RefCounted

# حالة مشتركة بين القائمة الرئيسية والمشهد اللعب (تبقى بين تغيير المشاهد)

const SAVE_PATH := "user://harb_save.json"

static var mode: String = "story"      # "story" أو "free"
static var char_index: int = 0         # الشخصية المختارة في المعركة الحرة
static var story_checkpoint: int = 0   # آخر نقطة حفظ في القصة
static var shadows: bool = true
static var sensitivity: float = 1.0
static var loaded: bool = false


static func load_data() -> void:
    if loaded:
        return
    loaded = true
    # الظلال ثقيلة على الهاتف، لذلك تكون مغلقة افتراضيًا على أندرويد
    shadows = OS.get_name() != "Android"

    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed
    story_checkpoint = int(data.get("checkpoint", 0))
    shadows = bool(data.get("shadows", shadows))
    sensitivity = clampf(float(data.get("sensitivity", 1.0)), 0.4, 2.5)
    char_index = int(data.get("char_index", 0))


static func save_data() -> void:
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return
    var data: Dictionary = {
        "checkpoint": story_checkpoint,
        "shadows": shadows,
        "sensitivity": sensitivity,
        "char_index": char_index,
    }
    file.store_string(JSON.stringify(data))


static func has_progress() -> bool:
    return story_checkpoint > 0
