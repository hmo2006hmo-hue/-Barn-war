extends RefCounted

# Runtime FBX retargeting for the shared 65-bone Mixamo sources and 40-bone GLB characters.
# Procedural poses remain as a safe fallback if a configured source cannot load.

var pivot: Node3D
var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var retarget_skeleton: Skeleton3D
var retarget_modifier: SkeletonModifier3D
var source_scene: Node3D
var active_motion: String = ""
var active_motion_speed: float = 1.0
static var shared_motion_library: AnimationLibrary
static var reported_skeleton_warnings: Dictionary = {}
var bone_ids: Dictionary = {}       # canonical name -> bone index
var rest_rot: Dictionary = {}       # bone index -> rest local rotation
var arm_drop: Dictionary = {}
var arm_flex_axis: Dictionary = {}   # skeleton-space axes perpendicular to each arm segment
var materials: Array = []
var height: float = 1.75

var time: float = 0.0
var walk_phase: float = 0.0
var move_blend: float = 0.0
var speed_smooth: float = 0.0
var flash: float = 0.0
var last_flash: float = -1.0
var dead_time: float = -1.0
var hit_t: float = 0.0
var move_speed: float = -1.0
var attack_style: String = "slash"

const HIT_TIME := 0.35
const ATTACK_WINDOW := 0.76
const ANIMATION_FOLDER := "res://assets/animations"
const ExplicitRetargetModifier = preload("res://scripts/explicit_retarget_modifier.gd")
const RETARGET_MAP := ExplicitRetargetModifier.BONE_LINKS
const MOTION_SOURCES := {
	"idle": "great sword idle.fbx",
	"walk": "great sword walk.fbx",
	"run": "Great Sword Run.fbx",
	"slash": "Great Sword Slash.fbx",
	"chop": "Great Sword Attack.fbx",
	"thrust": "Sword And Shield Attack.fbx",
	"bow": "spell cast.fbx",
	"hit": "great sword impact.fbx",
	"death": "two handed sword death.fbx",
	"block": "sword and shield block.fbx",
	"dodge": "Great Sword Slide Attack.fbx",
	"dash": "Standing Run Forward.fbx",
}

# Common aliases after normalization (lowercase, no separators or rig prefixes).
const BONE_ALIASES := {
	"pelvis": ["pelvis", "hips", "hip", "rootpelvis", "bip001pelvis"],
	"spine": ["spine", "spine1", "spine01", "spine_01", "torso", "mixamorigrspine"],
	"chest": ["chest", "spine2", "spine02", "spine_02", "spine3", "spine03", "upperchest", "thorax"],
	"neck": ["neck", "neck1"],
	"head": ["head", "headend"],
	"upper_arm_L": ["upperarml", "upperarmleft", "leftupperarm", "leftarm", "armleft", "arml", "uparml", "armupperl", "lupperarm", "bip001lupperarm"],
	"upper_arm_R": ["upperarmr", "upperarmright", "rightupperarm", "rightarm", "armright", "armr", "uparmr", "armupperr", "rupperarm", "bip001rupperarm"],
	"forearm_L": ["forearml", "forearmleft", "leftforearm", "leftlowerarm", "lowerarmleft", "lowerarml", "forearmlower", "lforearm", "bip001lforearm"],
	"forearm_R": ["forearmr", "forearmright", "rightforearm", "rightlowerarm", "lowerarmright", "lowerarmr", "forearmlower", "rforearm", "bip001rforearm"],
	"hand_L": ["handl", "lefthand", "handleft", "bip001lhand"],
	"hand_R": ["handr", "righthand", "handright", "bip001rhand"],
	"thigh_L": ["thighl", "thighleft", "leftthigh", "leftupleg", "uplegl", "upperlegl", "upperlegleft", "leftupperleg", "lthigh", "lupperleg", "bip001lthigh"],
	"thigh_R": ["thighr", "thighright", "rightthigh", "rightupleg", "uplegr", "upperlegr", "upperlegright", "rightupperleg", "rthigh", "rupperleg", "bip001rthigh"],
	"lower_leg_L": ["lowerlegl", "lowerlegleft", "leftleg", "leftlowerleg", "calfl", "calfleft", "shinl", "shinleft", "legl", "llowerleg", "bip001lcalf"],
	"lower_leg_R": ["lowerlegr", "lowerlegright", "rightleg", "rightlowerleg", "calfr", "calfright", "shinr", "shinright", "legr", "rlowerleg", "bip001rcalf"],
	"foot_L": ["footl", "leftfoot", "lfoot", "bip001lfoot"],
	"foot_R": ["footr", "rightfoot", "rfoot", "bip001rfoot"],
}

