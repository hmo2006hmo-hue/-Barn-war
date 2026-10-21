
extends SkeletonModifier3D

# Explicit bone links:
# [target_name, FBX_name, FBX_index, GLB_index, GLB_parent_index, FBX_parent_index]
# FBX: 65 bones
# GLB: 40 bones
# FBX Spine1 (index 2) is not mapped directly. Its animated rotation is
# preserved through the global rest-relative rotation transfer.

const BONE_LINKS := [
	["pelvis", "mixamorig_Hips", 0, 1, 0, -1],
	["spine", "mixamorig_Spine", 1, 2, 1, 0],
	["chest", "mixamorig_Spine2", 3, 3, 2, 2],
	["neck", "mixamorig_Neck", 4, 4, 3, 3],
	["head", "mixamorig_Head", 5, 5, 4, 4],

	["clavicle_L", "mixamorig_LeftShoulder", 31, 6, 3, 3],
	["upper_arm_L", "mixamorig_LeftArm", 32, 7, 6, 31],
	["forearm_L", "mixamorig_LeftForeArm", 33, 8, 7, 32],
	["hand_L", "mixamorig_LeftHand", 34, 9, 8, 33],

	["finger1_1_L", "mixamorig_LeftHandIndex1", 39, 10, 9, 34],
	["finger1_2_L", "mixamorig_LeftHandIndex2", 40, 11, 10, 39],
	["finger1_3_L", "mixamorig_LeftHandIndex3", 41, 12, 11, 40],

	["finger2_1_L", "mixamorig_LeftHandMiddle1", 43, 13, 9, 34],
	["finger2_2_L", "mixamorig_LeftHandMiddle2", 44, 14, 13, 43],
	["finger2_3_L", "mixamorig_LeftHandMiddle3", 45, 15, 14, 44],

	["finger3_1_L", "mixamorig_LeftHandRing1", 47, 16, 9, 34],
	["finger3_2_L", "mixamorig_LeftHandRing2", 48, 17, 16, 47],
	["finger3_3_L", "mixamorig_LeftHandRing3", 49, 18, 17, 48],

	["clavicle_R", "mixamorig_RightShoulder", 7, 19, 3, 3],
	["upper_arm_R", "mixamorig_RightArm", 8, 20, 19, 7],
	["forearm_R", "mixamorig_RightForeArm", 9, 21, 20, 8],
	["hand_R", "mixamorig_RightHand", 10, 22, 21, 9],

	["finger1_1_R", "mixamorig_RightHandIndex1", 15, 23, 22, 10],
	["finger1_2_R", "mixamorig_RightHandIndex2", 16, 24, 23, 15],
	["finger1_3_R", "mixamorig_RightHandIndex3", 17, 25, 24, 16],

	["finger2_1_R", "mixamorig_RightHandMiddle1", 19, 26, 22, 10],
	["finger2_2_R", "mixamorig_RightHandMiddle2", 20, 27, 26, 19],
	["finger2_3_R", "mixamorig_RightHandMiddle3", 21, 28, 27, 20],

	["finger3_1_R", "mixamorig_RightHandRing1", 23, 29, 22, 10],
	["finger3_2_R", "mixamorig_RightHandRing2", 24, 30, 29, 23],
	["finger3_3_R", "mixamorig_RightHandRing3", 25, 31, 30, 24],

	["thigh_L", "mixamorig_LeftUpLeg", 60, 32, 1, 0],
	["lower_leg_L", "mixamorig_LeftLeg", 61, 33, 32, 60],
	["foot_L", "mixamorig_LeftFoot", 62, 34, 33, 61],
	["toe_L", "mixamorig_LeftToeBase", 63, 35, 34, 62],

	["thigh_R", "mixamorig_RightUpLeg", 55, 36, 1, 0],
	["lower_leg_R", "mixamorig_RightLeg", 56, 37, 36, 55],
	["foot_R", "mixamorig_RightFoot", 57, 38, 37, 56],
	["toe_R", "mixamorig_RightToeBase", 58, 39, 38, 57],
]

var source_skeleton: Skeleton3D
var target_skeleton: Skeleton3D
var _validated: bool = false


