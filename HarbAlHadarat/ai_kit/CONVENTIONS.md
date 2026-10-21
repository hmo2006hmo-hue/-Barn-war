# Project: حرب الحضارات (Godot 4.7, GDScript, GL Compatibility renderer, Android + PC)

## Files (scripts/)
- main.gd      : main menu (Control). Builds UI in code.
- game.gd      : gameplay scene (Node3D). World, player, enemies (class Actor), combat, HUD, dialogue, story steps.
- rig.gd       : procedural animation for GLB characters (shared 40-bone skeleton).
- catalog.gd   : scans assets/, classifies characters vs buildings, enemy stats by type tag.
- story.gd     : story text + positions (const only).
- session.gd   : static shared state + save file user://harb_save.json.
- ui_kit.gd    : colors, theme (Arabic system font), button/label/bar helpers.

## Style rules
- Typed GDScript 4. 4 spaces. No class_name; use `const X = preload("res://scripts/x.gd")`.
- Scripts reference each other only through preload constants: Rig, Catalog, Session, UI, Story.
- Arabic UI text, UI roots use LAYOUT_DIRECTION_LTR.
- Character models face +Z. Rotation: `node.rotation.y = atan2(dir.x, dir.z)`.
- Collision layers: 1 world, 2 player, 4 enemies/NPC (bit values).
- Touch input handled manually in game.gd `_input` (HUD pads are Panels with mouse_filter IGNORE registered in `pads`).

## Key APIs
Rig (instance): setup(path, parent_node3d, height), animate(delta, moving, running, attack_p, ranged=false), hit_flash(), tint(color), die(); static get_bounds(node3d).
Catalog (static): scan() -> {"characters": Array[Dictionary], "buildings": Array[Dictionary]},
  pick(characters, tag, salt, exclude_path) -> Dictionary, find_building(buildings, key), find_by_kingdom(characters, kingdom).
  Character dict keys: path, name, kingdom, role, tag (archer|heavy|shield|spear|infantry), hp, speed, damage, reach, cooldown.
Session (static vars): mode ("story"|"free"), char_index, story_checkpoint, shadows, sensitivity; load_data(), save_data().
UI (static): make_theme(), box(color, radius, border, border_w, margin), label(text,size,color), button(text,w,h,primary,font_size), bar(w,h,color), outline(label,width), full_rect(control).

## game.gd structure
- enum State {PLAYING, DIALOGUE, CARD, PAUSED, GAME_OVER}; enum Step {PROLOGUE, GO_MARKET, TRAINING, RETURN_GUARD, WAVE1, WAVE2, SHARD, SHARD_TRIAL, MASKED, END}
- class Actor fields: node, yaw_node, rig, kind (melee|ranged|dummy|ally|npc|masked), hp, speed, damage, reach, cooldown_max, cooldown, attack_t, attack_done, dead, dead_t, knock, yaw, swerve, moving.
- Main functions: _spawn_actor, _ai_enemy, _ai_ally, _player_attack, _apply_player_hit, _damage_actor, _damage_player, _use_shard, _update_player, _update_camera, _spawn_wave, _set_step, _story_update, _start_dialogue, _show_card.
- To add a story step: add to enum Step, add a branch in `_set_step`, add logic in `_story_update`, add text constants in story.gd.
- To add an enemy type: edit `_fighter_stats` in catalog.gd (tag + stats) and use the tag in `_spawn_wave([...])`.
