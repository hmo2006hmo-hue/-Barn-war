extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const DETAIL_FILES := [
    "Great Sword Attack.fbx",
    "Great Sword Slash.fbx",
    "Great Sword Slash (1).fbx",
    "great sword idle.fbx",
    "great sword walk.fbx",
    "great sword run (2).fbx",
    "great sword slash (3).fbx",
    "sword and shield idle.fbx",
    "sword and shield walk.fbx",
    "ssword and shield run.fbx",
    "sword and shield attack (3).fbx",
    "sword and shield death.fbx"
]

func _initialize() -> void:
    call_deferred("_run")

func _nodes_of_type(root: Node, type_name: String) -> Array:
    var result: Array = root.find_children("*", type_name, true, false)
    if type_name == "Skeleton3D" and root is Skeleton3D:
        result.append(root)
    elif type_name == "AnimationPlayer" and root is AnimationPlayer:
        result.append(root)
    return result

func _run() -> void:
    var root := Node3D.new()
    root.name = "AnimationAssetAudit"
    get_root().add_child(root)
    await process_frame

    var catalog: Dictionary = Catalog.scan()
    var characters: Array = catalog.get("characters", [])
    print("ANIMATION_AUDIT_TARGETS: ", characters.size(), " playable GLB models")
    for value in characters:
        var entry: Dictionary = value
        var path := String(entry.get("path", ""))
        var label := String(entry.get("name", path))
        var packed := ResourceLoader.load(path) as PackedScene
        if packed == null:
            print("ANIMATION_AUDIT_TARGET_FAIL: ", label, " | cannot load ", path)
            continue
        var instance := packed.instantiate()
        root.add_child(instance)
        await process_frame
        var skeletons := _nodes_of_type(instance, "Skeleton3D")
        var players := _nodes_of_type(instance, "AnimationPlayer")
        var bone_names: PackedStringArray = PackedStringArray()
        var bone_count := 0
        if not skeletons.is_empty():
            var skel := skeletons[0] as Skeleton3D
            bone_count = skel.get_bone_count()
            for i in range(bone_count):
                bone_names.append(String(skel.get_bone_name(i)))
        var clip_names: PackedStringArray = PackedStringArray()
        var clip_count := 0
        for player_value in players:
            var ap := player_value as AnimationPlayer
            for clip_value in ap.get_animation_list():
                var clip_name := String(clip_value)
                if clip_name == "RESET":
                    continue
                clip_count += 1
                clip_names.append(clip_name)
        print("ANIMATION_AUDIT_TARGET: ", label, " | bones=", bone_count, " | anim_players=", players.size(), " | clips=", clip_count, " | bone_names=", ",".join(bone_names), " | clip_names=", ",".join(clip_names))
        instance.queue_free()
        await process_frame

    var dir := DirAccess.open("res://assets/_fbx_audit")
    if dir == null:
        push_error("ANIMATION_AUDIT_FAIL: staging folder res://assets/_fbx_audit does not exist")
        quit(1)
        return

    dir.list_dir_begin()
    var filenames: PackedStringArray = PackedStringArray()
    var filename := dir.get_next()
    while filename != "":
        if not dir.current_is_dir() and filename.to_lower().ends_with(".fbx"):
            filenames.append(filename)
        filename = dir.get_next()
    dir.list_dir_end()
    filenames.sort()

    var loaded := 0
    var failed := PackedStringArray()
    var scenes_with_skeleton := 0
    var scenes_with_player := 0
    var animation_count := 0
    var total_tracks := 0
    var bone_histogram: Dictionary = {}
    print("ANIMATION_AUDIT_SOURCE_COUNT: ", filenames.size(), " FBX files staged")
    for name in filenames:
        var path := "res://assets/_fbx_audit/" + name
        var packed := ResourceLoader.load(path) as PackedScene
        if packed == null:
            failed.append(name)
            print("ANIMATION_AUDIT_SOURCE_FAIL: ", name, " | PackedScene load returned null")
            continue

        var instance := packed.instantiate()
        root.add_child(instance)
        await process_frame
        loaded += 1
        var skeletons := _nodes_of_type(instance, "Skeleton3D")
        var players := _nodes_of_type(instance, "AnimationPlayer")
        if not skeletons.is_empty():
            scenes_with_skeleton += 1
        if not players.is_empty():
            scenes_with_player += 1
        var skeleton_summary := "none"
        var bone_names: PackedStringArray = PackedStringArray()
        if not skeletons.is_empty():
            var skel := skeletons[0] as Skeleton3D
            var count := skel.get_bone_count()
            bone_histogram[count] = int(bone_histogram.get(count, 0)) + 1
            skeleton_summary = String(skel.name) + ":" + str(count)
            for i in range(count):
                bone_names.append(String(skel.get_bone_name(i)))

        var clip_summary: PackedStringArray = PackedStringArray()
        var track_paths: PackedStringArray = PackedStringArray()
        var source_clip_count := 0
        for player_value in players:
            var ap := player_value as AnimationPlayer
            for clip_value in ap.get_animation_list():
                var clip_name := String(clip_value)
                if clip_name == "RESET":
                    continue
                var anim := ap.get_animation(clip_name)
                if anim == null:
                    continue
                source_clip_count += 1
                animation_count += 1
                total_tracks += anim.get_track_count()
                clip_summary.append(clip_name + ":" + str(snappedf(anim.length, 0.01)) + "s/" + str(anim.get_track_count()) + "t")
                if DETAIL_FILES.has(name) and track_paths.size() < 8:
                    for track_index in range(anim.get_track_count()):
                        var track_path := String(anim.track_get_path(track_index))
                        if not track_paths.has(track_path):
                            track_paths.append(track_path)
                        if track_paths.size() >= 8:
                            break
        print("ANIMATION_AUDIT_SOURCE: ", name, " | load=ok | skeletons=", skeletons.size(), " | source_rig=", skeleton_summary, " | players=", players.size(), " | clips=", source_clip_count, " | clip_data=", ",".join(clip_summary), " | tracks_sample=", ",".join(track_paths))
        if DETAIL_FILES.has(name) and not bone_names.is_empty():
            print("ANIMATION_AUDIT_SOURCE_BONES: ", name, " | ", ",".join(bone_names))
        instance.queue_free()
        await process_frame

    print("ANIMATION_AUDIT_SUMMARY: total=", filenames.size(), " | loaded=", loaded, " | failed=", failed.size(), " | scenes_with_skeleton=", scenes_with_skeleton, " | scenes_with_animation_player=", scenes_with_player, " | clips=", animation_count, " | total_tracks=", total_tracks, " | bone_count_histogram=", str(bone_histogram))
    if not failed.is_empty():
        print("ANIMATION_AUDIT_FAILED_FILES: ", ",".join(failed))
    if loaded == 0:
        push_error("ANIMATION_AUDIT_FAIL: no FBX source files could be imported")
        quit(1)
        return
    print("ANIMATION_AUDIT_PASS: FBX contents enumerated and character skeletons inspected.")
    quit(0)
