extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const Rig = preload("res://scripts/rig.gd")

const REQUIRED_BONES := [
    "upper_arm_L", "upper_arm_R",
    "forearm_L", "forearm_R",
    "thigh_L", "thigh_R",
    "lower_leg_L", "lower_leg_R",
]
const SIDE_PAIRS := [
    ["upper_arm_L", "upper_arm_R"],
    ["forearm_L", "forearm_R"],
    ["thigh_L", "thigh_R"],
    ["lower_leg_L", "lower_leg_R"],
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var root := Node3D.new()
    root.name = "RigSmokeTestRoot"
    get_root().add_child(root)

    var catalog: Dictionary = Catalog.scan()
    var characters: Array = catalog.get("characters", [])
    if characters.is_empty():
        push_error("RIG_SMOKE_FAIL: Catalog returned no playable characters.")
        quit(1)
        return

    var failures: PackedStringArray = PackedStringArray()
    var checked := 0
    print("RIG_SMOKE: checking ", characters.size(), " character models")

    for entry_value in characters:
        var entry: Dictionary = entry_value
        var path: String = String(entry.get("path", ""))
        var label: String = String(entry.get("name", path))
        var rig = Rig.new()
        rig.setup(path, root, 1.75)
        checked += 1

        if rig.model == null or rig.skeleton == null:
            failures.append(label + ": model or Skeleton3D failed to load")
        else:
            var missing: PackedStringArray = PackedStringArray()
            for bone_name in REQUIRED_BONES:
                if not rig.bone_ids.has(bone_name):
                    missing.append(bone_name)
            if not missing.is_empty():
                failures.append(label + ": missing mapped joints [" + ", ".join(missing) + "]")

            for pair in SIDE_PAIRS:
                var left_name := String(pair[0])
                var right_name := String(pair[1])
                if rig.bone_ids.has(left_name) and rig.bone_ids.has(right_name):
                    if int(rig.bone_ids[left_name]) == int(rig.bone_ids[right_name]):
                        failures.append(label + ": left/right joints share index for " + left_name + "/" + right_name)

            # Require the runtime FBX driver and every configured movement/action clip.
            if rig.retarget_modifier == null or rig.retarget_skeleton == null:
                failures.append(label + ": FBX retarget driver was not created")
            var required_motions := ["idle", "walk", "run", "slash", "chop", "thrust", "bow", "hit", "death", "block", "dodge", "dash"]
            if rig.anim_player == null:
                failures.append(label + ": no runtime AnimationPlayer")
            else:
                for motion_name in required_motions:
                    if not rig.anim_player.has_animation("motion/" + motion_name):
                        failures.append(label + ": missing runtime motion " + motion_name)

            rig.attack_style = "slash"
            rig.animate(1.0 / 60.0, false, false, -1.0)
            for frame in range(2):
                await process_frame
            rig.skeleton.force_update_all_bone_transforms()
            var clips: PackedStringArray = PackedStringArray()
            if rig.anim_player != null:
                for clip_name in rig.anim_player.get_animation_list():
                    clips.append(String(clip_name))
            var current_clip := "<none>"
            if rig.anim_player != null:
                current_clip = String(rig.anim_player.current_animation)
            print("RIG_MODEL: ", label, " | current=", current_clip, " | clips=", ",".join(clips), " | retarget=", rig.retarget_modifier != null)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/idle") and current_clip != "motion/idle":
                failures.append(label + ": idle FBX motion did not start")

            # Assert that a real walk clip changes the target GLB bones, not only the driver skeleton.
            var thigh_index := int(rig.bone_ids.get("thigh_L", -1))
            if thigh_index >= 0 and rig.anim_player != null and rig.anim_player.has_animation("motion/walk"):
                var before_walk: Transform3D = rig.skeleton.get_bone_global_pose(thigh_index)
                rig.animate(1.0 / 60.0, true, false, -1.0)
                for frame in range(10):
                    await process_frame
                rig.skeleton.force_update_all_bone_transforms()
                var after_walk: Transform3D = rig.skeleton.get_bone_global_pose(thigh_index)
                var motion_delta := before_walk.origin.distance_to(after_walk.origin)
                motion_delta += before_walk.basis.get_rotation_quaternion().angle_to(after_walk.basis.get_rotation_quaternion())
                if motion_delta < 0.005:
                    failures.append(label + ": retargeted walk clip did not move the GLB skeleton")

            # Smoke-test transitions to run, attacks, hit reaction, and death.
            rig.animate(1.0 / 60.0, true, true, -1.0)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/run") and rig.anim_player.current_animation != "motion/run":
                failures.append(label + ": run FBX motion did not start")
            for style in ["slash", "chop", "thrust", "bow"]:
                rig.attack_style = style
                rig.animate(1.0 / 60.0, false, false, 0.35, style == "bow")
                if rig.anim_player != null and rig.anim_player.has_animation("motion/" + style) and rig.anim_player.current_animation != "motion/" + style:
                    failures.append(label + ": attack FBX motion did not start for " + style)
            rig.hit_flash()
            rig.animate(1.0 / 60.0, false, false, -1.0)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/hit") and rig.anim_player.current_animation != "motion/hit":
                failures.append(label + ": hit reaction FBX motion did not start")
            rig.die()
            rig.animate(1.0 / 60.0, false, false, -1.0)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/death") and rig.anim_player.current_animation != "motion/death":
                failures.append(label + ": death FBX motion did not start")

            rig.dead_time = -1.0
            rig.hit_t = 0.0
            rig.attack_style = "slash"
            rig.animate(1.0 / 60.0, false, false, -1.0, false, true)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/block") and rig.anim_player.current_animation != "motion/block":
                failures.append(label + ": block FBX motion did not start")
            rig.animate(1.0 / 60.0, false, false, -1.0, false, false, true)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/dodge") and rig.anim_player.current_animation != "motion/dodge":
                failures.append(label + ": dodge FBX motion did not start")
            rig.animate(1.0 / 60.0, false, false, -1.0, false, false, false, true)
            if rig.anim_player != null and rig.anim_player.has_animation("motion/dash") and rig.anim_player.current_animation != "motion/dash":
                failures.append(label + ": dash FBX motion did not start")

        if rig.pivot != null and is_instance_valid(rig.pivot):
            rig.pivot.queue_free()
        await process_frame

    if failures.is_empty():
        print("RIG_SMOKE_PASS: ", checked, " character rigs loaded, core joints mapped, left/right indices distinct, and animation states exercised.")
        quit(0)
        return

    for failure in failures:
        push_error("RIG_SMOKE_FAIL: " + String(failure))
    push_error("RIG_SMOKE_FAIL: " + str(failures.size()) + " failure(s) across " + str(checked) + " character model(s).")
    quit(1)
