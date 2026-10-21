extends Node3D

# ==================================================
# حرب الحضارات - مشهد اللعب (القصة: الفصل الأول نَمار + المعركة الحرة)
# ==================================================

const Rig = preload("res://scripts/rig.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Session = preload("res://scripts/session.gd")
const UI = preload("res://scripts/ui_kit.gd")
const Story = preload("res://scripts/story.gd")

const MAIN_SCENE := "res://scenes/main.tscn"

const PLAYER_HEIGHT := 1.75
const PLAYER_MAX_HP := 100.0
const PLAYER_SPEED := 4.4
const PLAYER_ATTACK_RANGE := 2.7
const AIM_ASSIST := 4.5
const ATTACK_DURATION := 0.76
const GRAVITY := 18.0
const WORLD_RADIUS := 33.0
const JOY_RADIUS := 90.0
const RANGED_MIN := 6.0
const RANGED_MAX := 11.0
const SHARD_RADIUS := 6.5
const SHARD_DAMAGE := 3.0
const SHARD_COST := 32.0

enum State { PLAYING, DIALOGUE, CARD, PAUSED, GAME_OVER }
enum Step { PROLOGUE, GO_MARKET, TRAINING, RETURN_GUARD, WAVE1, WAVE2, SHARD, SHARD_TRIAL, MASKED, END }

# مواضع مباني نَمار: key يطابق نوع المبنى في الفهرس، h الارتفاع، cap أقصى امتداد أفقي
const TOWN := [
    {"key": "hall", "pos": Vector3(0, 0, -26), "h": 7.0, "cap": 12.0},
    {"key": "store", "pos": Vector3(-24, 0, -4), "h": 4.5, "cap": 11.0},
    {"key": "farm", "pos": Vector3(26, 0, 4), "h": 3.5, "cap": 13.0},
    {"key": "barracks", "pos": Vector3(-25, 0, 14), "h": 4.5, "cap": 13.0},
    {"key": "tower", "pos": Vector3(24, 0, -18), "h": 9.0, "cap": 7.0},
    {"key": "house", "pos": Vector3(-14, 0, -25), "h": 4.5, "cap": 9.0},
    {"key": "house", "pos": Vector3(14, 0, -24), "h": 4.5, "cap": 9.0},
    {"key": "house", "pos": Vector3(-24, 0, -18), "h": 4.5, "cap": 9.0},
    {"key": "gate", "pos": Vector3(0, 0, 38), "h": 7.0, "cap": 16.0, "collide": false},
]


class Actor:
    var node: CharacterBody3D
    var yaw_node: Node3D
    var rig = null
    var kind: String = "melee"   # melee | ranged | dummy | ally | npc | masked
    var title: String = ""
    var hp: float = 3.0
    var speed: float = 2.4
    var damage: float = 8.0
    var reach: float = 1.9
    var cooldown_max: float = 1.4
    var cooldown: float = 1.0
    var attack_t: float = 0.0
    var attack_done: bool = false
    var dead: bool = false
    var dead_t: float = 0.0
    var knock: Vector3 = Vector3.ZERO
    var yaw: float = 0.0
    var swerve: float = 1.0
    var moving: bool = false
    var style: String = "slash"
    var stun: float = 0.0


var characters: Array = []
var buildings: Array = []
var hero_path: String = ""

var state: int = State.PLAYING
var story_mode: bool = true
var step: int = Step.PROLOGUE
var pending_step: int = -1
var pending_delay: float = 0.0

var world_root: Node3D
var marker: Node3D
var marker_active: bool = false
var marker_pos: Vector3 = Vector3.ZERO
var marker_radius: float = 3.5

var player: CharacterBody3D
var player_yaw_node: Node3D
var player_rig = null
var player_yaw: float = PI
var player_hp: float = PLAYER_MAX_HP
var player_knock: Vector3 = Vector3.ZERO
var attack_t: float = 0.0
var attack_done: bool = true
var invuln: float = 0.0
var running: bool = false
var blocking: bool = false
var dodge_t: float = 0.0
var dash_t: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var dash_direction: Vector3 = Vector3.ZERO

var camera: Camera3D
var camera_yaw: float = 0.0
var camera_pitch: float = 0.25
var camera_distance: float = 4.8
var cam_dist_now: float = 4.8
var shake: float = 0.0
var cam_manual_t: float = 0.0
var hero_tag: String = "infantry"
var player_combo: int = 0

var actors: Array[Actor] = []
var projectiles: Array = []
var kuri: Actor = null
var masked: Actor = null

var kills: int = 0
var wave: int = 1
var dummies_down: int = 0
var shard_unlocked: bool = false
var shard_uses: int = 0
var shard_cd: float = 0.0
var shard_idle: float = 0.0
var fatigue: float = 0.0
var exhausted: bool = false
var trial_extra_spawned: bool = false
var wave_break: float = 0.0
var time_passed: float = 0.0
var message_timer: float = 0.0
var damage_flash: float = 0.0
var overlay_flash: float = 0.0

# الحوار
var dlg_lines: Array = []
var dlg_index: int = 0
var dlg_done: Callable = Callable()
var card_done: Callable = Callable()

# اللمس
var joy_index: int = -1
var joy_origin: Vector2 = Vector2.ZERO
var joy_vector: Vector2 = Vector2.ZERO
var cam_index: int = -1
var mouse_look: bool = false
var pads: Array = []

# الواجهة
var ui_root: Control
var hud_root: Control
var safe_root: Control
var pad_group: Control
var joy_pad: Control
var info_label: Label
var hp_bar: ProgressBar
var fatigue_bar: ProgressBar
var objective_label: Label
var distance_label: Label
var compass: Control
var message_label: Label
var run_pad: Panel
var block_pad: Panel
var shard_pad: Panel
var vignette: ColorRect
var flash_rect: ColorRect
var dialogue_root: Control
var dialogue_speaker: Label
var dialogue_text: Label
var card_root: Control
var card_title: Label
var card_body: Label
var card_button: Button
var pause_root: Control
var end_root: Control
var end_title: Label
var end_info: Label
var end_retry: Button


func _ready() -> void:
    randomize()
    Session.load_data()
    var catalog: Dictionary = Catalog.scan()
    characters = catalog["characters"]
    buildings = catalog["buildings"]
    story_mode = Session.mode == "story"

    var hero: Dictionary = Catalog.find_by_kingdom(characters, Story.HERO_KINGDOM)
    if not story_mode and not characters.is_empty():
        hero = characters[posmod(Session.char_index, characters.size())]
    hero_path = String(hero.get("path", ""))
    hero_tag = String(hero.get("tag", "infantry"))

    _build_world()
    _build_player(hero_path)
    _build_camera()
    _build_ui()

    if story_mode:
        _begin_story()
    else:
        _begin_free()


# --------------------------------------------------
# العالم
# --------------------------------------------------

func _build_world() -> void:
    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)

    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.26, 0.42, 0.72)
    sky_material.sky_horizon_color = Color(0.88, 0.74, 0.55)
    sky_material.ground_horizon_color = Color(0.72, 0.62, 0.46)
    sky_material.ground_bottom_color = Color(0.3, 0.26, 0.2)
    var sky := Sky.new()
    sky.sky_material = sky_material

    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.82, 0.72, 0.58)
    env.fog_density = 0.006
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    world_root.add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = Session.shadows
    sun.directional_shadow_max_distance = 60.0
    world_root.add_child(sun)

    _make_box("Ground", Vector3(0, -0.25, 0), Vector3(200, 0.5, 200), Color(0.5, 0.42, 0.3), true)

    var plaza := MeshInstance3D.new()
    var plaza_mesh := CylinderMesh.new()
    plaza_mesh.top_radius = 14.0
    plaza_mesh.bottom_radius = 14.0
    plaza_mesh.height = 0.04
    plaza_mesh.radial_segments = 48
    var plaza_mat := StandardMaterial3D.new()
    plaza_mat.albedo_color = Color(0.66, 0.57, 0.42)
    plaza_mat.roughness = 1.0
    plaza_mesh.material = plaza_mat
    plaza.mesh = plaza_mesh
    plaza.position = Vector3(0, 0.02, 0)
    world_root.add_child(plaza)

    _make_box("Road", Vector3(0, 0.015, 26), Vector3(6, 0.03, 26), Color(0.62, 0.53, 0.39), false)

    _spawn_town()
    _spawn_decor()
    _build_marker()


