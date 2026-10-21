# مصادر أنيميشن أوران

يحمّل `scripts/rig.gd` ملفات FBX الموجودة في هذا المجلد بأسمائها الحرفية. عند تغيير اسم ملف، يجب تحديث `MOTION_SOURCES` في السكربت.

| الحالة | ملف FBX |
|---|---|
| وقوف | `great sword idle.fbx` |
| مشي | `great sword walk.fbx` |
| ركض | `Great Sword Run.fbx` |
| هجوم مائل | `Great Sword Slash.fbx` |
| ضربة قوية | `Great Sword Attack.fbx` |
| طعن | `Sword And Shield Attack.fbx` |
| حركة بديلة للهجوم بعيد المدى | `spell cast.fbx` |
| تلقي ضربة | `great sword impact.fbx` |
| موت | `two handed sword death.fbx` |
| صدّ | `sword and shield block.fbx` |
| تفادٍ | `Great Sword Slide Attack.fbx` |
| اندفاع | `Standing Run Forward.fbx` |

## إعادة الاستهداف

ملفات Mixamo المصدرية تحتوي على 65 عظمة. نموذج أوران `assets/characters/اوران .glb` يحتوي على 23 عظمة، بينها عظمة `Root`. يربط `scripts/explicit_retarget_modifier.gd` العظام المشتركة الـ22 ويُبقي أطوال عظام نموذج أوران كما هي.

## التحكم

- **الحاسوب:** WASD أو الأسهم للحركة، Space للهجوم، Shift للركض، G لتبديل الصدّ، C للتفادي، X للاندفاع، وF لاستخدام الشظية.
- **الهاتف:** أزرار منفصلة للهجوم والركض والصدّ والتفادي والاندفاع، ويظهر زر الشظية عند فتح القدرة.

## الاختبارات

بعد استيراد المشروع في Godot 4.7.2، يفحص CI ملفات GLB وFBX، ويتأكد من ربط الهيكل والعظام، وانتقالات الأنيميشنات، والتحكم والصدّ والتفادي والاندفاع.