func configure(source: Skeleton3D, target: Skeleton3D) -> bool:
	source_skeleton = source
	target_skeleton = target
	_validated = false

	if source_skeleton == null or target_skeleton == null:
		push_error(
            "Explicit retarget: source/target skeleton reference is null."
		)
		return false

	for row in BONE_LINKS:
		var target_name: String = String(row[0])
		var source_name: String = String(row[1])
		var source_index: int = int(row[2])
		var target_index: int = int(row[3])
		var target_parent: int = int(row[4])
		var source_parent: int = int(row[5])

		if (
			source_index < 0
			or source_index >= source_skeleton.get_bone_count()
		):
			push_error(
                "Explicit retarget: FBX index out of range for "
				+ source_name
			)
			return false

		var actual_source_name := String(
			source_skeleton.get_bone_name(source_index)
		)

		if actual_source_name != source_name:
			push_error(
                "Explicit retarget: FBX index/name mismatch at index "
				+ str(source_index)
				+ "; expected "
				+ source_name
				+ ", got "
				+ actual_source_name
			)
			return false

		if source_skeleton.get_bone_parent(source_index) != source_parent:
			push_error(
                "Explicit retarget: FBX parent mismatch for "
				+ source_name
			)
			return false

		if (
			target_index < 0
			or target_index >= target_skeleton.get_bone_count()
		):
			push_error(
                "Explicit retarget: GLB index out of range for "
				+ target_name
			)
			return false

		var actual_target_name := String(
			target_skeleton.get_bone_name(target_index)
		)

		if actual_target_name != target_name:
			push_error(
                "Explicit retarget: GLB index/name mismatch at index "
				+ str(target_index)
				+ "; expected "
				+ target_name
				+ ", got "
				+ actual_target_name
			)
			return false

		if target_skeleton.get_bone_parent(target_index) != target_parent:
			push_error(
                "Explicit retarget: GLB parent mismatch for "
				+ target_name
			)
			return false

	_validated = true

	print(
		"EXPLICIT_RETARGET_CONFIGURED: links=",
		BONE_LINKS.size(),
		" | FBX_bones=",
		source_skeleton.get_bone_count(),
		" | GLB_bones=",
		target_skeleton.get_bone_count()
	)

	return true


func _process_modification_with_delta(_delta: float) -> void:
	if (
		not _validated
		or source_skeleton == null
		or target_skeleton == null
	):
		return

	# Convert both skeleton coordinate frames into the common world frame.
	# This accounts for differences between the FBX and GLB node transforms.
	var source_to_world: Basis = (
		source_skeleton.global_transform.basis.orthonormalized()
	)

	var target_to_world: Basis = (
		target_skeleton.global_transform.basis.orthonormalized()
	)

	var world_to_target: Basis = target_to_world.inverse()

	# Track desired target global rotations so child bones use the rotations
	# calculated for their target parents, not the previous frame's pose.
	var desired_target_global_basis: Dictionary = {
		0: target_skeleton.get_bone_global_rest(0).basis.orthonormalized()
	}

	for row in BONE_LINKS:
		var source_index: int = int(row[2])
		var target_index: int = int(row[3])
		var target_parent_index: int = int(row[4])

		var source_pose_global: Transform3D = (
			source_skeleton.get_bone_global_pose(source_index)
		)

		var source_rest_global: Transform3D = (
			source_skeleton.get_bone_global_rest(source_index)
		)

		var target_rest_global: Transform3D = (
			target_skeleton.get_bone_global_rest(target_index)
		)

		# Express the animated FBX pose and its rest pose in world coordinates.
		var source_pose_world: Basis = (
			source_to_world * source_pose_global.basis
		).orthonormalized()

		var source_rest_world: Basis = (
			source_to_world * source_rest_global.basis
		).orthonormalized()

		# Calculate the animation delta relative to the FBX rest orientation.
		var source_delta_world: Basis = (
			source_pose_world * source_rest_world.inverse()
		).orthonormalized()

		# Express the GLB rest orientation in world coordinates.
		var target_rest_world: Basis = (
			target_to_world * target_rest_global.basis
		).orthonormalized()

		# Apply the FBX animation delta to the GLB rest orientation,
		# then convert the result back into the GLB skeleton frame.
		var target_pose_global_basis: Basis = (
			world_to_target
			* source_delta_world
			* target_rest_world
		).orthonormalized()

		var parent_pose_global_basis: Basis

		if desired_target_global_basis.has(target_parent_index):
			parent_pose_global_basis = (
				desired_target_global_basis[target_parent_index]
			)
		else:
			parent_pose_global_basis = (
				target_skeleton
				.get_bone_global_rest(target_parent_index)
				.basis
				.orthonormalized()
			)

		# Convert the desired target global rotation into target-local space.
		var target_pose_local_basis: Basis = (
			parent_pose_global_basis.inverse()
			* target_pose_global_basis
		).orthonormalized()

		# Change rotation only. Preserve the GLB's original bone lengths
		# and local translation offsets.
		target_skeleton.set_bone_pose_rotation(
			target_index,
			target_pose_local_basis.get_rotation_quaternion()
		)

		desired_target_global_basis[target_index] = (
			target_pose_global_basis
		)