func _make_box(box_name: String, pos: Vector3, dimensions: Vector3, color: Color, with_collision: bool) -> void:
    var body: Node3D = StaticBody3D.new() if with_collision else Node3D.new()
    body.name = box_name
    body.position = pos

    var mesh_instance := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = dimensions
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.95
    box_mesh.material = material
    mesh_instance.mesh = box_mesh
    body.add_child(mesh_instance)

    if with_collision:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = dimensions
        collision.shape = shape
        body.add_child(collision)

    world_root.add_child(body)


func _spawn_town() -> void:
    for spec in TOWN:
        var entry: Dictionary = Catalog.find_building(buildings, String(spec["key"]))
        if entry.is_empty():
            continue
        _place_building(entry, spec)


func _place_building(entry: Dictionary, spec: Dictionary) -> void:
    var packed: PackedScene = ResourceLoader.load(String(entry["path"])) as PackedScene
    if packed == null:
        return
    var model: Node3D = packed.instantiate() as Node3D
    if model == null:
        return

    var pos: Vector3 = spec["pos"]
    var body := StaticBody3D.new()
    body.name = "Building_" + String(spec["key"])
    world_root.add_child(body)
    body.position = pos
    body.rotation.y = atan2(-pos.x, -pos.z)
    body.add_child(model)

    var b: AABB = Rig.get_bounds(model)
    if b.size.y <= 0.001:
        return
    var s: float = float(spec["h"]) / b.size.y
    var extent: float = maxf(b.size.x, b.size.z)
    s = minf(s, float(spec["cap"]) / maxf(extent, 0.001))
    model.scale = Vector3.ONE * s
    model.position = Vector3(
        -(b.position.x + b.size.x * 0.5) * s,
        -b.position.y * s,
        -(b.position.z + b.size.z * 0.5) * s)

    if bool(spec.get("collide", true)):
        var size: Vector3 = b.size * s
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        collision.position = Vector3(0.0, size.y * 0.5, 0.0)
        body.add_child(collision)


func _spawn_decor() -> void:
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color(0.36, 0.26, 0.15)
    var leaf_mat := StandardMaterial3D.new()
    leaf_mat.albedo_color = Color(0.2, 0.42, 0.2)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for i in 18:
        var angle: float = rng.randf() * TAU
        var radius: float = rng.randf_range(36.0, 55.0)
        var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        if Vector2(pos.x, pos.z - 38.0).length() < 10.0:
            continue
        var palm := Node3D.new()
        palm.position = pos

        var trunk := MeshInstance3D.new()
        var trunk_mesh := CylinderMesh.new()
        trunk_mesh.top_radius = 0.14
        trunk_mesh.bottom_radius = 0.2
        trunk_mesh.height = 4.2
        trunk_mesh.material = trunk_mat
        trunk.mesh = trunk_mesh
        trunk.position.y = 2.1
        palm.add_child(trunk)

        var leaves := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 1.5
        leaf_mesh.height = 1.0
        leaf_mesh.material = leaf_mat
        leaves.mesh = leaf_mesh
        leaves.position.y = 4.4
        palm.add_child(leaves)
        world_root.add_child(palm)


func _build_marker() -> void:
    marker = Node3D.new()
    var ring := MeshInstance3D.new()
    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 1.8
    ring_mesh.bottom_radius = 1.8
    ring_mesh.height = 0.06
    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.albedo_color = Color(1.0, 0.85, 0.35, 0.45)
    ring_mesh.material = ring_mat
    ring.mesh = ring_mesh
    ring.position.y = 0.05
    marker.add_child(ring)

    var beam := MeshInstance3D.new()
    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.2
    beam_mesh.bottom_radius = 0.2
    beam_mesh.height = 9.0
    var beam_mat := StandardMaterial3D.new()
    beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_mat.albedo_color = Color(1.0, 0.85, 0.35, 0.3)
    beam_mesh.material = beam_mat
    beam.mesh = beam_mesh
    beam.position.y = 4.5
    marker.add_child(beam)

    marker.visible = false
    world_root.add_child(marker)


func _set_marker(pos: Vector3, radius: float = 3.5) -> void:
    marker_pos = pos
    marker_radius = radius
    marker_active = true
    marker.global_position = Vector3(pos.x, 0.0, pos.z)
    marker.visible = true


func _clear_marker() -> void:
    marker_active = false
    marker.visible = false


# --------------------------------------------------
# اللاعب والكاميرا
# --------------------------------------------------

func _build_player(path: String) -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.collision_layer = 2
    player.collision_mask = 1 | 4
    add_child(player)
    player.position = Story.PLAYER_START if story_mode else Vector3(0.0, 0.05, 10.0)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.75
    collision.shape = capsule
    collision.position.y = 0.875
    player.add_child(collision)

    player_yaw_node = Node3D.new()
    player.add_child(player_yaw_node)
    player_yaw_node.rotation.y = player_yaw

    player_rig = Rig.new()
    player_rig.setup(path, player_yaw_node, PLAYER_HEIGHT)


func _build_camera() -> void:
    camera = Camera3D.new()
    camera.fov = 70.0
    camera.current = true
    add_child(camera)


