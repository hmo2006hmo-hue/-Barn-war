#!/usr/bin/env python3
"""فاحص سريع لأخطاء شائعة تكتبها النماذج الصغيرة (صياغة Godot 3 وغيرها)."""
import re
import sys

RULES = [
    (r"^\s*onready\b", "استخدم @onready بدل onready"),
    (r"^\s*export\b", "استخدم @export بدل export"),
    (r"\byield\s*\(", "استخدم await بدل yield"),
    (r"\bKinematicBody\b|\bKinematicBody2D\b", "استخدم CharacterBody3D/2D"),
    (r"\bSpatial\b", "استخدم Node3D بدل Spatial"),
    (r"\.instance\(\)", "استخدم instantiate()"),
    (r"\bconnect\(\s*\"[^\"]+\"\s*,", "استخدم signal.connect(callable)"),
    (r"move_and_slide\(\s*[^)\s]", "move_and_slide() بلا معاملات في Godot 4 (استخدم velocity)"),
    (r"\brand_range\(", "استخدم randf_range/randi_range"),
    (r"\.translation\b", "استخدم position"),
    (r"\bdeg2rad\(|\brad2deg\(", "استخدم deg_to_rad/rad_to_deg"),
    (r"\bstepify\(", "استخدم snappedf/snapped"),
    (r"\bsetget\b", "استخدم setter/getter بصيغة Godot 4"),
    (r"\bPool(String|Vector2|Vector3|Int|Real|Byte|Color)Array\b", "استخدم Packed...Array"),
    (r"\bFile\.new\(\)|\bDirectory\.new\(\)", "استخدم FileAccess/DirAccess"),
    (r"change_scene\(", "استخدم change_scene_to_file"),
    (r"^\s*tool\s*$", "استخدم @tool"),
    (r"\bclass_name\b", "هذا المشروع لا يستخدم class_name (استخدم preload)"),
    (r":=\s*[A-Za-z_][\w\.]*\[[^\]]+\]\s*$", "قد يفشل استنتاج النوع مع := على عنصر قاموس/مصفوفة، اكتب النوع صراحة"),
    (r":=.*\.(get|get_meta)\(", "قد يفشل استنتاج النوع مع := على get()، اكتب النوع صراحة"),
]


def lint_text(text):
    problems = []
    lines = text.split("\n")
    has_tab = has_space = False
    depth = {"(": 0, "[": 0, "{": 0}
    for no, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped:
            continue
        lead = line[: len(line) - len(line.lstrip())]
        if "\t" in lead:
            has_tab = True
        if lead.startswith(" "):
            has_space = True
            if len(lead) % 4 != 0 and not stripped.startswith((")", "]", "}", "+", "-", '"', "#")):
                problems.append((no, "المسافة البادئة ليست من مضاعفات 4 (قد تكون استمرار سطر)"))
        if stripped.startswith("#"):
            continue
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        code = code.split("#")[0]
        for ch in code:
            if ch in "([{":
                depth[ch] += 1
            elif ch == ")":
                depth["("] -= 1
            elif ch == "]":
                depth["["] -= 1
            elif ch == "}":
                depth["{"] -= 1
        if re.match(r"^(static\s+)?func\s", stripped) and not stripped.endswith(":") and depth["("] == 0:
            if not stripped.endswith(("\\", ",", "(")):
                problems.append((no, "سطر func لا ينتهي بنقطتين"))
        for pattern, message in RULES:
            if re.search(pattern, line):
                problems.append((no, message))
    if has_tab and has_space:
        problems.append((0, "خلط بين TAB والمسافات"))
    for ch, n in depth.items():
        if n != 0:
            problems.append((0, "أقواس غير متوازنة: " + ch + " (الفرق " + str(n) + ")"))
    return problems


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        print("الاستخدام: python ai_kit/lint_gd.py ملف1.gd [ملف2.gd]")
        return 1
    bad = 0
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8") as f:
            problems = lint_text(f.read())
        if not problems:
            print("OK  " + path)
            continue
        bad += 1
        print("!!  " + path)
        for no, message in problems:
            print("   سطر " + str(no) + ": " + message)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