const ATTACK_KEYS := {
	"slash": [
		[0.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.22, -1.65, -0.65, -0.12, -0.04, -0.70, 0.25],
		[0.48, -0.25, 0.95, 0.22, 0.24, 0.60, -0.48],
		[0.70, -0.55, 0.35, 0.12, 0.12, 0.25, -0.25],
		[1.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	],
	"chop": [
		[0.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.24, -2.45, -0.10, -0.28, 0.0, 0.0, 0.20],
		[0.48, -0.50, 0.02, 0.45, 0.30, 0.0, -0.55],
		[0.70, -0.45, 0.0, 0.22, 0.16, 0.0, -0.32],
		[1.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	],
	"thrust": [
		[0.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.25, -0.95, -0.45, -0.16, -0.08, -0.22, 0.32],
		[0.50, -1.20, 0.52, 0.24, 0.45, 0.18, -0.62],
		[0.72, -0.92, 0.28, 0.12, 0.20, 0.08, -0.35],
		[1.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	],
	"bow": [
		[0.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.25, -1.05, 0.25, -0.06, 0.0, 0.0, 0.06],
		[0.58, -1.42, 0.38, -0.08, 0.0, 0.0, 0.06],
		[0.72, -1.35, 0.20, -0.02, 0.0, 0.0, 0.02],
		[1.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	],
}


func setup(path: String, parent: Node3D, target_height: float) -> void:
	height = target_height
	time = randf() * 10.0
	pivot = Node3D.new()
	pivot.name = "CharacterMotionPivot"
	parent.add_child(pivot)

	var packed: PackedScene = null
	if not path.is_empty():
		packed = ResourceLoader.load(path) as PackedScene
	if packed != null:
		model = packed.instantiate() as Node3D

	if model == null:
		model = _make_placeholder()
	pivot.add_child(model)
	_find_skeleton()
	_fit_to_ground()
	_prepare_materials()
	_reset_pose()
	_setup_animation_driver()
	animate(0.0, false, false, -1.0)


func _find_descendants(root: Node, type_name: String) -> Array:
	var result: Array = root.find_children("*", type_name, true, false)
	if type_name == "Skeleton3D" and root is Skeleton3D:
		result.push_front(root)
	elif type_name == "AnimationPlayer" and root is AnimationPlayer:
		result.push_front(root)
	return result


func _load_shared_motion_library() -> AnimationLibrary:
	if shared_motion_library != null:
		return shared_motion_library
	var library := AnimationLibrary.new()
	for motion_value in MOTION_SOURCES.keys():
		var motion_name := String(motion_value)
		var file_name := String(MOTION_SOURCES[motion_name])
		var packed := ResourceLoader.load(ANIMATION_FOLDER + "/" + file_name) as PackedScene
		if packed == null:
			push_warning("Character rig: missing FBX animation source " + file_name)
			return null
		var source_instance := packed.instantiate()
		var source_players := _find_descendants(source_instance, "AnimationPlayer")
		if source_players.is_empty():
			source_instance.free()
			push_warning("Character rig: FBX has no AnimationPlayer: " + file_name)
			return null
		var source_player := source_players[0] as AnimationPlayer
		var clip_name := "mixamo_com" if source_player.has_animation("mixamo_com") else ""
		if clip_name.is_empty():
			for candidate in source_player.get_animation_list():
				var candidate_name := String(candidate)
				if candidate_name == "RESET" or candidate_name.to_lower() == "take 001":
					continue
				clip_name = candidate_name
				break
		if clip_name.is_empty():
			source_instance.free()
			push_warning("Character rig: FBX has no usable motion clip: " + file_name)
			return null
		var animation := source_player.get_animation(clip_name).duplicate(true) as Animation
		source_instance.free()
		if animation == null:
			push_warning("Character rig: could not duplicate animation from " + file_name)
			return null

		# Preserve the exact Mixamo track paths because the FBX driver keeps
		# its original bone names. The gameplay controller owns root movement.
		for track_index in range(animation.get_track_count() - 1, -1, -1):
			var track_path := String(animation.track_get_path(track_index))
			if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D and track_path.ends_with(":mixamorig_Hips"):
				animation.remove_track(track_index)
		animation.loop_mode = Animation.LOOP_LINEAR if ["idle", "walk", "run", "block"].has(motion_name) else Animation.LOOP_NONE
		var add_error: Error = library.add_animation(motion_name, animation)
		if add_error != OK:
			push_warning("Character rig: could not register animation " + motion_name + " from " + file_name)
			return null
	shared_motion_library = library
	return shared_motion_library


func _setup_animation_driver() -> bool:
	if model == null or skeleton == null:
		return false
	var library := _load_shared_motion_library()
	if library == null:
		return false

	var packed := ResourceLoader.load(ANIMATION_FOLDER + "/Great Sword Slash.fbx") as PackedScene
	if packed == null:
		push_warning("Character rig: could not load the explicit FBX driver.")
		return false
	source_scene = packed.instantiate() as Node3D
	if source_scene == null:
		return false

	pivot.add_child(source_scene)
	var source_skeletons := _find_descendants(source_scene, "Skeleton3D")
	var source_players := _find_descendants(source_scene, "AnimationPlayer")
	if source_skeletons.is_empty() or source_players.is_empty():
		source_scene.queue_free()
		source_scene = null
		push_warning("Character rig: explicit FBX driver lacks Skeleton3D or AnimationPlayer.")
		return false

	retarget_skeleton = source_skeletons[0] as Skeleton3D
	var driver_player := source_players[0] as AnimationPlayer

	# Validate fixed FBX/GLB bone indices and both parent chains. Do not search for
	# similarly named bones and do not rename the source rig at runtime.
	var explicit_map := ExplicitRetargetModifier.BONE_LINKS
	if retarget_skeleton.get_bone_count() != 65:
		push_warning("Character rig: unexpected FBX skeleton size; expected 65 bones, got " + str(retarget_skeleton.get_bone_count()))
		source_scene.queue_free()
		source_scene = null
		return false
	if skeleton.get_bone_count() != 40:
		push_warning("Character rig: unexpected GLB skeleton size; expected 40 bones, got " + str(skeleton.get_bone_count()))
		source_scene.queue_free()
		source_scene = null
		return false

	for row in explicit_map:
		var target_name := String(row[0])
		var source_name := String(row[1])
		var source_index := int(row[2])
		var target_index := int(row[3])
		var target_parent_index := int(row[4])
		var source_parent_index := int(row[5])

		if String(retarget_skeleton.get_bone_name(source_index)) != source_name:
			push_warning("Character rig: FBX index " + str(source_index) + " expected " + source_name + ".")
			source_scene.queue_free()
			source_scene = null
			return false
		if retarget_skeleton.get_bone_parent(source_index) != source_parent_index:
			push_warning("Character rig: FBX hierarchy mismatch for " + source_name + ".")
			source_scene.queue_free()
			source_scene = null
			return false
		if String(skeleton.get_bone_name(target_index)) != target_name:
			push_warning("Character rig: GLB index " + str(target_index) + " expected " + target_name + ".")
			source_scene.queue_free()
			source_scene = null
			return false
		if skeleton.get_bone_parent(target_index) != target_parent_index:
			push_warning("Character rig: GLB hierarchy mismatch for " + target_name + ".")
			source_scene.queue_free()
			source_scene = null
			return false

	var player_library := library.duplicate(false) as AnimationLibrary
	var library_error: Error = driver_player.add_animation_library("motion", player_library)
	if library_error != OK:
		source_scene.queue_free()
		source_scene = null
		push_warning("Character rig: could not attach shared motion library.")
		return false
	driver_player.stop()

	# The source FBX mesh is only a skeleton/animation driver; do not render it.
	for mesh_value in source_scene.find_children("*", "MeshInstance3D", true, false):
		(mesh_value as Node).free()

	# Apply an explicit retarget operation. It transfers rest-relative GLOBAL
	# rotations so unmapped FBX Spine1 still contributes to target chest motion,
	# then converts to target-local rotations without changing GLB bone lengths.
	var explicit_modifier = ExplicitRetargetModifier.new()
	if not explicit_modifier.configure(retarget_skeleton, skeleton):
		source_scene.queue_free()
		source_scene = null
		push_warning("Character rig: explicit FBX-to-GLB bone validation failed.")
		return false

	retarget_modifier = explicit_modifier as SkeletonModifier3D
	retarget_skeleton.add_child(retarget_modifier)

	# Keep the fitted GLB transform intact while moving its skeleton under the
	# source skeleton's modifier pipeline.
	var fitted_model_transform := model.global_transform
	model.reparent(retarget_skeleton, true)
	if not model.global_transform.is_equal_approx(fitted_model_transform):
		push_warning("Character rig: GLB transform changed while attaching explicit animation driver.")

	skeleton.reparent(retarget_modifier, true)
	for mesh_value in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance != null and mesh_instance.skin != null:
			mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)

	anim_player = driver_player
	active_motion = ""
	return true


static func get_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var visual_nodes: Array = root.find_children("*", "VisualInstance3D", true, false)
	if root is VisualInstance3D:
		visual_nodes.append(root)
	for node in visual_nodes:
		var visual := node as VisualInstance3D
		if visual == null:
			continue
		var box: AABB = visual.get_aabb()
		var corners: Array = [
			box.position,
			Vector3(box.end.x, box.position.y, box.position.z),
			Vector3(box.position.x, box.end.y, box.position.z),
			Vector3(box.position.x, box.position.y, box.end.z),
			Vector3(box.end.x, box.end.y, box.position.z),
			Vector3(box.end.x, box.position.y, box.end.z),
			Vector3(box.position.x, box.end.y, box.end.z),
			box.end,
		]
		for corner in corners:
			var point: Vector3 = root.to_local(visual.to_global(corner))
			if not found:
				result = AABB(point, Vector3.ZERO)
				found = true
			else:
				result = result.expand(point)
	return result


func _normalize_bone_name(raw_name: String) -> String:
	var n := raw_name.to_lower()
	n = n.replace("mixamorig", "").replace("armature", "")
	n = n.replace("skeleton", "").replace("bone", "")
	n = n.replace("_", "").replace("-", "").replace(".", "")
	n = n.replace(":", "").replace(" ", "")
	return n


func _find_skeleton() -> void:
	skeleton = null
	anim_player = null
	var skeletons: Array = model.find_children("*", "Skeleton3D", true, false)
	if model is Skeleton3D:
		skeletons.append(model)
	if not skeletons.is_empty():
		skeleton = skeletons[0] as Skeleton3D
	var players: Array = model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim_player = players[0] as AnimationPlayer
	if skeleton == null:
		push_warning("Character rig: no Skeleton3D found for model: " + model.name)
		return

	# Some GLB imports place the skinned mesh and its armature in separate
	# branches. Explicitly point every skinned MeshInstance3D at this skeleton.
	var mesh_nodes: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		mesh_nodes.append(model)
	for mesh_node in mesh_nodes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if mesh_instance.skin != null:
			mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)

	bone_ids.clear()
	rest_rot.clear()
	for i in range(skeleton.get_bone_count()):
		var actual_name := String(skeleton.get_bone_name(i))
		var normalized := _normalize_bone_name(actual_name)
		rest_rot[i] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		for canonical in BONE_ALIASES:
			if bone_ids.has(canonical):
				continue
			for alias in BONE_ALIASES[canonical]:
				if normalized == _normalize_bone_name(String(alias)):
					bone_ids[canonical] = i
					break
	_map_bone_fallback("upper_arm_L", ["upperarm", "leftarm", "arml"], ["right"])
	_map_bone_fallback("upper_arm_R", ["upperarm", "rightarm", "armr"], ["left"])
	_map_bone_fallback("forearm_L", ["forearm", "lowerarm", "elbow"], ["right", "hand", "wrist"])
	_map_bone_fallback("forearm_R", ["forearm", "lowerarm", "elbow"], ["left", "hand", "wrist"])
	_map_bone_fallback("thigh_L", ["thigh", "upperleg", "upleg"], ["right", "lower", "calf", "foot"])
	_map_bone_fallback("thigh_R", ["thigh", "upperleg", "upleg"], ["left", "lower", "calf", "foot"])
	_map_bone_fallback("lower_leg_L", ["lowerleg", "calf", "shin"], ["right", "upper", "thigh", "foot", "toe"])
	_map_bone_fallback("lower_leg_R", ["lowerleg", "calf", "shin"], ["left", "upper", "thigh", "foot", "toe"])

	# Warn once per imported model if core joints remain unmapped. This identifies
	# skeleton naming variants that need an alias rather than silently leaving
	# an obvious T-pose on screen.
	var missing_core: PackedStringArray = PackedStringArray()
	for core_name in ["upper_arm_L", "upper_arm_R", "thigh_L", "thigh_R"]:
		if not bone_ids.has(core_name):
			missing_core.append(core_name)
	if not missing_core.is_empty():
		var warning_key := String(model.scene_file_path)
		if warning_key.is_empty():
			warning_key = model.name
		if not reported_skeleton_warnings.has(warning_key):
			reported_skeleton_warnings[warning_key] = true
			push_warning("Character rig: unmapped core joints for " + warning_key + ": " + ", ".join(missing_core))

	arm_drop["L"] = _drop_quat("upper_arm_L", "forearm_L", 1.0)
	arm_drop["R"] = _drop_quat("upper_arm_R", "forearm_R", -1.0)
	arm_flex_axis["L"] = _segment_bend_axis("upper_arm_L", "forearm_L", Vector3.BACK)
	arm_flex_axis["R"] = _segment_bend_axis("upper_arm_R", "forearm_R", Vector3.FORWARD)
	arm_flex_axis["elbow_L"] = _segment_bend_axis("forearm_L", "hand_L", arm_flex_axis["L"])
	arm_flex_axis["elbow_R"] = _segment_bend_axis("forearm_R", "hand_R", arm_flex_axis["R"])


func _has_explicit_bone_side(n: String, left_side: bool) -> bool:
	if left_side and n.contains("left"):
		return true
	if not left_side and n.contains("right"):
		return true

	# Common exported abbreviations: upperarml / rforearm / lthigh / calfr.
	# Only accept these when the side marker is at an anatomical-token boundary.
	if left_side and n.ends_with("l"):
		return true
	if not left_side and n.ends_with("r"):
		return true

	var prefixes: Array = [
		"lupperarm", "larm", "lforearm", "llowerarm",
		"lupperleg", "lupleg", "llowerleg", "lthigh", "lcalf", "lshin", "lhand", "lfoot",
	] if left_side else [
		"rupperarm", "rarm", "rforearm", "rlowerarm",
		"rupperleg", "rupleg", "rlowerleg", "rthigh", "rcalf", "rshin", "rhand", "rfoot",
	]
	for prefix in prefixes:
		if n.begins_with(String(prefix)):
			return true
	return false


func _map_bone_fallback(canonical: String, include_terms: Array, exclude_terms: Array) -> void:
	if bone_ids.has(canonical) or skeleton == null:
		return

	var needs_left := canonical.ends_with("_L")
	var needs_right := canonical.ends_with("_R")
	for i in range(skeleton.get_bone_count()):
		var n := _normalize_bone_name(String(skeleton.get_bone_name(i)))
		var matches := false
		for term in include_terms:
			if n.contains(String(term)):
				matches = true
				break
		if not matches:
			continue

		# Do not assign a right limb to a missing left slot (or vice versa).
		# Ambiguous names are left unmapped and reported instead of corrupting pose.
		if needs_left and (not _has_explicit_bone_side(n, true) or _has_explicit_bone_side(n, false)):
			continue
		if needs_right and (not _has_explicit_bone_side(n, false) or _has_explicit_bone_side(n, true)):
			continue

		var excluded := false
		for term in exclude_terms:
			if n.contains(String(term)):
				excluded = true
				break
		if excluded:
			continue

		var already_used := false
		for mapped_canonical in bone_ids:
			if int(bone_ids[mapped_canonical]) == i:
				already_used = true
				break
		if not already_used:
			bone_ids[canonical] = i
			return


func _fit_to_ground() -> void:
	var b: AABB = get_bounds(model)
	if b.size.y <= 0.001:
		return
	var s: float = clampf(height / b.size.y, 0.01, 100.0)
	model.scale = Vector3.ONE * s
	var cx: float = b.position.x + b.size.x * 0.5
	var cz: float = b.position.z + b.size.z * 0.5
	if skeleton != null and bone_ids.has("pelvis"):
		var pelvis_idx: int = int(bone_ids["pelvis"])
		var pelvis_local: Vector3 = model.to_local(skeleton.to_global(skeleton.get_bone_global_rest(pelvis_idx).origin))
		cx = pelvis_local.x
		cz = pelvis_local.z
	model.position = Vector3(-cx * s, -b.position.y * s, -cz * s)


func _segment_bend_axis(start_bone: String, end_bone: String, fallback: Vector3) -> Vector3:
	if skeleton == null or not bone_ids.has(start_bone) or not bone_ids.has(end_bone):
		return fallback.normalized()
	var start_idx: int = int(bone_ids[start_bone])
	var end_idx: int = int(bone_ids[end_bone])
	var direction: Vector3 = skeleton.get_bone_global_rest(end_idx).origin - skeleton.get_bone_global_rest(start_idx).origin
	if direction.length() < 0.0001:
		return fallback.normalized()
	# Cross with world-up so a horizontal T-pose arm rotates down/up around Z,
	# rather than rolling invisibly around the arm's own X axis.
	var axis: Vector3 = direction.normalized().cross(Vector3.UP)
	if axis.length() < 0.05:
		return fallback.normalized()
	return axis.normalized()


func _drop_quat(upper: String, lower: String, default_side: float) -> Quaternion:
	if skeleton == null or not bone_ids.has(upper) or not bone_ids.has(lower):
		return Quaternion.IDENTITY
	var ui: int = int(bone_ids[upper])
	var li: int = int(bone_ids[lower])
	var a: Vector3 = skeleton.get_bone_global_rest(ui).origin
	var b: Vector3 = skeleton.get_bone_global_rest(li).origin
	var dir: Vector3 = b - a
	if dir.length() < 0.0001:
		return Quaternion.IDENTITY
	dir = dir.normalized()
	var side: float = signf(dir.x)
	if side == 0.0:
		side = default_side
	var target: Vector3 = Vector3(side * 0.55, -0.83, 0.1).normalized()
	return Quaternion(dir, target)


func _prepare_materials() -> void:
	materials.clear()
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null:
				continue
			var copy := src.duplicate() as BaseMaterial3D
			copy.emission_enabled = true
			copy.emission = Color(1.0, 0.2, 0.1)
			copy.emission_energy_multiplier = 0.0
			mi.set_surface_override_material(s, copy)
			materials.append(copy)


func _make_placeholder() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.1
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.45, 0.33, 0.2)
	capsule.material = body_mat
	body.mesh = capsule
	body.position.y = 0.75
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.65, 0.47, 0.34)
	sphere.material = head_mat
	head.mesh = sphere
	head.position.y = 1.5
	root.add_child(head)
	return root