func _update_camera(delta: float) -> void:
    if not is_instance_valid(camera) or not is_instance_valid(player):
        return
    var target: Vector3 = player.global_position + Vector3(0.0, 1.5, 0.0)
    var dir := Vector3(
        sin(camera_yaw) * cos(camera_pitch),
        sin(camera_pitch),
        cos(camera_yaw) * cos(camera_pitch))
    var desired: Vector3 = target + dir * camera_distance

    # منع الكاميرا من اختراق المباني
    var allowed: float = camera_distance
    var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
    query.exclude = [player.get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var hit_pos: Vector3 = hit["position"]
        allowed = maxf(0.8, target.distance_to(hit_pos) - 0.3)
    if allowed < cam_dist_now:
        cam_dist_now = allowed
    else:
        cam_dist_now = move_toward(cam_dist_now, allowed, delta * 8.0)

    var pos: Vector3 = target + dir * cam_dist_now
    if shake > 0.0:
        pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.15
    camera.global_position = pos
    camera.look_at(target, Vector3.UP)


func _rotate_camera(relative: Vector2) -> void:
    cam_manual_t = 1.5
    var k: float = Session.sensitivity
    camera_yaw -= relative.x * 0.006 * k
    camera_pitch = clampf(camera_pitch + relative.y * 0.004 * k, -0.1, 1.15)


# --------------------------------------------------
# الشخصيات (لاعب/أعداء/حلفاء)
# --------------------------------------------------

func _spawn_actor(entry: Dictionary, pos: Vector3, kind: String, hp_mult: float = 1.0) -> Actor:
    var a := Actor.new()
    a.kind = kind
    a.node = CharacterBody3D.new()
    a.node.collision_layer = 4
    if kind == "melee" or kind == "ranged":
        a.node.collision_mask = 1 | 2 | 4
    else:
        a.node.collision_mask = 1
    world_root.add_child(a.node)
    a.node.position = pos

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    a.node.add_child(collision)

    a.yaw_node = Node3D.new()
    a.node.add_child(a.yaw_node)

    var path: String = String(entry.get("path", ""))
    a.rig = Rig.new()
    a.rig.setup(path, a.yaw_node, 1.75 if kind != "dummy" else 1.5)

    a.hp = float(entry.get("hp", 3.0)) * hp_mult
    a.speed = float(entry.get("speed", 2.4))
    a.damage = float(entry.get("damage", 8.0))
    a.reach = float(entry.get("reach", 1.9))
    a.cooldown_max = float(entry.get("cooldown", 1.4))
    a.cooldown = randf_range(0.6, 1.6)
    a.swerve = 1.0 if randf() < 0.5 else -1.0
    a.style = _style_for_tag(String(entry.get("tag", "infantry")))
    a.rig.attack_style = a.style

    if kind == "dummy":
        a.hp = 3.0
        a.rig.tint(Color(0.75, 0.6, 0.38))
    elif kind == "masked":
        a.rig.tint(Color(0.22, 0.22, 0.28))
    elif kind == "melee" or kind == "ranged":
        a.rig.tint(Color(0.9, 0.82, 0.8))

    actors.append(a)
    return a


func _style_for_tag(tag: String) -> String:
    if tag == "spear":
        return "thrust"
    if tag == "heavy":
        return "chop"
    if tag == "archer":
        return "bow"
    return "slash"


func _flat_dist(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()


func _apply_gravity(body: CharacterBody3D, delta: float) -> void:
    if body.is_on_floor():
        body.velocity.y = -0.5
    else:
        body.velocity.y -= GRAVITY * delta


func _attack_p(timer: float) -> float:
    if timer <= 0.0:
        return -1.0
    return 1.0 - timer / ATTACK_DURATION


func _is_enemy(a: Actor) -> bool:
    return a.kind == "melee" or a.kind == "ranged"


func _enemies_alive() -> int:
    var n: int = 0
    for a in actors:
        if _is_enemy(a) and not a.dead:
            n += 1
    return n


func _update_actors(delta: float) -> void:
    for a in actors:
        if not is_instance_valid(a.node):
            continue
        a.cooldown = maxf(0.0, a.cooldown - delta)
        a.attack_t = maxf(0.0, a.attack_t - delta)
        a.knock = a.knock * maxf(0.0, 1.0 - delta * 7.0)

        if a.dead:
            a.dead_t += delta
            a.rig.animate(delta, false, false, -1.0)
            if a.dead_t > 2.1:
                a.node.position.y -= delta * 0.9
            continue

        if a.kind == "melee" or a.kind == "ranged":
            _ai_enemy(a, delta)
        elif a.kind == "ally":
            _ai_ally(a, delta)
        else:
            _ai_idle(a, delta)

    for i in range(actors.size() - 1, -1, -1):
        var d: Actor = actors[i]
        if d.dead and d.dead_t > 3.2:
            if is_instance_valid(d.node):
                d.node.queue_free()
            actors.remove_at(i)


func _face(a: Actor, dir: Vector3, delta: float) -> void:
    if dir.length() < 0.01:
        return
    a.yaw = lerp_angle(a.yaw, atan2(dir.x, dir.z), clampf(delta * 10.0, 0.0, 1.0))
    a.yaw_node.rotation.y = a.yaw


func _ai_enemy(a: Actor, delta: float) -> void:
    var to_p: Vector3 = player.global_position - a.node.global_position
    to_p.y = 0.0
    var dist: float = to_p.length()
    var dir: Vector3 = Vector3.ZERO
    if dist > 0.001:
        dir = to_p / dist

    var ranged: bool = a.kind == "ranged"
    var attacking: bool = a.attack_t > 0.0
    var want: Vector3 = Vector3.ZERO
    if ranged:
        if dist > RANGED_MAX:
            want = dir
        elif dist < RANGED_MIN:
            want = -dir * 0.8
    elif dist > a.reach * 0.85:
        want = dir

    if want != Vector3.ZERO:
        var side := Vector3(-dir.z, 0.0, dir.x) * a.swerve * 0.35
        want = (want + side).normalized()
    if a.stun > 0.0:
        a.stun -= delta
        want = Vector3.ZERO
    if attacking:
        want = Vector3.ZERO

    _apply_gravity(a.node, delta)
    var vel: Vector3 = want * a.speed + a.knock
    a.node.velocity.x = vel.x
    a.node.velocity.z = vel.z
    a.node.move_and_slide()
    a.moving = want != Vector3.ZERO
    a.rig.move_speed = want.length() * a.speed
    _face(a, dir, delta)

    if not attacking and a.cooldown <= 0.0 and a.stun <= 0.0:
        var in_range: bool = dist <= a.reach
        if ranged:
            in_range = dist >= RANGED_MIN * 0.7 and dist <= RANGED_MAX + 2.0
        if in_range:
            a.attack_t = ATTACK_DURATION
            a.attack_done = false
            a.cooldown = a.cooldown_max

    if a.attack_t > 0.0 and not a.attack_done:
        if _attack_p(a.attack_t) >= 0.55:
            a.attack_done = true
            if ranged:
                _fire_arrow(a)
            elif dist <= a.reach + 0.6:
                _damage_player(a.damage, a.node.global_position)

    a.rig.animate(delta, a.moving, false, _attack_p(a.attack_t), ranged)


func _nearest_enemy(from_pos: Vector3) -> Actor:
    var best: Actor = null
    var best_d: float = 1000.0
    for e in actors:
        if not _is_enemy(e) or e.dead:
            continue
        var d: float = _flat_dist(e.node.global_position, from_pos)
        if d < best_d:
            best_d = d
            best = e
    return best


func _ai_ally(a: Actor, delta: float) -> void:
    var target: Actor = _nearest_enemy(a.node.global_position)
    var want: Vector3 = Vector3.ZERO
    var face_dir: Vector3 = Vector3.ZERO
    if target != null:
        var to_t: Vector3 = target.node.global_position - a.node.global_position
        to_t.y = 0.0
        var d: float = to_t.length()
        face_dir = to_t.normalized()
        if d > 2.0 and a.attack_t <= 0.0:
            want = face_dir
        if d <= 2.4 and a.cooldown <= 0.0 and a.attack_t <= 0.0:
            a.attack_t = ATTACK_DURATION
            a.attack_done = false
            a.cooldown = 1.1
        if a.attack_t > 0.0 and not a.attack_done and _attack_p(a.attack_t) >= 0.55:
            a.attack_done = true
            if d <= 3.0:
                _damage_actor(target, 1.0, a.node.global_position, 4.0)
    else:
        var to_p: Vector3 = player.global_position - a.node.global_position
        to_p.y = 0.0
        if to_p.length() > 5.0:
            want = to_p.normalized()
        face_dir = to_p.normalized()

    _apply_gravity(a.node, delta)
    a.node.velocity.x = want.x * 3.2
    a.node.velocity.z = want.z * 3.2
    a.node.move_and_slide()
    a.moving = want != Vector3.ZERO
    a.rig.move_speed = want.length() * 3.2
    _face(a, face_dir, delta)
    a.rig.animate(delta, a.moving, false, _attack_p(a.attack_t), false)


func _ai_idle(a: Actor, delta: float) -> void:
    if a.kind == "npc" or a.kind == "masked":
        var to_p: Vector3 = player.global_position - a.node.global_position
        to_p.y = 0.0
        if to_p.length() < 10.0:
            _face(a, to_p.normalized(), delta)
    a.rig.move_speed = 0.0
    a.rig.animate(delta, false, false, -1.0)


func _fire_arrow(a: Actor) -> void:
    var from_pos: Vector3 = a.node.global_position + Vector3(0.0, 1.4, 0.0)
    var target: Vector3 = player.global_position + Vector3(0.0, 1.1, 0.0)
    var dir: Vector3 = (target - from_pos).normalized()

    var arrow := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.05, 0.05, 0.7)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.45, 0.3, 0.15)
    mesh.material = mat
    arrow.mesh = mesh
    world_root.add_child(arrow)
    arrow.global_position = from_pos + dir * 0.6
    arrow.look_at(arrow.global_position + dir, Vector3.UP)
    projectiles.append({"node": arrow, "vel": dir * 15.0, "life": 2.8, "dmg": a.damage})


