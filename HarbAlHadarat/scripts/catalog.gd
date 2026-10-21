extends RefCounted

# فهرس الأصول: يقرأ ملفات GLB ويفرّق بين الشخصيات والمباني.
# السبب القديم للخطأ: المباني كانت داخل مجلد الشخصيات وأسماؤها في الشيفرة
# لا تطابق أسماء الملفات (شرطة سفلية/مسافة/ياء فارسية)، فكانت تظهر كأعداء.
# الآن التصنيف يتم بكلمات مفتاحية بعد توحيد الحروف، ولا يعتمد على اسم ملف دقيق.

const CHARACTER_FOLDER := "res://assets/characters"
const BUILDING_FOLDER := "res://assets/environment"

# كلمات تدل على المباني (بعد التوحيد)
const BUILDING_WORDS := ["سور", "بواب", "مزرع", "مركز", "مبني", "برج", "ثكن", "مخزن"]
# كلمات تدل على المقاتلين
const FIGHTER_WORDS := ["جندي", "محارب", "رامي", "حامل"]


# توحيد الحروف: الهمزات، التاء المربوطة، الياء، التشكيل، الشرطة السفلية
static func normalize(text: String) -> String:
    var r: String = text.get_basename() if text.contains(".") else text
    r = r.replace("_", " ")
    for ch in ["آ", "أ", "إ"]:
        r = r.replace(ch, "ا")
    r = r.replace("ة", "ه")
    r = r.replace("ى", "ي")
    r = r.replace(char(0x06CC), "ي")  # الياء الفارسية
    r = r.replace(char(0x0640), "")   # التطويل
    for code in [0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652]:
        r = r.replace(char(code), "")
    return r.strip_edges()


static func _has_any(text: String, words: Array) -> bool:
    for w in words:
        if text.contains(String(w)):
            return true
    return false


# قائمة ملفات النماذج في مجلد (تدعم لواحق .remap/.import في نسخة APK)
static func list_models(folder_path: String) -> Array:
    var result: Array = []
    var seen := {}
    var directory := DirAccess.open(folder_path)
    if directory == null:
        return result

    directory.list_dir_begin()
    var filename: String = directory.get_next()
    while filename != "":
        if not directory.current_is_dir():
            var real_name: String = filename
            for suffix in [".remap", ".import"]:
                if real_name.ends_with(suffix):
                    real_name = real_name.trim_suffix(suffix)
            var extension: String = real_name.get_extension().to_lower()
            if (extension == "glb" or extension == "gltf") and not seen.has(real_name):
                seen[real_name] = true
                result.append(folder_path + "/" + real_name)
        filename = directory.get_next()
    directory.list_dir_end()
    result.sort()
    return result


static func _building_key(norm: String) -> String:
    if norm.contains("برج"):
        return "tower"
    if norm.contains("ثكن"):
        return "barracks"
    if norm.contains("مخزن"):
        return "store"
    if norm.contains("مزرع"):
        return "farm"
    if norm.contains("مركز"):
        return "hall"
    if norm.contains("سور") or norm.contains("بواب"):
        return "gate"
    if norm.contains("مبني"):
        return "house"
    return "other"


static func _kingdom(norm: String) -> String:
    if norm.contains("سومر"):
        return "سومر"
    if norm.contains("اكد"):
        return "أكد"
    if norm.contains("اشور"):
        return "آشور"
    if norm.contains("بابل"):
        return "بابل"
    if norm.contains("مصر"):
        return "مصر"
    if norm.contains("حثي"):
        return "الحثيون"
    return "مجهول"


# إحصاءات المقاتل حسب نوعه. hp = عدد الضربات اللازمة
static func _fighter_stats(norm: String) -> Dictionary:
    if norm.contains("رامي"):
        return {"tag": "archer", "role": "رامٍ", "hp": 2.0, "speed": 2.5, "damage": 7.0, "reach": 11.0, "cooldown": 2.4}
    if norm.contains("ثقيل"):
        return {"tag": "heavy", "role": "مشاة ثقيل", "hp": 5.0, "speed": 1.8, "damage": 15.0, "reach": 2.1, "cooldown": 2.0}
    if norm.contains("درع"):
        return {"tag": "shield", "role": "حامل درع", "hp": 4.0, "speed": 2.0, "damage": 8.0, "reach": 1.9, "cooldown": 1.5}
    if norm.contains("رمح"):
        return {"tag": "spear", "role": "حامل رمح", "hp": 3.0, "speed": 2.4, "damage": 9.0, "reach": 2.6, "cooldown": 1.6}
    return {"tag": "infantry", "role": "مشاة", "hp": 3.0, "speed": 2.6, "damage": 8.0, "reach": 1.9, "cooldown": 1.3}


static func scan() -> Dictionary:
    var characters: Array = []
    var buildings: Array = []

    for path in list_models(CHARACTER_FOLDER):
        var file_name: String = String(path).get_file()
        var norm: String = normalize(file_name)
        var display: String = file_name.get_basename().replace("_", " ")
        if _has_any(norm, BUILDING_WORDS):
            buildings.append({"path": path, "name": display, "key": _building_key(norm)})
        else:
            var entry: Dictionary = _fighter_stats(norm)
            entry["path"] = path
            entry["name"] = display
            entry["kingdom"] = _kingdom(norm)
            characters.append(entry)

    for path in list_models(BUILDING_FOLDER):
        var file_name2: String = String(path).get_file()
        var norm2: String = normalize(file_name2)
        var display2: String = file_name2.get_basename().replace("_", " ")
        buildings.append({"path": path, "name": display2, "key": _building_key(norm2)})

    return {"characters": characters, "buildings": buildings}


static func find_building(buildings: Array, key: String) -> Dictionary:
    for b in buildings:
        var entry: Dictionary = b
        if entry["key"] == key:
            return entry
    return {}


# يختار شخصية حسب نوعها مع استثناء مسار معيّن (مثل مسار البطل)
static func pick(characters: Array, tag: String, salt: int = 0, exclude_path: String = "") -> Dictionary:
    var matches: Array = []
    for c in characters:
        var entry: Dictionary = c
        if entry["path"] == exclude_path:
            continue
        if entry["tag"] == tag:
            matches.append(entry)
    if matches.is_empty():
        for c2 in characters:
            var entry2: Dictionary = c2
            if entry2["path"] != exclude_path:
                matches.append(entry2)
    if matches.is_empty():
        return {}
    return matches[salt % matches.size()]


static func find_by_kingdom(characters: Array, kingdom: String) -> Dictionary:
    for c in characters:
        var entry: Dictionary = c
        if entry["kingdom"] == kingdom:
            return entry
    if characters.is_empty():
        return {}
    return characters[0]