func _reset_pose() -> void:
	if skeleton == null:
		return
	for bone_index in rest_rot:
		skeleton.set_bone_pose_rotation(int(bone_index), rest_rot[bone_index])


func _pose(bone_name: String, delta_rot: Quaternion) -> void:
	if skeleton == null or not bone_ids.has(bone_name):
		return
	var i: int = int(bone_ids[bone_name])
	var parent_index: int = skeleton.get_bone_parent(i)
	var parent_rest := Quaternion.IDENTITY
	if parent_index >= 0:
		parent_rest = skeleton.get_bone_global_rest(parent_index).basis.get_rotation_quaternion()
	# The requested procedural rotation is in skeleton space. Convert it into
	# the bone's parent-rest space, not the already-animated parent pose. This
	# prevents rotations from being re-applied through the whole bone chain.
	var local_delta: Quaternion = parent_rest.inverse() * delta_rot * parent_rest
	var base_q: Quaternion = rest_rot.get(i, Quaternion.IDENTITY)
	skeleton.set_bone_pose_rotation(i, local_delta * base_q)


func _qx(angle: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, angle)


func _qy(angle: float) -> Quaternion:
	return Quaternion(Vector3.UP, angle)


func _qz(angle: float) -> Quaternion:
	return Quaternion(Vector3(0.0, 0.0, 1.0), angle)