func _update_projectiles(delta: float) -> void:
    for i in range(projectiles.size() - 1, -1, -1):
        var p: Dictionary = projectiles[i]
        var node: Node3D = p["node"]
        var vel: Vector3 = p["vel"]
        node.global_position += vel * delta
        p["life"] = float(p["life"]) - delta

        var done: bool = float(p["life"]) <= 0.0 or node.global_position.y < 0.05
        var chest: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
        if node.global_position.distance_to(chest) < 0.8:
            _damage_player(float(p["dmg"]), node.global_position - vel)
            done = true
        if done:
            node.queue_free()
            projectiles.remove_at(i)


# --------------------------------------------------
# القتال
# --------------------------------------------------

func _player_attack() -> void:
    if state != State.PLAYING or attack_t > 0.0 or blocking or dodge_t > 0.0 or dash_t > 0.0:
        return
    attack_t = ATTACK_DURATION
    attack_done = false
    player_combo = 1 - player_combo
    if hero_tag == "spear":
        player_rig.attack_style = "thrust"
    elif hero_tag == "heavy":
        player_rig.attack_style = "chop"
    else:
        player_rig.attack_style = "slash" if player_combo == 0 else "chop"

    # مساعدة التصويب نحو أقرب عدو
    var best: Actor = null
    var best_d: float = AIM_ASSIST
    for a in actors:
        if a.dead or a.kind == "ally" or a.kind == "npc" or a.kind == "masked":
            continue
        var d: float = _flat_dist(a.node.global_position, player.global_position)
        if d < best_d:
            best_d = d
            best = a
    if best != null:
        var v: Vector3 = best.node.global_position - player.global_position
        player_yaw = atan2(v.x, v.z)


func _apply_player_hit() -> void:
    var forward := Vector3(sin(player_yaw), 0.0, cos(player_yaw))
    for a in actors:
        if a.dead or a.kind == "ally" or a.kind == "npc" or a.kind == "masked":
            continue
        var to_a: Vector3 = a.node.global_position - player.global_position
        to_a.y = 0.0
        var d: float = to_a.length()
        if d <= PLAYER_ATTACK_RANGE + 0.4 and (d < 0.3 or to_a.normalized().dot(forward) > 0.15):
            _damage_actor(a, 1.0, player.global_position, 5.0)


func _damage_actor(a: Actor, amount: float, from_pos: Vector3, knock_power: float) -> void:
    if a.dead:
        return
    a.hp -= amount
    a.rig.hit_flash()
    var away: Vector3 = a.node.global_position - from_pos
    away.y = 0.0
    if away.length() > 0.01 and a.kind != "dummy":
        a.knock = away.normalized() * knock_power
    _float_text(a.node, str(roundi(amount)), Color(1.0, 0.9, 0.4))
    shake = maxf(shake, 0.1)
    if _is_enemy(a) and a.hp > 0.0:
        a.attack_t = 0.0
        a.cooldown = maxf(a.cooldown, 0.6)
        a.stun = 0.3
    if a.hp <= 0.0:
        _kill_actor(a)


func _kill_actor(a: Actor) -> void:
    a.dead = true
    a.rig.die()
    a.node.collision_layer = 0
    a.node.collision_mask = 0
    if _is_enemy(a):
        kills += 1
    elif a.kind == "dummy":
        dummies_down += 1
        _on_dummy_down()


func _damage_player(amount: float, from_pos: Vector3) -> void:
    if state != State.PLAYING or player_hp <= 0.0 or invuln > 0.0:
        return

    var damage_taken: float = amount
    var guarded_hit: bool = false
    var toward_attacker: Vector3 = from_pos - player.global_position
    toward_attacker.y = 0.0
    var facing: Vector3 = Vector3(sin(player_yaw), 0.0, cos(player_yaw))
    if blocking and toward_attacker.length() > 0.01:
        guarded_hit = facing.dot(toward_attacker.normalized()) > 0.0
        if guarded_hit:
            damage_taken *= 0.25

    player_hp = maxf(0.0, player_hp - damage_taken)
    invuln = 0.3 if not guarded_hit else 0.12
    damage_flash = 0.55 if not guarded_hit else 0.18
    shake = maxf(shake, 0.25 if not guarded_hit else 0.08)
    player_rig.hit_flash()

    var away: Vector3 = player.global_position - from_pos
    away.y = 0.0
    if away.length() > 0.01 and not guarded_hit:
        player_knock = away.normalized() * 4.0
    if player_hp <= 0.0:
        _on_player_dead()


func _on_player_dead() -> void:
    player_rig.die()
    _clear_touch()
    state = State.GAME_OVER
    _show_end("سقط أوران", "القتلى: " + str(kills) + "\nيمكنك المحاولة مرة أخرى من آخر نقطة حفظ.", true)


# يُربط الرقم بعقدة الهدف نفسه فيتبعه إن دُفع للخلف
func _float_text(parent: Node3D, text: String, color: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.modulate = color
    l.font_size = 56
    l.pixel_size = 0.006
    l.outline_size = 12
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    parent.add_child(l)
    l.position = Vector3(0.0, 2.1, 0.0)
    var tw := create_tween()
    tw.tween_property(l, "position:y", l.position.y + 1.2, 0.7)
    tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
    tw.tween_callback(l.queue_free)


# --------------------------------------------------
# الشظية
# --------------------------------------------------

func _unlock_shard() -> void:
    shard_unlocked = true
    shard_pad.visible = true
    fatigue_bar.visible = true


func _use_shard() -> void:
    if state != State.PLAYING or not shard_unlocked or shard_cd > 0.0:
        return
    if exhausted:
        _show_message("الشظية مرهقة... انتظر حتى تهدأ", 1.5)
        return

    shard_uses += 1
    shard_cd = 1.2
    shard_idle = 1.6
    fatigue += SHARD_COST
    if fatigue >= 100.0:
        fatigue = 100.0
        exhausted = true
    shake = 0.5
    overlay_flash = 0.45

    for a in actors:
        if a.dead or a.kind == "ally" or a.kind == "npc" or a.kind == "masked":
            continue
        if _flat_dist(a.node.global_position, player.global_position) <= SHARD_RADIUS:
            _damage_actor(a, SHARD_DAMAGE, player.global_position, 11.0)

    _spawn_ring(player.global_position)
    if randf() < 0.3:
        _show_message(Story.MEMORIES[randi() % Story.MEMORIES.size()], 3.0)


func _spawn_ring(pos: Vector3) -> void:
    var ring := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.5
    mesh.bottom_radius = 0.5
    mesh.height = 0.12
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.55, 0.3, 0.95, 0.7)
    mesh.material = mat
    ring.mesh = mesh
    world_root.add_child(ring)
    ring.global_position = Vector3(pos.x, 0.15, pos.z)
    var tw := create_tween()
    tw.tween_property(ring, "scale", Vector3(SHARD_RADIUS * 2.0, 1.0, SHARD_RADIUS * 2.0), 0.4)
    tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
    tw.tween_callback(ring.queue_free)


func _update_shard(delta: float) -> void:
    shard_cd = maxf(0.0, shard_cd - delta)
    if shard_idle > 0.0:
        shard_idle -= delta
    else:
        fatigue = maxf(0.0, fatigue - 9.0 * delta)
    if exhausted and fatigue < 40.0:
        exhausted = false


# --------------------------------------------------
# حركة اللاعب
# --------------------------------------------------

