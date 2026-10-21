#!/usr/bin/env python3
"""مساعد التعامل مع النموذج المحلي (Ollama) بدون أي مكتبات إضافية.

أمثلة:
  python ai_kit/ask.py "اجعل العدو أبطأ بنسبة 20%" scripts/game.gd --func _ai_enemy
  python ai_kit/ask.py "add a new dialogue line" scripts/story.gd
  python ai_kit/ask.py "..." scripts/game.gd --func _ai_enemy --apply
  python ai_kit/ask.py "..." scripts/game.gd --func _ai_enemy --dry-run
"""
import argparse
import datetime
import difflib
import json
import os
import re
import shutil
import sys
import urllib.request

KIT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(KIT)
OUT = os.path.join(KIT, "out")
sys.path.insert(0, KIT)
from lint_gd import lint_text  # noqa: E402

TOP_LEVEL = re.compile(r"^(func |static func |class |const |var |enum |signal |@|extends )")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def find_func(lines, name):
    """يرجع (بداية، نهاية) الدالة بالأسطر، النهاية غير شاملة."""
    start = None
    for i, line in enumerate(lines):
        if re.match(r"^(static\s+)?func\s+" + re.escape(name) + r"\s*\(", line):
            start = i
            break
    if start is None:
        return None
    # نرجع للخلف لتشمل التعليقات الملاصقة فوق الدالة
    while start > 0 and lines[start - 1].startswith("#"):
        start -= 1
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("#") or not lines[j].strip():
            continue
        if TOP_LEVEL.match(lines[j]) and not re.match(r"^(static\s+)?func\s+" + re.escape(name) + r"\b", lines[j]):
            end = j
            break
    # لا نأخذ الأسطر الفارغة في النهاية
    while end > start and not lines[end - 1].strip():
        end -= 1
    return start, end


def build_prompt(task, files, func):
    parts = ["# Project conventions\n" + read(os.path.join(KIT, "CONVENTIONS.md"))]
    for path in files:
        full = path if os.path.isabs(path) else os.path.join(ROOT, path)
        src = read(full)
        rel = os.path.relpath(full, ROOT).replace("\\", "/")
        if func:
            lines = src.split("\n")
            span = find_func(lines, func)
            if span is None:
                sys.exit("لم أجد الدالة " + func + " في " + rel)
            body = "\n".join(lines[span[0]:span[1]])
            parts.append("# File: " + rel + " (only function " + func + ")\n```gdscript\n" + body + "\n```")
        else:
            parts.append("# File: " + rel + "\n```gdscript\n" + src + "\n```")
    if func:
        parts.append("# Task\n" + task + "\n\nReturn ONLY the complete updated function `" + func + "` in one ```gdscript block.")
    else:
        parts.append("# Task\n" + task + "\n\nReturn the complete updated file in one ```gdscript block.")
    return "\n\n".join(parts)


def call_ollama(model, prompt, ctx):
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "stream": True,
        "options": {"num_ctx": ctx, "temperature": 0.2},
    }).encode("utf-8")
    req = urllib.request.Request("http://localhost:11434/api/chat", data=body,
                                 headers={"Content-Type": "application/json"})
    text = ""
    try:
        with urllib.request.urlopen(req, timeout=3600) as resp:
            for raw in resp:
                if not raw.strip():
                    continue
                obj = json.loads(raw.decode("utf-8"))
                piece = obj.get("message", {}).get("content", "")
                text += piece
                sys.stdout.write(piece)
                sys.stdout.flush()
    except Exception as e:  # noqa: BLE001
        sys.exit("\nتعذر الاتصال بـ Ollama: " + str(e) + "\nتأكد أن Ollama يعمل (ollama serve) وأن النموذج موجود (ollama list).")
    print()
    return text


def extract_code(reply):
    blocks = re.findall(r"```(?:gdscript|gd|)\n(.*?)```", reply, re.DOTALL)
    if not blocks:
        return None
    return max(blocks, key=len).rstrip("\n")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("task")
    ap.add_argument("files", nargs="+")
    ap.add_argument("--func", help="أرسل هذه الدالة فقط (يوفر السياق ويرفع الجودة)")
    ap.add_argument("--model", default="godot-coder")
    ap.add_argument("--ctx", type=int, default=8192)
    ap.add_argument("--apply", action="store_true", help="طبّق التعديل بعد أخذ نسخة .bak")
    ap.add_argument("--dry-run", action="store_true", help="اعرض حجم الطلب فقط")
    args = ap.parse_args()

    if args.func and len(args.files) != 1:
        sys.exit("مع --func أرسل ملفاً واحداً فقط")

    prompt = build_prompt(args.task, args.files, args.func)
    approx_tokens = len(prompt) // 3
    print("حجم الطلب التقريبي: " + str(approx_tokens) + " توكن من أصل " + str(args.ctx))
    if approx_tokens > args.ctx * 0.75:
        print("تحذير: الطلب كبير على السياق. استخدم --func أو قلّل الملفات.")
    if args.dry_run:
        print(prompt[-1500:])
        return

    os.makedirs(OUT, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    reply = call_ollama(args.model, prompt, args.ctx)
    with open(os.path.join(OUT, stamp + "_reply.md"), "w", encoding="utf-8") as f:
        f.write(reply)

    code = extract_code(reply)
    if code is None:
        print("\nلم أجد كتلة شيفرة في الرد. ربما طلب النموذج توضيحاً، اقرأ الرد أعلاه.")
        return

    target = args.files[0]
    target_full = target if os.path.isabs(target) else os.path.join(ROOT, target)
    original = read(target_full)
    if args.func:
        lines = original.split("\n")
        s, e = find_func(lines, args.func)
        proposed = "\n".join(lines[:s] + code.split("\n") + lines[e:])
    else:
        proposed = code + "\n"

    problems = lint_text(proposed)
    print("\n==== نتيجة الفحص ====")
    if problems:
        for no, msg in problems:
            print("سطر " + str(no) + ": " + msg)
        print("الفحص وجد مشاكل. الأفضل ألا تطبّق، وأعد الطلب مع ذكر المشكلة.")
    else:
        print("لا مشاكل ظاهرة (هذا لا يغني عن التجربة في Godot).")

    proposed_path = os.path.join(OUT, stamp + "_" + os.path.basename(target) + ".proposed")
    with open(proposed_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(proposed)

    print("\n==== الفرق ====")
    diff = list(difflib.unified_diff(original.split("\n"), proposed.split("\n"), "قبل", "بعد", lineterm="", n=2))
    print("\n".join(diff) if diff else "(لا فرق)")

    if args.apply and diff:
        if problems:
            ans = input("يوجد مشاكل في الفحص. تطبيق رغم ذلك؟ (y/N): ")
            if ans.strip().lower() != "y":
                print("لم يُطبَّق.")
                return
        shutil.copy2(target_full, target_full + ".bak")
        with open(target_full, "w", encoding="utf-8", newline="\n") as f:
            f.write(proposed)
        print("تم التطبيق. النسخة السابقة: " + target + ".bak")
    elif diff:
        print("\nلم يُطبَّق شيء. المقترح محفوظ في: " + os.path.relpath(proposed_path, ROOT))


if __name__ == "__main__":
    main()
