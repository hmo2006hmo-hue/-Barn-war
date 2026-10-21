
extends SkeletonModifier3D

# Retarget Mixamo's 65-bone animation source onto Oran's 23-bone GLB rig.
# Only bones present in both hierarchies are mapped; Oran's separate Root is
# kept at rest. Spine1 is mapped directly rather than being discarded.

const BONE_LINKS := [
	# Oran uses a 23-bone Mixamo body rig (including a separate Root).
	# Rows: [target_name, FBX_name, FBX_index, GLB_index, GLB_parent_index, FBX_parent_index]
	["mixamorig_Hips", "mixamorig_Hips", 0, 1, 0, -1],
	["mixamorig_Spine", "mixamorig_Spine", 1, 2, 1, 0],
	["mixamorig_Spine1", "mixamorig_Spine1", 2, 3, 2, 1],
	["mixamorig_Spine2", "mixamorig_Spine2", 3, 4, 3, 2],
	["mixamorig_Neck", "mixamorig_Neck", 4, 5, 4, 3],
	["mixamorig_Head", "mixamorig_Head", 5, 6, 5, 4],
	["mixamorig_LeftShoulder", "mixamorig_LeftShoulder", 31, 7, 4, 3],
	["mixamorig_LeftArm", "mixamorig_LeftArm", 32, 8, 7, 31],
	["mixamorig_LeftForeArm", "mixamorig_LeftForeArm", 33, 9, 8, 32],
	["mixamorig_LeftHand", "mixamorig_LeftHand", 34, 10, 9, 33],
	["mixamorig_RightShoulder", "mixamorig_RightShoulder", 7, 11, 4, 3],
	["mixamorig_RightArm", "mixamorig_RightArm", 8, 12, 11, 7],
	["mixamorig_RightForeArm", "mixamorig_RightForeArm", 9, 13, 12, 8],
	["mixamorig_RightHand", "mixamorig_RightHand", 10, 14, 13, 9],
	["mixamorig_LeftUpLeg", "mixamorig_LeftUpLeg", 60, 15, 1, 0],
	["mixamorig_LeftLeg", "mixamorig_LeftLeg", 61, 16, 15, 60],
	["mixamorig_LeftFoot", "mixamorig_LeftFoot", 62, 17, 16, 61],
	["mixamorig_LeftToeBase", "mixamorig_LeftToeBase", 63, 18, 17, 62],
	["mixamorig_RightUpLeg", "mixamorig_RightUpLeg", 55, 19, 1, 0],
	["mixamorig_RightLeg", "mixamorig_RightLeg", 56, 20, 19, 55],
	["mixamorig_RightFoot", "mixamorig_RightFoot", 57, 21, 20, 56],
	["mixamorig_RightToeBase", "mixamorig_RightToeBase", 58, 22, 21, 57],
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