func _update_player(delta: float) -> void:
    _apply_gravity(player, delta)
    invuln = maxf(0.0, invuln - delta)
    dodge_t = maxf(0.0, dodge_t - delta)
    dash_t = maxf(0.0, dash_t - delta)
    player_knock = player_knock * maxf(0.0, 1.0 - delta * 8.0)

    var input_x: float = joy_vector.x
    var input_forward: float = -joy_vector.y
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_x += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_x -= 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        input_forward += 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        input_forward -= 1.0
    input_x = clampf(input_x, -1.0, 1.0)
    input_forward = clampf(input_forward, -1.0, 1.0)

    var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
    var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
    var direction: Vector3 = right * input_x + forward * input_forward
    if direction.length() > 1.0:
        direction = direction.normalized()
    if dodge_t > 0.0:
        direction = dodge_direction
    elif dash_t > 0.0:
        direction = dash_direction

    # الكاميرا تدور تدريجيًا لتبقى خلف الشخصية أثناء الحركة (إلا بعد سحب يدوي)
    cam_manual_t = maxf(0.0, cam_manual_t - delta)
    if direction.length() > 0.1 and cam_manual_t <= 0.0 and attack_t <= 0.0 and input_forward > -0.2:
        var follow: float = clampf(maxf(input_forward, 0.0) + absf(input_x) * 0.35, 0.0, 1.0)
        camera_yaw = lerp_angle(camera_yaw, player_yaw + PI, clampf(delta * 2.4 * follow, 0.0, 1.0))

    var sprint: bool = running or Input.is_key_pressed(KEY_SHIFT)
    var speed: float = PLAYER_SPEED
    if blocking:
        speed *= 0.35
    if dodge_t > 0.0:
        speed = 10.0
    elif dash_t > 0.0:
        speed = 13.5
    elif sprint:
        speed *= 1.6
    if attack_t > 0.0:
        speed *= 0.35
    if exhausted:
        speed *= 0.75

    var vel: Vector3 = direction * speed + player_knock
    player.velocity.x = vel.x
    player.velocity.z = vel.z

    var moving: bool = direction.length() > 0.1 and attack_t <= 0.0
    player_rig.move_speed = (direction * speed).length() if direction.length() > 0.1 else 0.0
    if moving:
        player_yaw = lerp_angle(player_yaw, atan2(direction.x, direction.z), clampf(delta * 14.0, 0.0, 1.0))
    player_yaw_node.rotation.y = player_yaw

    player.move_and_slide()
    if player.position.y < -5.0:
        player.position = Story.PLAYER_START if story_mode else Vector3(0.0, 0.05, 10.0)
        player.velocity = Vector3.ZERO

    # حدود الملعب
    var flat := Vector2(player.position.x, player.position.z)
    if flat.length() > WORLD_RADIUS:
        flat = flat.normalized() * WORLD_RADIUS
        player.position.x = flat.x
        player.position.z = flat.y

    if attack_t > 0.0:
        attack_t = maxf(0.0, attack_t - delta)
        if not attack_done and _attack_p(attack_t) >= 0.5:
            attack_done = true
            _apply_player_hit()

    player_rig.animate(delta, moving, sprint and moving, _attack_p(attack_t), false, blocking, dodge_t > 0.0, dash_t > 0.0)


func _movement_direction() -> Vector3:
    var input_x: float = joy_vector.x
    var input_forward: float = -joy_vector.y
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_x += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_x -= 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        input_forward += 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        input_forward -= 1.0
    input_x = clampf(input_x, -1.0, 1.0)
    input_forward = clampf(input_forward, -1.0, 1.0)
    var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
    var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
    var direction: Vector3 = right * input_x + forward * input_forward
    if direction.length() > 1.0:
        direction = direction.normalized()
    return direction


func _toggle_running() -> void:
    if state != State.PLAYING or dodge_t > 0.0 or dash_t > 0.0:
        return
    running = not running
    if running and blocking:
        blocking = false
        _refresh_block_pad()
    _refresh_run_pad()


func _toggle_block() -> void:
    if state != State.PLAYING or attack_t > 0.0 or dodge_t > 0.0 or dash_t > 0.0:
        return
    blocking = not blocking
    if blocking:
        running = false
        _refresh_run_pad()
    _refresh_block_pad()


func _start_dodge() -> void:
    if state != State.PLAYING or attack_t > 0.0 or dodge_t > 0.0 or dash_t > 0.0:
        return
    blocking = false
    running = false
    dodge_direction = _movement_direction()
    if dodge_direction.length() < 0.1:
        dodge_direction = Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
    dodge_t = 0.42
    invuln = maxf(invuln, 0.32)
    _refresh_run_pad()
    _refresh_block_pad()


func _start_dash() -> void:
    if state != State.PLAYING or attack_t > 0.0 or dodge_t > 0.0 or dash_t > 0.0:
        return
    blocking = false
    running = false
    dash_direction = _movement_direction()
    if dash_direction.length() < 0.1:
        dash_direction = Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
    dash_t = 0.30
    _refresh_run_pad()
    _refresh_block_pad()


func _refresh_run_pad() -> void:
    if not is_instance_valid(run_pad):
        return
    var l: Label = run_pad.get_child(0) as Label
    if l != null:
        l.text = "ركض ✓" if running else "ركض"


func _refresh_block_pad() -> void:
    if not is_instance_valid(block_pad):
        return
    var l: Label = block_pad.get_child(0) as Label
    if l != null:
        l.text = "صدّ ✓" if blocking else "صدّ"


# --------------------------------------------------
# الحلقة الرئيسية
# --------------------------------------------------

func _physics_process(delta: float) -> void:
    time_passed += delta
    if state == State.PAUSED or state == State.GAME_OVER:
        return

    if state == State.PLAYING:
        _update_player(delta)
        _update_actors(delta)
        _update_projectiles(delta)
        _update_shard(delta)
        if story_mode:
            _story_update(delta)
        else:
            _free_update(delta)
    else:
        player_rig.move_speed = 0.0
        player_rig.animate(delta, false, false, -1.0)
        for a in actors:
            if not a.dead and is_instance_valid(a.node):
                a.rig.move_speed = 0.0
                a.rig.animate(delta, false, false, -1.0)

    shake = maxf(0.0, shake - delta * 1.6)
    damage_flash = maxf(0.0, damage_flash - delta * 1.5)
    overlay_flash = maxf(0.0, overlay_flash - delta * 1.2)
    if message_timer > 0.0:
        message_timer -= delta
        if message_timer <= 0.0:
            message_label.visible = false

    _update_camera(delta)


func _process(_delta: float) -> void:
    if hud_root == null:
        return
    hp_bar.value = player_hp
    fatigue_bar.value = fatigue
    var fill: StyleBoxFlat = fatigue_bar.get_theme_stylebox("fill") as StyleBoxFlat
    if fill != null:
        fill.bg_color = UI.DANGER if exhausted else UI.SHARD
    vignette.color = Color(0.8, 0.05, 0.05, damage_flash * 0.6)
    flash_rect.color = Color(0.5, 0.25, 0.9, overlay_flash * 0.5)

    if story_mode:
        info_label.text = "الأعداء: " + str(_enemies_alive()) + "   |   القتلى: " + str(kills)
    else:
        info_label.text = "الموجة: " + str(wave) + "   |   الأعداء: " + str(_enemies_alive()) + "   |   القتلى: " + str(kills)

    if marker_active and state == State.PLAYING:
        distance_label.text = str(roundi(_flat_dist(player.global_position, marker_pos))) + " م"
        distance_label.visible = true
        compass.visible = true
        compass.queue_redraw()
    else:
        distance_label.visible = false
        compass.visible = false
    joy_pad.queue_redraw()


# --------------------------------------------------
# الإدخال
# --------------------------------------------------

func _press_pad(pos: Vector2) -> bool:
    for p in pads:
        var ctrl: Control = p["ctrl"]
        if ctrl.is_visible_in_tree() and ctrl.get_global_rect().grow(10.0).has_point(pos):
            var cb: Callable = p["cb"]
            cb.call()
            return true
    return false


func _clear_touch() -> void:
    joy_index = -1
    joy_vector = Vector2.ZERO
    cam_index = -1
    mouse_look = false


