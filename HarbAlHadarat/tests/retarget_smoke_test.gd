extends SceneTree

const ExplicitRetargetModifier = preload("res://scripts/explicit_retarget_modifier.gd")
const SOURCE_FBX := "res://assets/_fbx_audit/Great Sword Slash.fbx"
const TARGET_GLB := "res://assets/characters/المحارب السومري حامل الرمح.glb"
const ANGLE_TOLERANCE := 0.035
const POSITION_TOLERANCE := 0.0001

func _initialize() -> void:
    call_deferred("_run")

func _nodes(root: Node, type_name: String) -> Array:
    var out: Array = root.find_children("*", type_name, true, false)
    if type_name == "Skeleton3D" and root is Skeleton3D:
        out.push_front(root)
    elif type_name == "AnimationPlayer" and root is AnimationPlayer:
        out.push_front(root)
    return out

func _fail(message: String) -> void:
    push_error("RETARGET_SMOKE_FAIL: " + message)
    quit(1)

func _expected_local_rotations(source: Skeleton3D, target: Skeleton3D) -> Dictionary:
    var expected_global: Dictionary = {0: target.get_bone_global_rest(0).basis.orthonormalized()}
    var expected_local: Dictionary = {}
    for row in ExplicitRetargetModifier.BONE_LINKS:
        var source_index := int(row[2])
        var target_index := int(row[3])
        var target_parent_index := int(row[4])
        var source_pose_global: Transform3D = source.get_bone_global_pose(source_index)
        var source_rest_global: Transform3D = source.get_bone_global_rest(source_index)
        var target_rest_global: Transform3D = target.get_bone_global_rest(target_index)
        var source_delta: Basis = source_pose_global.basis.orthonormalized() * source_rest_global.basis.orthonormalized().inverse()
        var desired_global: Basis = (source_delta * target_rest_global.basis.orthonormalized()).orthonormalized()
        var parent_global: Basis = expected_global.get(target_parent_index, target.get_bone_global_rest(target_parent_index).basis.orthonormalized())
        var desired_local: Basis = (parent_global.inverse() * desired_global).orthonormalized()
        expected_local[target_index] = desired_local.get_rotation_quaternion()
        expected_global[target_index] = desired_global
    return expected_local

func _run() -> void:
    var source_packed := ResourceLoader.load(SOURCE_FBX) as PackedScene
    var target_packed := ResourceLoader.load(TARGET_GLB) as PackedScene
    if source_packed == null or target_packed == null:
        _fail("could not load the inspected FBX and GLB files")
        return

    var source := source_packed.instantiate()
    get_root().add_child(source)
    await process_frame

    var source_skeletons := _nodes(source, "Skeleton3D")
    var source_players := _nodes(source, "AnimationPlayer")
    if source_skeletons.is_empty() or source_players.is_empty():
        _fail("FBX source is missing its skeleton or animation player")
        return
    var source_skeleton := source_skeletons[0] as Skeleton3D
    var source_player := source_players[0] as AnimationPlayer

    var target := target_packed.instantiate()
    source_skeleton.add_child(target)
    await process_frame
    var target_skeletons := _nodes(target, "Skeleton3D")
    if target_skeletons.is_empty():
        _fail("GLB target has no skeleton")
        return
    var target_skeleton := target_skeletons[0] as Skeleton3D

    var modifier = ExplicitRetargetModifier.new()
    if not modifier.configure(source_skeleton, target_skeleton):
        _fail("explicit mapping failed asset name/index/parent validation")
        return
    source_skeleton.add_child(modifier)
    target_skeleton.reparent(modifier, true)
    for mesh_value in _nodes(target, "MeshInstance3D"):
        var mesh := mesh_value as MeshInstance3D
        if mesh != null and mesh.skin != null:
            mesh.skeleton = mesh.get_path_to(target_skeleton)

    await process_frame
    source_skeleton.force_update_all_bone_transforms()
    target_skeleton.force_update_all_bone_transforms()

    # At rest, the explicit conversion must preserve every GLB rest rotation
    # and leave every GLB bone offset untouched.
    var rest_rotation_error := 0.0
    var rest_position_error := 0.0
    for row in ExplicitRetargetModifier.BONE_LINKS:
        var source_index := int(row[2])
        var target_index := int(row[3])
        var target_rest_q := target_skeleton.get_bone_rest(target_index).basis.get_rotation_quaternion()
        rest_rotation_error = maxf(rest_rotation_error, target_skeleton.get_bone_pose_rotation(target_index).angle_to(target_rest_q))
        rest_position_error = maxf(rest_position_error, target_skeleton.get_bone_pose_position(target_index).distance_to(target_skeleton.get_bone_rest(target_index).origin))

    if source_player.has_animation("mixamo_com"):
        source_player.play("mixamo_com")
    else:
        _fail("driver FBX lacks exact mixamo_com clip")
        return

    for frame in range(24):
        await process_frame
        source_skeleton.force_update_all_bone_transforms()
        target_skeleton.force_update_all_bone_transforms()

    var expected_rotations := _expected_local_rotations(source_skeleton, target_skeleton)
    var max_rotation_error := 0.0
    var max_position_error := 0.0
    for row in ExplicitRetargetModifier.BONE_LINKS:
        var target_index := int(row[3])
        var expected_q: Quaternion = expected_rotations[target_index]
        var actual_q := target_skeleton.get_bone_pose_rotation(target_index)
        max_rotation_error = maxf(max_rotation_error, actual_q.angle_to(expected_q))
        max_position_error = maxf(max_position_error, target_skeleton.get_bone_pose_position(target_index).distance_to(target_skeleton.get_bone_rest(target_index).origin))

    var spine1_index := 2
    var spine1_delta := source_skeleton.get_bone_global_pose(spine1_index).basis.get_rotation_quaternion().angle_to(
        source_skeleton.get_bone_global_rest(spine1_index).basis.get_rotation_quaternion()
    )
    var chest_index := 3
    var chest_delta := target_skeleton.get_bone_pose_rotation(chest_index).angle_to(
        target_skeleton.get_bone_rest(chest_index).basis.get_rotation_quaternion()
    )

    print("RETARGET_EXPLICIT_TEST: links=", ExplicitRetargetModifier.BONE_LINKS.size(),
        " | source_bones=", source_skeleton.get_bone_count(),
        " | target_bones=", target_skeleton.get_bone_count(),
        " | rest_rotation_error=", rest_rotation_error,
        " | rest_position_error=", rest_position_error,
        " | max_runtime_rotation_error=", max_rotation_error,
        " | max_runtime_position_error=", max_position_error,
        " | spine1_motion_radians=", spine1_delta,
        " | chest_motion_radians=", chest_delta)

    if rest_rotation_error > ANGLE_TOLERANCE:
        _fail("retarget modifier does not preserve GLB rest rotations")
        return
    if rest_position_error > POSITION_TOLERANCE or max_position_error > POSITION_TOLERANCE:
        _fail("target GLB bone positions changed; body proportions must remain target-local")
        return
    if max_rotation_error > ANGLE_TOLERANCE:
        _fail("actual target local rotations diverge from explicit rest-relative global mapping")
        return
    if spine1_delta < 0.01:
        _fail("chosen test time did not exercise the unmapped source Spine1 bone")
        return
    if chest_delta < 0.01:
        _fail("source animation did not transfer a rotation to target chest")
        return

    print("RETARGET_EXPLICIT_PASS: exact bone indices and parent hierarchies validated; unmapped Spine1 motion contributes without stretching GLB bones.")
    quit(0)
