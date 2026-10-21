extends SceneTree

const SOURCE_FBX := "res://assets/_fbx_audit/Great Sword Slash.fbx"
const TARGET_GLB := "res://assets/characters/المحارب السومري حامل الرمح.glb"

func _initialize() -> void:
    call_deferred("_run")

func _nodes(root: Node, type_name: String) -> Array:
    var out: Array = root.find_children("*", type_name, true, false)
    if type_name == "Skeleton3D" and root is Skeleton3D:
        out.append(root)
    elif type_name == "AnimationPlayer" and root is AnimationPlayer:
        out.append(root)
    return out

func _dump_skeleton(label: String, skel: Skeleton3D) -> void:
    print("FORENSIC_SKELETON|", label, "|name=", skel.name, "|bones=", skel.get_bone_count(), "|node_transform=", skel.transform)
    for i in range(skel.get_bone_count()):
        var parent_index := skel.get_bone_parent(i)
        var parent_name := "<none>"
        if parent_index >= 0:
            parent_name = String(skel.get_bone_name(parent_index))
        var rest := skel.get_bone_rest(i)
        var global_rest := skel.get_bone_global_rest(i)
        print("FORENSIC_BONE|", label, "|index=", i, "|name=", String(skel.get_bone_name(i)), "|parent_index=", parent_index, "|parent=", parent_name, "|rest_origin=", rest.origin, "|rest_rotation=", rest.basis.get_rotation_quaternion(), "|rest_scale=", rest.basis.get_scale(), "|global_rest_origin=", global_rest.origin, "|global_rest_rotation=", global_rest.basis.get_rotation_quaternion())

func _run() -> void:
    var source_packed := ResourceLoader.load(SOURCE_FBX) as PackedScene
    var target_packed := ResourceLoader.load(TARGET_GLB) as PackedScene
    if source_packed == null or target_packed == null:
        push_error("FORENSIC_FAIL|could_not_load_source_or_target")
        quit(1)
        return

    var source := source_packed.instantiate()
    var target := target_packed.instantiate()
    get_root().add_child(source)
    get_root().add_child(target)
    await process_frame

    print("FORENSIC_SCENE|source=", SOURCE_FBX, "|root=", source.name, "|transform=", source.transform)
    print("FORENSIC_SCENE|target=", TARGET_GLB, "|root=", target.name, "|transform=", target.transform)
    var source_skeletons := _nodes(source, "Skeleton3D")
    var source_players := _nodes(source, "AnimationPlayer")
    var target_skeletons := _nodes(target, "Skeleton3D")
    if source_skeletons.is_empty() or source_players.is_empty() or target_skeletons.is_empty():
        push_error("FORENSIC_FAIL|missing_skeleton_or_animation_player")
        quit(1)
        return

    var source_skeleton := source_skeletons[0] as Skeleton3D
    var target_skeleton := target_skeletons[0] as Skeleton3D
    _dump_skeleton("FBX_SOURCE", source_skeleton)
    _dump_skeleton("GLB_TARGET", target_skeleton)

    var source_player := source_players[0] as AnimationPlayer
    for animation_key in source_player.get_animation_list():
        var animation_name := String(animation_key)
        var animation := source_player.get_animation(animation_name)
        if animation == null:
            continue
        print("FORENSIC_ANIMATION|", animation_name, "|length=", animation.length, "|tracks=", animation.get_track_count(), "|loop_mode=", animation.loop_mode)
        for track_index in range(animation.get_track_count()):
            var track_path := String(animation.track_get_path(track_index))
            var track_type := animation.track_get_type(track_index)
            var key_count := animation.track_get_key_count(track_index)
            if track_path.contains(":mixamorig_") or track_path.contains(":Armature"):
                print("FORENSIC_TRACK|", animation_name, "|index=", track_index, "|path=", track_path, "|type=", track_type, "|keys=", key_count)

    for mesh_value in _nodes(target, "MeshInstance3D"):
        var mesh := mesh_value as MeshInstance3D
        if mesh == null or mesh.skin == null:
            continue
        var skin := mesh.skin
        print("FORENSIC_SKIN|mesh=", mesh.get_path(), "|skeleton_path=", mesh.skeleton, "|bind_count=", skin.get_bind_count())
        for bind_index in range(skin.get_bind_count()):
            print("FORENSIC_SKIN_BIND|mesh=", mesh.get_path(), "|index=", bind_index, "|bone_index=", skin.get_bind_bone(bind_index), "|bone_name=", skin.get_bind_name(bind_index), "|pose=", skin.get_bind_pose(bind_index))

    print("FORENSIC_PASS|GLB_and_FBX_inspected")
    quit(0)