func _input(event: InputEvent) -> void:
    if state != State.PLAYING:
        return

    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if _press_pad(t.position):
                return
            var half: float = get_viewport().get_visible_rect().size.x * 0.5
            if t.position.x < half:
                if joy_index == -1:
                    joy_index = t.index
                    joy_origin = t.position
                    joy_vector = Vector2.ZERO
            elif cam_index == -1:
                cam_index = t.index
        else:
            if t.index == joy_index:
                joy_index = -1
                joy_vector = Vector2.ZERO
            if t.index == cam_index:
                cam_index = -1

    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == joy_index:
            var offset: Vector2 = d.position - joy_origin
            if offset.length() > JOY_RADIUS:
                offset = offset.normalized() * JOY_RADIUS
            var v: Vector2 = offset / JOY_RADIUS
            joy_vector = Vector2.ZERO if v.length() < 0.12 else v
        elif d.index == cam_index:
            _rotate_camera(d.relative)

    elif event is InputEventMouseButton:
        var m := event as InputEventMouseButton
        # الأحداث المحاكاة من اللمس تُتجاهل حتى لا يتكرر التنفيذ
        if m.device == InputEvent.DEVICE_ID_EMULATION:
            return
        if m.button_index == MOUSE_BUTTON_LEFT and m.pressed:
            if not _press_pad(m.position):
                _player_attack()
        elif m.button_index == MOUSE_BUTTON_RIGHT:
            mouse_look = m.pressed

    elif event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        if mm.device == InputEvent.DEVICE_ID_EMULATION:
            return
        if mouse_look:
            _rotate_camera(mm.relative)


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var k := event as InputEventKey
    if not k.pressed or k.echo:
        return

    if state == State.DIALOGUE:
        if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
            _advance_dialogue()
        return

    if k.keycode == KEY_ESCAPE:
        if state == State.PLAYING:
            _pause()
        elif state == State.PAUSED:
            _resume()
        return

    if state != State.PLAYING:
        return
    if k.keycode == KEY_SPACE:
        _player_attack()
    elif k.keycode == KEY_F:
        _use_shard()
    elif k.keycode == KEY_G:
        _toggle_block()
    elif k.keycode == KEY_C:
        _start_dodge()
    elif k.keycode == KEY_X:
        _start_dash()
    elif k.keycode == KEY_Q:
        camera_yaw += 0.2
    elif k.keycode == KEY_E:
        camera_yaw -= 0.2


# --------------------------------------------------
# الواجهة
# --------------------------------------------------

func _place(c: Control, left_side: bool, bottom: bool, x: float, y: float, w: float, h: float) -> void:
    var ax: float = 0.0 if left_side else 1.0
    var ay: float = 1.0 if bottom else 0.0
    c.anchor_left = ax
    c.anchor_right = ax
    c.anchor_top = ay
    c.anchor_bottom = ay
    if left_side:
        c.offset_left = x
        c.offset_right = x + w
    else:
        c.offset_left = -x - w
        c.offset_right = -x
    if bottom:
        c.offset_top = -y - h
        c.offset_bottom = -y
    else:
        c.offset_top = y
        c.offset_bottom = y + h


func _new_root(parent: Control) -> Control:
    var c := Control.new()
    UI.full_rect(c)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(c)
    return c


func _make_pad(text: String, w: float, h: float, round_shape: bool, color: Color, cb: Callable) -> Panel:
    var p := Panel.new()
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var radius: int = int(minf(w, h) * 0.5) if round_shape else 12
    p.add_theme_stylebox_override("panel", UI.box(color, radius, Color(1, 1, 1, 0.4), 2, 0.0))
    var l := UI.label(text, 22, UI.TEXT)
    UI.full_rect(l)
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(l)
    pad_group.add_child(p)
    pads.append({"ctrl": p, "cb": cb})
    return p


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    ui_root = Control.new()
    UI.full_rect(ui_root)
    ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
    ui_root.theme = UI.make_theme()
    layer.add_child(ui_root)

    _build_hud()
    _build_dialogue()
    _build_card()
    _build_pause()
    _build_end()


func _build_hud() -> void:
    hud_root = _new_root(ui_root)

    vignette = ColorRect.new()
    UI.full_rect(vignette)
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vignette.color = Color(0, 0, 0, 0)
    hud_root.add_child(vignette)

    flash_rect = ColorRect.new()
    UI.full_rect(flash_rect)
    flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash_rect.color = Color(0, 0, 0, 0)
    hud_root.add_child(flash_rect)

    joy_pad = Control.new()
    UI.full_rect(joy_pad)
    joy_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joy_pad.draw.connect(_draw_joystick)
    hud_root.add_child(joy_pad)

    # كل عناصر الواجهة تُوضع داخل safe_root حتى لا تُقصّ بفعل الحواف/النتوء في الهاتف
    safe_root = _new_root(hud_root)

    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.position = Vector2(14.0, 14.0)
    panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.4), 10, Color(0, 0, 0, 0), 0, 8.0))
    safe_root.add_child(panel)
    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_theme_constant_override("separation", 4)
    panel.add_child(box)

    info_label = Label.new()
    info_label.add_theme_font_size_override("font_size", 16)
    box.add_child(info_label)
    hp_bar = UI.bar(240.0, 16.0, Color("#c9453a"))
    hp_bar.max_value = PLAYER_MAX_HP
    box.add_child(hp_bar)
    fatigue_bar = UI.bar(240.0, 10.0, UI.SHARD)
    fatigue_bar.max_value = 100.0
    fatigue_bar.visible = false
    box.add_child(fatigue_bar)

    # الهدف في أعلى الوسط
    var obj_box := VBoxContainer.new()
    obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    obj_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    obj_box.offset_left = -300.0
    obj_box.offset_right = 300.0
    obj_box.offset_top = 10.0
    obj_box.add_theme_constant_override("separation", 2)
    safe_root.add_child(obj_box)

    objective_label = UI.label("", 20, UI.GOLD)
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UI.outline(objective_label, 5)
    obj_box.add_child(objective_label)

    compass = Control.new()
    compass.custom_minimum_size = Vector2(40.0, 40.0)
    compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
    compass.draw.connect(_draw_compass)
    obj_box.add_child(compass)

    distance_label = UI.label("", 16, UI.TEXT)
    UI.outline(distance_label, 4)
    obj_box.add_child(distance_label)

    message_label = UI.label("", 30, UI.TEXT)
    message_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    message_label.offset_top = 190.0
    message_label.offset_bottom = 250.0
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.outline(message_label, 8)
    message_label.visible = false
    safe_root.add_child(message_label)

    pad_group = _new_root(safe_root)
    var attack_pad: Panel = _make_pad("هجوم", 120.0, 120.0, true, Color(0.7, 0.2, 0.18, 0.75), _player_attack)
    _place(attack_pad, false, true, 28.0, 28.0, 120.0, 120.0)
    run_pad = _make_pad("ركض", 84.0, 84.0, true, Color(0.2, 0.3, 0.45, 0.75), _toggle_running)
    _place(run_pad, false, true, 168.0, 28.0, 84.0, 84.0)
    block_pad = _make_pad("صدّ", 76.0, 76.0, true, Color(0.15, 0.35, 0.5, 0.82), _toggle_block)
    _place(block_pad, false, true, 264.0, 28.0, 76.0, 76.0)
    var dodge_pad: Panel = _make_pad("تفادٍ", 76.0, 76.0, true, Color(0.2, 0.45, 0.3, 0.82), _start_dodge)
    _place(dodge_pad, false, true, 264.0, 116.0, 76.0, 76.0)
    var dash_pad: Panel = _make_pad("اندفاع", 76.0, 76.0, true, Color(0.62, 0.38, 0.12, 0.82), _start_dash)
    _place(dash_pad, false, true, 168.0, 116.0, 76.0, 76.0)
    shard_pad = _make_pad("الشظية", 92.0, 92.0, true, Color(0.4, 0.22, 0.75, 0.8), _use_shard)
    _place(shard_pad, false, true, 56.0, 164.0, 92.0, 92.0)
    shard_pad.visible = false
    var pause_pad: Panel = _make_pad("القائمة", 110.0, 44.0, false, Color(0, 0, 0, 0.55), _pause)
    _place(pause_pad, false, false, 14.0, 14.0, 110.0, 44.0)
    _apply_safe_area()
    get_viewport().size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
    var left: float = 0.0
    var top: float = 0.0
    var right: float = 0.0
    var bottom: float = 0.0
    # المنطقة الآمنة تُستخدم على الهواتف فقط (على الحاسوب تعني شريط المهام)
    if OS.has_feature("mobile"):
        var win: Vector2i = DisplayServer.window_get_size()
        var safe: Rect2i = DisplayServer.get_display_safe_area()
        if win.x > 0 and win.y > 0 and safe.size.x > 0 and safe.size.y > 0:
            var view: Vector2 = get_viewport().get_visible_rect().size
            var sx: float = view.x / float(win.x)
            var sy: float = view.y / float(win.y)
            left = clampf(float(safe.position.x) * sx, 0.0, 140.0)
            top = clampf(float(safe.position.y) * sy, 0.0, 140.0)
            right = clampf(float(win.x - safe.position.x - safe.size.x) * sx, 0.0, 140.0)
            bottom = clampf(float(win.y - safe.position.y - safe.size.y) * sy, 0.0, 140.0)
    safe_root.offset_left = left
    safe_root.offset_top = top
    safe_root.offset_right = -right
    safe_root.offset_bottom = -bottom