func hit_flash() -> void:
	flash = 1.0
	hit_t = HIT_TIME


func tint(color: Color) -> void:
	for material in materials:
		(material as BaseMaterial3D).albedo_color = color


func die() -> void:
	if dead_time < 0.0:
		dead_time = 0.0
		if anim_player != null:
			anim_player.stop()
		active_motion = ""
		active_motion_speed = 1.0


func _apply_flash() -> void:
	if absf(flash - last_flash) < 0.01:
		return
	last_flash = flash
	for material in materials:
		(material as BaseMaterial3D).emission_energy_multiplier = flash * 2.5


func _sample(keys: Array, p: float) -> Array:
	var a: Array = keys[0]
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if p <= float(b[0]):
			var span: float = maxf(0.0001, float(b[0]) - float(a[0]))
			var k: float = smoothstep(0.0, 1.0, (p - float(a[0])) / span)
			var out: Array = []
			for j in range(1, 7):
				out.append(lerpf(float(a[j]), float(b[j]), k))
			return out
		a = b
	return (keys[keys.size() - 1] as Array).slice(1)


func _find_clip(keywords: Array) -> String:
	if anim_player == null:
		return ""
	for clip in anim_player.get_animation_list():
		var name_lower := String(clip).to_lower()
		for keyword in keywords:
			if name_lower.contains(String(keyword)):
				return String(clip)
	return ""


func _play_clip(keywords: Array) -> bool:
	var clip := _find_clip(keywords)
	if clip.is_empty():
		return false
	if anim_player.current_animation != clip:
		anim_player.play(clip)
	return true


func _play_motion(motion_name: String, playback_speed: float = 1.0, blend_time: float = 0.12) -> bool:
	if anim_player == null:
		return false
	var full_name := "motion/" + motion_name
	if not anim_player.has_animation(full_name):
		return false
	if active_motion != motion_name:
		anim_player.speed_scale = 1.0
		anim_player.play(full_name, blend_time, playback_speed)
		active_motion = motion_name
		active_motion_speed = playback_speed
	elif not is_equal_approx(active_motion_speed, playback_speed):
		anim_player.speed_scale *= playback_speed / maxf(active_motion_speed, 0.001)
		active_motion_speed = playback_speed
	return true


func _animate_death(delta: float) -> void:
	dead_time += delta
	var stagger: float = clampf(dead_time / 0.22, 0.0, 1.0)
	var fall: float = smoothstep(0.08, 0.88, dead_time)
	var side: float = 0.22 if int(get_instance_id()) % 2 == 0 else -0.22
	pivot.rotation = Vector3(-1.42 * fall, 0.0, side * fall)
	pivot.position = Vector3(0.0, 0.10 * fall, -0.12 * fall)
	if skeleton == null:
		return
	_reset_pose()
	_pose("pelvis", _qy(0.18 * fall))
	_pose("spine", _qx(0.38 * stagger * (1.0 - fall)) * _qz(side * 0.55 * fall))
	_pose("chest", _qx(0.25 * stagger * (1.0 - fall)))
	_pose("neck", _qx(-0.25 * fall))
	_pose("head", _qx(-0.38 * fall))
	var axis_l: Vector3 = arm_flex_axis.get("L", Vector3.BACK)
	var axis_r: Vector3 = arm_flex_axis.get("R", Vector3.FORWARD)
	var elbow_axis_l: Vector3 = arm_flex_axis.get("elbow_L", axis_l)
	var elbow_axis_r: Vector3 = arm_flex_axis.get("elbow_R", axis_r)
	_pose("upper_arm_L", Quaternion(axis_l, -0.65 * fall) * _qy(0.45 * fall) * arm_drop.get("L", Quaternion.IDENTITY))
	_pose("upper_arm_R", Quaternion(axis_r, -0.65 * fall) * _qy(-0.45 * fall) * arm_drop.get("R", Quaternion.IDENTITY))
	_pose("forearm_L", Quaternion(elbow_axis_l, -0.25 * fall))
	_pose("forearm_R", Quaternion(elbow_axis_r, -0.25 * fall))
	_pose("thigh_L", _qx(-0.38 * stagger))
	_pose("thigh_R", _qx(-0.20 * stagger))
	_pose("lower_leg_L", _qx(0.85 * stagger))
	_pose("lower_leg_R", _qx(0.60 * stagger))