func _draw_joystick() -> void:
    if joy_index == -1:
        return
    joy_pad.draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.14))
    joy_pad.draw_circle(joy_origin + joy_vector * JOY_RADIUS, 38.0, Color(1, 1, 1, 0.5))


func _draw_compass() -> void:
    if not marker_active:
        return
    var to_m: Vector3 = marker_pos - player.global_position
    var dir := Vector2(to_m.x, to_m.z)
    if dir.length() < 0.01:
        return
    var f := Vector2(-sin(camera_yaw), -cos(camera_yaw))
    var r := Vector2(cos(camera_yaw), -sin(camera_yaw))
    var angle: float = atan2(dir.dot(r), dir.dot(f))
    var c := Vector2(20.0, 20.0)
    var pts := PackedVector2Array([Vector2(0, -16), Vector2(11, 12), Vector2(0, 6), Vector2(-11, 12)])
    for i in pts.size():
        pts[i] = c + pts[i].rotated(angle)
    compass.draw_colored_polygon(pts, UI.GOLD)


func _build_dialogue() -> void:
    dialogue_root = _new_root(ui_root)
    dialogue_root.visible = false

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    panel.offset_left = -440.0
    panel.offset_right = 440.0
    panel.offset_top = -230.0
    panel.offset_bottom = -20.0
    panel.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.08, 0.12, 0.92), 14, Color(0.83, 0.69, 0.41, 0.6), 2, 16.0))
    dialogue_root.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)

    dialogue_speaker = UI.label("", 24, UI.GOLD)
    box.add_child(dialogue_speaker)

    dialogue_text = UI.label("", 21, UI.TEXT)
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text.custom_minimum_size = Vector2(800.0, 80.0)
    dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    box.add_child(dialogue_text)

    var next := UI.button("متابعة ◀", 160.0, 46.0, true, 20)
    next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    next.pressed.connect(_advance_dialogue)
    box.add_child(next)


func _build_card() -> void:
    card_root = _new_root(ui_root)
    card_root.visible = false
    var dim := ColorRect.new()
    UI.full_rect(dim)
    dim.color = Color(0.03, 0.04, 0.07, 0.94)
    card_root.add_child(dim)

    var center := CenterContainer.new()
    UI.full_rect(center)
    card_root.add_child(center)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 18)
    center.add_child(box)

    card_title = UI.label("", 44, UI.GOLD)
    UI.outline(card_title, 6)
    box.add_child(card_title)
    card_body = UI.label("", 22, UI.TEXT)
    card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card_body.custom_minimum_size = Vector2(720.0, 0.0)
    box.add_child(card_body)
    card_button = UI.button("متابعة", 260.0, 56.0, true)
    card_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    card_button.pressed.connect(_on_card_pressed)
    box.add_child(card_button)


func _build_pause() -> void:
    pause_root = _new_root(ui_root)
    pause_root.visible = false
    var dim := ColorRect.new()
    UI.full_rect(dim)
    dim.color = Color(0, 0, 0, 0.6)
    pause_root.add_child(dim)
    var center := CenterContainer.new()
    UI.full_rect(center)
    pause_root.add_child(center)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)
    box.add_child(UI.label("متوقف مؤقتًا", 36, UI.GOLD))
    var resume := UI.button("متابعة", 280.0, 56.0, true)
    resume.pressed.connect(_resume)
    box.add_child(resume)
    var restart := UI.button("إعادة المحاولة", 280.0, 52.0)
    restart.pressed.connect(_restart)
    box.add_child(restart)
    var menu := UI.button("القائمة الرئيسية", 280.0, 52.0)
    menu.pressed.connect(_to_menu)
    box.add_child(menu)


func _build_end() -> void:
    end_root = _new_root(ui_root)
    end_root.visible = false
    var dim := ColorRect.new()
    UI.full_rect(dim)
    dim.color = Color(0.03, 0.04, 0.07, 0.9)
    end_root.add_child(dim)
    var center := CenterContainer.new()
    UI.full_rect(center)
    end_root.add_child(center)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 16)
    center.add_child(box)
    end_title = UI.label("", 40, UI.GOLD)
    UI.outline(end_title, 6)
    box.add_child(end_title)
    end_info = UI.label("", 21, UI.TEXT)
    end_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    end_info.custom_minimum_size = Vector2(640.0, 0.0)
    box.add_child(end_info)
    end_retry = UI.button("إعادة المحاولة", 280.0, 56.0, true)
    end_retry.pressed.connect(_restart)
    box.add_child(end_retry)
    var menu := UI.button("القائمة الرئيسية", 280.0, 52.0)
    menu.pressed.connect(_to_menu)
    box.add_child(menu)


func _show_end(title_text: String, info: String, retry: bool) -> void:
    end_title.text = title_text
    end_info.text = info
    end_retry.visible = retry
    hud_root.visible = false
    end_root.visible = true


func _pause() -> void:
    if state != State.PLAYING:
        return
    _clear_touch()
    state = State.PAUSED
    pause_root.visible = true


func _resume() -> void:
    if state != State.PAUSED:
        return
    state = State.PLAYING
    pause_root.visible = false


func _restart() -> void:
    get_tree().reload_current_scene()


func _to_menu() -> void:
    get_tree().change_scene_to_file(MAIN_SCENE)


func _show_message(text: String, seconds: float) -> void:
    message_label.text = text
    message_label.visible = true
    message_timer = seconds


func _set_objective(text: String) -> void:
    objective_label.text = text


# --------------------------------------------------
# الحوار والبطاقات
# --------------------------------------------------

func _start_dialogue(lines: Array, on_done: Callable) -> void:
    dlg_lines = lines
    dlg_index = 0
    dlg_done = on_done
    _clear_touch()
    state = State.DIALOGUE
    pad_group.visible = false
    dialogue_root.visible = true
    _show_dialogue_line()


func _show_dialogue_line() -> void:
    var line: Dictionary = dlg_lines[dlg_index]
    var speaker: String = String(line.get("s", ""))
    dialogue_speaker.text = speaker
    dialogue_speaker.visible = speaker != ""
    dialogue_text.text = String(line.get("t", ""))


func _advance_dialogue() -> void:
    if state != State.DIALOGUE:
        return
    dlg_index += 1
    if dlg_index >= dlg_lines.size():
        dialogue_root.visible = false
        pad_group.visible = true
        state = State.PLAYING
        if dlg_done.is_valid():
            dlg_done.call()
    else:
        _show_dialogue_line()


func _show_card(title_text: String, body: String, button_text: String, on_press: Callable) -> void:
    _clear_touch()
    state = State.CARD
    card_title.text = title_text
    card_body.text = body
    card_button.text = button_text
    card_done = on_press
    pad_group.visible = false
    card_root.visible = true


func _on_card_pressed() -> void:
    card_root.visible = false
    pad_group.visible = true
    state = State.PLAYING
    if card_done.is_valid():
        card_done.call()


# --------------------------------------------------
# الموجات
# --------------------------------------------------

func _spawn_wave(tags: Array, hp_mult: float = 1.0) -> void:
    var n: int = tags.size()
    for i in n:
        var entry: Dictionary = Catalog.pick(characters, String(tags[i]), i + wave, hero_path)
        if entry.is_empty():
            entry = {"hp": 3.0, "speed": 2.4, "damage": 8.0, "reach": 1.9, "cooldown": 1.4, "tag": "infantry"}
        var t: float = (float(i) + 0.5) / float(n)
        var angle: float = lerpf(PI * 0.3, PI * 0.7, t) + randf_range(-0.05, 0.05)
        var pos := Vector3(cos(angle) * 31.0, 0.05, sin(angle) * 31.0)
        var kind: String = "ranged" if String(entry.get("tag", "")) == "archer" else "melee"
        _spawn_actor(entry, pos, kind, hp_mult)


# --------------------------------------------------
# المعركة الحرة
# --------------------------------------------------

func _begin_free() -> void:
    _unlock_shard()
    _set_objective("")
    objective_label.visible = false
    state = State.PLAYING
    _spawn_free_wave()


func _spawn_free_wave() -> void:
    var pool: Array = ["infantry", "spear", "shield", "archer", "heavy", "spear", "infantry"]
    var tags: Array = []
    var count: int = 3 + wave
    for i in count:
        tags.append(pool[randi() % pool.size()])
    _spawn_wave(tags, 1.0 + 0.15 * float(wave - 1))
    _show_message("الموجة " + str(wave), 2.0)


func _free_update(delta: float) -> void:
    if wave_break > 0.0:
        wave_break -= delta
        if wave_break <= 0.0:
            _spawn_free_wave()
        return
    if _enemies_alive() == 0:
        wave += 1
        player_hp = minf(PLAYER_MAX_HP, player_hp + 20.0)
        wave_break = 3.0
        _show_message("اكتملت الموجة! الموجة التالية بعد قليل", 2.8)


# --------------------------------------------------
# القصة: الفصل الأول (نَمار)
# --------------------------------------------------

func _begin_story() -> void:
    var kuri_entry: Dictionary = Catalog.pick(characters, "shield", 0, hero_path)
    kuri = _spawn_actor(kuri_entry, Story.KURI_POS, "npc")
    kuri.hp = 9999.0
    kuri.node.collision_mask = 1 | 4
    kuri.yaw = PI
    kuri.yaw_node.rotation.y = PI
    camera_yaw = 0.0
    _set_step(Session.story_checkpoint)


func _save_checkpoint(s: int) -> void:
    Session.story_checkpoint = s
    Session.save_data()


func _queue_step(s: int, delay: float) -> void:
    pending_step = s
    pending_delay = delay


func _near_marker() -> bool:
    return marker_active and _flat_dist(player.global_position, marker_pos) < marker_radius


func _set_step(s: int) -> void:
    step = s
    pending_step = -1
    match s:
        Step.PROLOGUE:
            _set_objective("")
            _show_card(Story.PROLOGUE_TITLE, Story.PROLOGUE_TEXT, "ابدأ", func(): _set_step(Step.GO_MARKET))
        Step.GO_MARKET:
            _set_objective("اذهب إلى السوق وتحدّث مع الحارس كوري")
            _set_marker(Story.KURI_POS)
            _show_message("اسحب في الجهة اليسرى للحركة، وفي اليمنى لتدوير الكاميرا", 7.0)
        Step.TRAINING:
            _clear_marker()
            dummies_down = 0
            for pos in Story.DUMMY_POS:
                var dummy: Actor = _spawn_actor({"hp": 3.0}, pos, "dummy")
                dummy.yaw = PI * 0.25
                dummy.yaw_node.rotation.y = dummy.yaw
            _set_objective("حطّم دمى التدريب بزر الهجوم (0/3)")
        Step.RETURN_GUARD:
            _set_objective("عُد إلى كوري")
            _set_marker(Story.KURI_POS)
        Step.WAVE1:
            _clear_marker()
            _save_checkpoint(Step.WAVE1)
            kuri.kind = "ally"
            overlay_flash = 0.0
            damage_flash = 0.5
            shake = 0.6
            _show_message("هجوم على نَمار!", 3.0)
            _set_objective("دافع عن السوق: الموجة 1 من 2")
            _spawn_wave(["spear", "infantry", "archer"])
        Step.WAVE2:
            _set_objective("دافع عن السوق: الموجة 2 من 2")
            _show_message(Story.WAVE_CLEAR_1, 3.0)
            _spawn_wave(["heavy", "spear", "infantry", "archer"])
        Step.SHARD:
            _save_checkpoint(Step.SHARD)
            kuri.kind = "ally"
            _set_objective("")
            _start_dialogue(Story.SHARD_LINES, func(): _set_step(Step.SHARD_TRIAL))
        Step.SHARD_TRIAL:
            _unlock_shard()
            trial_extra_spawned = false
            _set_objective("اضغط زر الشظية لصدّ المهاجمين الأخيرين")
            _show_message("زر الشظية يظهر أسفل اليمين (أو اضغط F)", 4.0)
            _spawn_wave(["infantry", "infantry", "spear"], 0.8)
        Step.MASKED:
            _unlock_shard()
            _save_checkpoint(Step.MASKED)
            kuri.kind = "npc"
            var m_entry: Dictionary = Catalog.pick(characters, "spear", 1, hero_path)
            masked = _spawn_actor(m_entry, Story.MASKED_POS, "masked")
            masked.hp = 9999.0
            _set_objective("اقترب من الغريب على حافة السوق")
            _set_marker(Story.MASKED_POS, 4.5)
        Step.END:
            _clear_marker()
            _set_objective("")
            _save_checkpoint(0)
            var info: String = Story.END_TEXT + "\n\nالقتلى: " + str(kills) + "   |   الزمن: " + str(roundi(time_passed)) + " ثانية"
            _show_card(Story.END_TITLE, info, "القائمة الرئيسية", _to_menu)


func _on_dummy_down() -> void:
    if step != Step.TRAINING:
        return
    _set_objective("حطّم دمى التدريب بزر الهجوم (" + str(dummies_down) + "/3)")
    if dummies_down >= 3:
        _queue_step(Step.RETURN_GUARD, 1.2)


func _story_update(delta: float) -> void:
    if pending_step >= 0:
        pending_delay -= delta
        if pending_delay <= 0.0:
            _set_step(pending_step)
        return

    match step:
        Step.GO_MARKET:
            if _near_marker():
                _clear_marker()
                _start_dialogue(Story.KURI_INTRO, func(): _set_step(Step.TRAINING))
        Step.RETURN_GUARD:
            if _near_marker():
                _clear_marker()
                _start_dialogue(Story.KURI_AFTER_TRAINING, func(): _set_step(Step.WAVE1))
        Step.WAVE1:
            if _enemies_alive() == 0:
                _queue_step(Step.WAVE2, 1.5)
        Step.WAVE2:
            if _enemies_alive() == 0:
                _queue_step(Step.SHARD, 1.5)
        Step.SHARD_TRIAL:
            if _enemies_alive() == 0:
                if shard_uses > 0:
                    _queue_step(Step.MASKED, 1.5)
                elif not trial_extra_spawned:
                    trial_extra_spawned = true
                    _show_message("جرّب زر الشظية!", 3.0)
                    _spawn_wave(["infantry", "infantry"], 0.8)
        Step.MASKED:
            if _near_marker():
                _clear_marker()
                _start_dialogue(Story.MASKED_LINES, _masked_leaves)


func _masked_leaves() -> void:
    if masked != null and is_instance_valid(masked.yaw_node):
        var tw := create_tween()
        tw.tween_property(masked.yaw_node, "scale", Vector3(0.01, 0.01, 0.01), 0.9)
        tw.tween_callback(func(): _set_step(Step.END))
    else:
        _set_step(Step.END)