# attack_p ranges 0..1 while attacking and is negative otherwise.
func animate(delta: float, moving: bool, running: bool, attack_p: float, ranged: bool = false, blocking: bool = false, dodging: bool = false, dashing: bool = false) -> void:
	time += delta
	flash = maxf(0.0, flash - delta * 5.0)
	hit_t = maxf(0.0, hit_t - delta)
	_apply_flash()

	if dead_time >= 0.0:
		dead_time += delta
		if _play_motion("death", 1.0, 0.08):
			return
		_animate_death(delta)
		return

	if hit_t > 0.0 and _play_motion("hit", 1.0, 0.06):
		return

	if blocking:
		if _play_motion("block", 1.0, 0.08):
			return
		if _play_clip(["block", "guard", "defend", "shield"]):
			return

	if dodging:
		if anim_player != null and anim_player.has_animation("motion/dodge"):
			var dodge_animation := anim_player.get_animation("motion/dodge")
			var dodge_speed: float = clampf(dodge_animation.length / 0.42, 0.65, 4.0)
			if _play_motion("dodge", dodge_speed, 0.04):
				return
		if _play_clip(["dodge", "evade", "roll", "slide"]):
			return

	if dashing:
		if anim_player != null and anim_player.has_animation("motion/dash"):
			var dash_animation := anim_player.get_animation("motion/dash")
			var dash_speed: float = clampf(dash_animation.length / 0.30, 0.65, 4.0)
			if _play_motion("dash", dash_speed, 0.04):
				return
		if _play_clip(["dash", "run", "sprint", "forward"]):
			return

	if attack_p >= 0.0:
		var style := "bow" if ranged else attack_style
		var attack_clip := "motion/" + style
		var attack_speed := 1.0
		if anim_player != null and anim_player.has_animation(attack_clip):
			var attack_animation := anim_player.get_animation(attack_clip)
			attack_speed = clampf(attack_animation.length / maxf(ATTACK_WINDOW, 0.05), 0.65, 3.0)
		if _play_motion(style, attack_speed, 0.07):
			return

	if moving:
		var effective_speed := move_speed
		if effective_speed < 0.0:
			effective_speed = 6.5 if running else 3.0
		# Fast player movement uses a run cycle even without the sprint toggle.
		var use_run := running or effective_speed >= 3.6
		if use_run:
			var run_rate := clampf(effective_speed / 4.8, 0.75, 1.45)
			if _play_motion("run", run_rate, 0.12):
				return
		else:
			var walk_rate := clampf(effective_speed / 1.6, 0.8, 1.9)
			if _play_motion("walk", walk_rate, 0.12):
				return

	if _play_motion("idle", 1.0, 0.18):
		return

	# If a GLB contains its own usable clips, preserve support for them.
	if attack_p >= 0.0 and _play_clip(["attack", "slash", "swing", "melee"]):
		return
	if moving and running and _play_clip(["run", "running", "sprint"]):
		return
	if moving and _play_clip(["walk", "walking", "move"]):
		return
	if not moving and _play_clip(["idle", "stand", "breath"]):
		return
	if anim_player != null and anim_player.is_playing() and active_motion.is_empty():
		anim_player.stop()

	_reset_pose()
	var target_speed: float = move_speed
	if target_speed < 0.0:
		target_speed = (6.5 if running else 3.0) if moving else 0.0
	speed_smooth = move_toward(speed_smooth, target_speed, delta * 14.0)
	var spd: float = speed_smooth
	var walk_w: float = clampf(spd / 1.6, 0.0, 1.0)
	var run_w: float = clampf((spd - 4.2) / 3.2, 0.0, 1.0)
	var idle_w: float = 1.0 - walk_w

	# Cadence rises with speed; the earlier version slowed the gait as speed rose.
	if spd > 0.05:
		var cadence: float = lerpf(1.65, 2.55, run_w)
		walk_phase = fposmod(walk_phase + delta * TAU * cadence, TAU)
	var s: float = sin(walk_phase)
	var c: float = cos(walk_phase)

	var leg_amp: float = lerpf(0.40, 0.78, run_w) * walk_w
	var knee_amp: float = lerpf(0.60, 1.12, run_w) * walk_w
	var arm_amp: float = lerpf(0.28, 0.70, run_w) * walk_w
	var lean: float = lerpf(0.025, 0.20, run_w) * walk_w
	var bob: float = absf(s) * lerpf(0.025, 0.065, run_w) * walk_w
	var pelvis_yaw: float = s * lerpf(0.06, 0.15, run_w) * walk_w
	var chest_yaw: float = -s * lerpf(0.10, 0.24, run_w) * walk_w
	var pelvis_roll: float = s * 0.035 * walk_w + sin(time * 0.7) * 0.02 * idle_w

	var leg_l: float = s * leg_amp
	var leg_r: float = -s * leg_amp
	var knee_l: float = maxf(0.0, -c) * knee_amp
	var knee_r: float = maxf(0.0, c) * knee_amp
	var swing_l: float = -s * arm_amp
	var swing_r: float = s * arm_amp
	var lunge: float = 0.0
	var crouch: float = 0.0
	var head_yaw: float = sin(time * 0.45) * 0.08 * idle_w
	var breathe: float = sin(time * 1.7) * 0.02 * idle_w
	var arm_yaw: float = 0.0

	var attacking: bool = attack_p >= 0.0
	if attacking:
		var style: String = "bow" if ranged else attack_style
		var keys: Array = ATTACK_KEYS.get(style, ATTACK_KEYS["slash"])
		var a: Array = _sample(keys, clampf(attack_p, 0.0, 1.0))
		var envelope: float = clampf(minf(attack_p, 1.0 - attack_p) / 0.16, 0.0, 1.0)
		swing_r = lerpf(swing_r, float(a[0]), envelope)
		swing_l = lerpf(swing_l, float(a[0]) * (0.45 if style == "bow" else 0.25), envelope)
		pelvis_yaw = lerpf(pelvis_yaw, -float(a[1]) * 0.18, envelope)
		chest_yaw = lerpf(chest_yaw, float(a[1]) * 0.72, envelope)
		lean = lerpf(lean, float(a[2]), envelope)
		lunge = float(a[3]) * envelope
		arm_yaw = float(a[4]) * envelope
		var front: float = float(a[5])
		leg_l = lerpf(leg_l, front, envelope)
		leg_r = lerpf(leg_r, -front * 0.55, envelope)
		knee_l = lerpf(knee_l, absf(front) * 0.8, envelope)
		knee_r = lerpf(knee_r, absf(front) * 0.45, envelope)
		crouch = absf(front) * 0.07 * envelope

	var h: float = clampf(hit_t / HIT_TIME, 0.0, 1.0)
	var head_hit: float = 0.0
	var recoil: float = 0.0
	if h > 0.0:
		lean -= 0.38 * h
		head_hit = -0.32 * h
		swing_l -= 0.35 * h
		swing_r -= 0.50 * h
		pelvis_yaw += 0.10 * h
		recoil = 0.10 * h

	pivot.position = Vector3(0.0, bob - crouch, lunge - recoil)
	pivot.rotation = Vector3.ZERO
	if skeleton == null:
		pivot.rotation.x = lean * 0.6
		return

	_pose("pelvis", _qy(pelvis_yaw) * _qz(pelvis_roll))
	_pose("spine", _qx(lean * 0.52 + breathe) * _qy(chest_yaw * 0.35))
	_pose("chest", _qx(lean * 0.42 + breathe) * _qy(chest_yaw * 0.65))
	_pose("neck", _qx(-lean * 0.28) * _qy(head_yaw * 0.5))
	_pose("head", _qx(-lean * 0.28 + head_hit) * _qy(head_yaw * 0.5))

	var shoulder_l: Quaternion
	var shoulder_r: Quaternion
	if attacking:
		# Attack swings raise/lower the arms in their flexion plane.
		var axis_l: Vector3 = arm_flex_axis.get("L", Vector3.BACK)
		var axis_r: Vector3 = arm_flex_axis.get("R", Vector3.FORWARD)
		shoulder_l = Quaternion(axis_l, swing_l) * _qy(-arm_yaw * 0.35) * arm_drop.get("L", Quaternion.IDENTITY)
		shoulder_r = Quaternion(axis_r, swing_r) * _qy(arm_yaw) * arm_drop.get("R", Quaternion.IDENTITY)
	else:
		# During locomotion, rotate around body-up to swing arms forward/back.
		shoulder_l = _qy(swing_l - arm_yaw * 0.35) * arm_drop.get("L", Quaternion.IDENTITY)
		# The arms mirror each other across X, so the right-side phase is inverted
		# before applying the same skeleton-space yaw.
		shoulder_r = _qy(-swing_r + arm_yaw) * arm_drop.get("R", Quaternion.IDENTITY)
	_pose("upper_arm_L", shoulder_l)
	_pose("upper_arm_R", shoulder_r)

	var elbow_base: float = 0.22 + 0.45 * run_w * walk_w
	var elbow_l: float = -(elbow_base + maxf(0.0, -swing_l) * 0.42)
	var elbow_r: float = -(elbow_base + maxf(0.0, -swing_r) * 0.42)
	if attacking:
		elbow_l = -0.24
		elbow_r = -0.16
	var elbow_axis_l: Vector3 = arm_flex_axis.get("elbow_L", arm_flex_axis.get("L", Vector3.BACK))
	var elbow_axis_r: Vector3 = arm_flex_axis.get("elbow_R", arm_flex_axis.get("R", Vector3.FORWARD))
	_pose("forearm_L", Quaternion(elbow_axis_l, elbow_l))
	_pose("forearm_R", Quaternion(elbow_axis_r, elbow_r))

	_pose("thigh_L", _qx(leg_l))
	_pose("thigh_R", _qx(leg_r))
	_pose("lower_leg_L", _qx(knee_l))
	_pose("lower_leg_R", _qx(knee_r))
	_pose("foot_L", _qx(-(leg_l + knee_l) * 0.72))
	_pose("foot_R", _qx(-(leg_r + knee_r) * 0.72))
