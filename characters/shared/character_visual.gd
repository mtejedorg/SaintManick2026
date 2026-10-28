extends MeshInstance3D
class_name CharacterVisual

## Shared character visual root: owns the base material policy and the per-instance neon
## rim overlay for every child mesh of the instanced model.
##
## Base material policy:
##   tint == WHITE  -> keep the model's own imported materials/textures. Never overridden.
##   any other tint -> ONE dark base material (near-black, 18 % toward the tint) on every
##                     child mesh. Feedback (telegraph, vulnerable, phase change) is carried
##                     by the RIM, never by swapping base materials.
@export var tint: Color = Color.WHITE

## Selects the default rim colour: PLAYER -> cyan #00F5FF, ENEMY -> magenta #FF00AA.
enum Faction { PLAYER, ENEMY }
@export var faction: Faction = Faction.ENEMY
## Rim colour override. Alpha 0 (the default) means "use the faction colour".
@export var rim_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var rim_strength: float = 3.0
## Idle hover for floating models (Sniper drone): sine bob of the Pivot, +/- amplitude
## metres at hover_hz. 0 = no hover.
@export var hover_amplitude: float = 0.0
@export var hover_hz: float = 1.0
## R1: auto-play (and LOOP_LINEAR) the model's first clip when no controller drives it.
## Off for the shared rigged enemy body: its library is Nick's, whose first clip is
## attack_combo, and the EnemyAnimator owns playback there. Never touches a clip whose
## owner has a PlayerAnimationController (the library is shared, so a loop mode set here
## would leak into Nick's one-shot swings).
@export var auto_play_clip: bool = true
## R4: surface indices removed from every child mesh at load. A surface override cannot hide
## geometry from the per-instance rim overlay (material_overlay draws every surface), so
## stray surfaces (Enforcer_Hammer.glb's 280-tri "Wire" surface 1) are dropped instead.
@export var stripped_surfaces: PackedInt32Array = PackedInt32Array()

const PLAYER_RIM_COLOR := Color(0.0, 0.960784, 1.0, 1.0)     # #00F5FF cyan
const ENEMY_RIM_COLOR := Color(1.0, 0.0, 0.666667, 1.0)      # #FF00AA magenta
## Shared telegraph language: a white-hot rim one beat before the hit.
const TELEGRAPH_RIM_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const TELEGRAPH_RIM_STRENGTH := 6.0
## Vulnerable window (post-attack recovery / shield break).
const VULNERABLE_RIM_COLOR := Color(0.2, 0.6, 1.0, 1.0)

## Death presentation (F3): white-hot rim while the body shrinks away.
const DEATH_RIM_STRENGTH := 6.0
## Shrink target as a fraction of the authored scale — a true zero basis is singular
## (rotation/inverse queries on it error out), and 0.1 % is invisible.
const DEATH_SCALE_FRACTION := 0.001

const DARK_BASE_ALBEDO := Color(0.05, 0.05, 0.08, 1.0)
const DARK_BASE_TINT_WEIGHT := 0.18
const DARK_BASE_ROUGHNESS := 0.55

const RIM_MATERIAL := preload("res://assets/shaders/neon_rim_material.tres")

var skinned_meshes: Array[MeshInstance3D] = []
## Generated meshes exported without a normal array (headliner_brutalizer_raw.glb) make the
## rim fresnel saturate (NORMAL = 0 -> the whole body glows). Their normals are generated
## once per source mesh and shared by every instance.
static var _normal_fixed_meshes: Dictionary = {}
## The dark base material (null for a WHITE tint — the model keeps its own materials).
var base_material: StandardMaterial3D = null
## Per-instance rim overlay so changing one character's rim never touches another's.
var _rim_material_instance: ShaderMaterial = null
## The rim the character returns to after a flash (changed by update_rim_color/strength).
var _base_rim_color: Color
var _base_rim_strength: float
var _rim_tween: Tween = null
## Optional child named "Pivot" carrying the model's placement (scale + feet offset). Unrigged
## models get their procedural motion (beat squash, telegraph lean) on it, about the feet,
## so the root keeps its authored transform.
var pivot: Node3D = null
var _pivot_base_scale: Vector3 = Vector3.ONE
var _pivot_base_rotation: Vector3 = Vector3.ZERO
var _pulse_tween: Tween = null
var _lean_tween: Tween = null
var _hover_tween: Tween = null

func _ready() -> void:
	skinned_meshes.clear()
	_find_mesh_instances_recursive(self)
	for sm in skinned_meshes:
		_strip_surfaces(sm)
		_ensure_normals(sm)
	pivot = get_node_or_null("Pivot") as Node3D
	if pivot:
		_pivot_base_scale = pivot.scale
		_pivot_base_rotation = pivot.rotation
		if hover_amplitude > 0.0 and hover_hz > 0.0:
			_start_hover()

	if tint != Color.WHITE:
		base_material = StandardMaterial3D.new()
		base_material.albedo_color = DARK_BASE_ALBEDO.lerp(tint, DARK_BASE_TINT_WEIGHT)
		base_material.roughness = DARK_BASE_ROUGHNESS
		base_material.metallic = 0.0
		base_material.emission_enabled = false
		for sm in skinned_meshes:
			sm.material_override = base_material

	_base_rim_color = get_default_rim_color()
	_base_rim_strength = rim_strength
	_rim_material_instance = RIM_MATERIAL.duplicate() as ShaderMaterial
	_rim_material_instance.set_shader_parameter("rim_color", _base_rim_color)
	_rim_material_instance.set_shader_parameter("rim_strength", _base_rim_strength)
	for sm in skinned_meshes:
		sm.material_overlay = _rim_material_instance

	var anim_player := _find_animation_player_recursive(self)
	var driven := owner != null and owner.has_node("PlayerAnimationController")
	if anim_player and auto_play_clip and not driven:
		# Auto-play the model's own clip only when no controller drives it.
		var anim_list := anim_player.get_animation_list()
		if anim_list.size() > 0:
			var clip_name: String = "Animation" if "Animation" in anim_list else anim_list[0]
			var anim := anim_player.get_animation(clip_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(clip_name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_surface_overrides()

## T3: drop the per-instance surface overrides before the node tree is torn down. Freeing a
## Nick body and an enemy body on the shared rigged mesh in one go made the dummy (headless)
## renderer query a material it had already released ("Parameter material is null" x17 in the
## test log); the real renderer never complained. Children are still alive in PREDELETE.
func _release_surface_overrides() -> void:
	for sm in skinned_meshes:
		if is_instance_valid(sm) and sm.mesh != null:
			for i in sm.mesh.get_surface_count():
				if sm.get_surface_override_material(i) != null:
					sm.set_surface_override_material(i, null)

func _find_mesh_instances_recursive(node: Node) -> void:
	for child in node.get_children():
		# T6: a mesh riding a BoneAttachment3D (Nick's emissive bionic arm) is an accessory with
		# its own look -- no tint override, no rim overlay.
		if child is MeshInstance3D and not (child.get_parent() is BoneAttachment3D):
			skinned_meshes.append(child)
		_find_mesh_instances_recursive(child)

func _strip_surfaces(sm: MeshInstance3D) -> void:
	var src := sm.mesh
	if stripped_surfaces.is_empty() or src == null or sm.skin != null:
		return
	var keep: Array[int] = []
	for s in src.get_surface_count():
		if not stripped_surfaces.has(s):
			keep.append(s)
	if keep.size() == src.get_surface_count():
		return
	var overrides: Array[Material] = []
	for s in keep:
		overrides.append(sm.get_surface_override_material(s))
	# Per instance on purpose: a statically cached copy outliving its instance made the
	# dummy (headless) renderer error on free. Only the single Enforcer uses this.
	var out := ArrayMesh.new()
	for s in keep:
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	sm.mesh = out # set_mesh keeps the override slots below the new count
	for i in keep.size():
		if sm.get_surface_override_material(i) != overrides[i]:
			sm.set_surface_override_material(i, overrides[i])

func _ensure_normals(sm: MeshInstance3D) -> void:
	var src := sm.mesh
	if src == null or sm.skin != null:
		return
	var missing := false
	for s in src.get_surface_count():
		if (src.surface_get_format(s) & Mesh.ARRAY_FORMAT_NORMAL) == 0:
			missing = true
	if not missing:
		return
	if not _normal_fixed_meshes.has(src):
		var fixed := ArrayMesh.new()
		for s in src.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from(src, s)
			if (src.surface_get_format(s) & Mesh.ARRAY_FORMAT_NORMAL) == 0:
				st.generate_normals()
			st.commit(fixed)
			fixed.surface_set_material(s, src.surface_get_material(s))
		_normal_fixed_meshes[src] = fixed
	sm.mesh = _normal_fixed_meshes[src]

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var res := _find_animation_player_recursive(child)
		if res:
			return res
	return null

## Sets the rim the character rests at (e.g. vulnerable blue, Headliner phase-2 magenta).
## Cancels any running flash.
func update_rim_color(color: Color) -> void:
	_kill_rim_tween()
	_base_rim_color = color
	_set_rim(color, _base_rim_strength)

## Sets the rim strength the character rests at (e.g. Headliner enraged).
func update_rim_strength(strength: float) -> void:
	_kill_rim_tween()
	_base_rim_strength = strength
	_set_rim(_base_rim_color, strength)

## Flash the rim to `color`/`strength`, hold it for `hold_fraction` of `seconds`, then
## tween back to the resting rim over the rest.
func flash_rim(color: Color, strength: float, seconds: float, hold_fraction: float = 0.5) -> void:
	if _rim_material_instance == null:
		return
	_kill_rim_tween()
	_set_rim(color, flash_strength_for(color, strength))
	if not is_inside_tree():
		return
	var hold := seconds * clampf(hold_fraction, 0.0, 1.0)
	var fade := maxf(seconds - hold, 0.0)
	_rim_tween = create_tween().set_parallel(true)
	_rim_tween.tween_property(_rim_material_instance, "shader_parameter/rim_color", _base_rim_color, fade).set_delay(hold)
	_rim_tween.tween_property(_rim_material_instance, "shader_parameter/rim_strength", _base_rim_strength, fade).set_delay(hold)

## T4: the Reduce Flashes accessibility option halves the white-hot flashes (the telegraph
## and the hit flash) and keeps their colour. Coloured pulses are left alone.
const REDUCED_FLASH_FACTOR := 0.5

func flash_strength_for(color: Color, strength: float) -> float:
	if color.is_equal_approx(Color.WHITE) and GameManager.has_method("reduce_flashes") and GameManager.reduce_flashes():
		return strength * REDUCED_FLASH_FACTOR
	return strength

## H4: the telegraph holds white-hot for this share of its beat, so the tell is still at
## full strength when the hitbox arms on the next beat.
const TELEGRAPH_HOLD_FRACTION := 0.9

## The shared enemy telegraph: white-hot rim for one beat of the world's current tempo.
## R2: also announces the tell globally (SignalBus.enemy_telegraphed) for audio/HUD cues.
func flash_telegraph() -> void:
	flash_rim(TELEGRAPH_RIM_COLOR, TELEGRAPH_RIM_STRENGTH, 60.0 / maxf(Conductor.bpm, 1.0), TELEGRAPH_HOLD_FRACTION)
	if SignalBus.has_signal("enemy_telegraphed"):
		var enemy: Node3D = owner as Node3D if owner is Node3D else get_parent() as Node3D
		SignalBus.emit_signal("enemy_telegraphed", enemy)

## The authored resting rim: the rim_color export, or the faction colour when unset.
func get_default_rim_color() -> Color:
	return rim_color if rim_color.a > 0.0 else get_faction_rim_color()

func _start_hover() -> void:
	var base_y := pivot.position.y
	var half_period := 0.5 / hover_hz
	pivot.position.y = base_y - hover_amplitude
	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_property(pivot, "position:y", base_y + hover_amplitude, half_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(pivot, "position:y", base_y - hover_amplitude, half_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Procedural beat squash for unrigged models: stretch the pivot's height by `amount`
## (0.03 = +3 %) about the feet and settle back, all within `seconds`.
func beat_pulse(amount: float, seconds: float) -> void:
	if pivot == null or not is_inside_tree():
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	pivot.scale = _pivot_base_scale
	var peak := _pivot_base_scale * Vector3(1.0, 1.0 + amount, 1.0)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(pivot, "scale", peak, seconds * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(pivot, "scale", _pivot_base_scale, seconds * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Procedural telegraph lean for unrigged models: tip the pivot `degrees` toward the model's
## front (+Z) about the feet, hold, and return within `seconds`.
func lean_forward(degrees: float, seconds: float) -> void:
	if pivot == null or not is_inside_tree():
		return
	if _lean_tween and _lean_tween.is_valid():
		_lean_tween.kill()
	var leaned := _pivot_base_rotation.x + deg_to_rad(degrees)
	_lean_tween = create_tween()
	_lean_tween.tween_property(pivot, "rotation:x", leaned, seconds * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lean_tween.tween_interval(seconds * 0.5)
	_lean_tween.tween_property(pivot, "rotation:x", _pivot_base_rotation.x, seconds * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## F3: shared enemy death — white-hot rim and a shrink of the Pivot (or the root when the
## model has none) to nothing over `seconds`. Returns the shrink tween (null outside the
## tree) so the owner can queue_free when it finishes.
func play_death(seconds: float = 0.25) -> Tween:
	_kill_rim_tween()
	_set_rim(Color.WHITE, DEATH_RIM_STRENGTH)
	if not is_inside_tree():
		return null
	for t: Tween in [_pulse_tween, _lean_tween, _hover_tween]:
		if t and t.is_valid():
			t.kill()
	var target: Node3D = pivot if pivot else self
	var death_tween := create_tween()
	# R2: an enemy with an EnemyAnimator plays its death clip first (death_anim_seconds),
	# then shrinks — the owner frees on this tween's finish, so the delay covers both.
	var anim_delay := _death_anim_seconds()
	if anim_delay > 0.0:
		death_tween.tween_interval(anim_delay)
	death_tween.tween_property(target, "scale", target.scale * DEATH_SCALE_FRACTION, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return death_tween

## The owner's EnemyAnimator death clip time (read via has_node; 0 without an animator).
func _death_anim_seconds() -> float:
	var host: Node = owner if owner else get_parent()
	if host == null or not host.has_node("EnemyAnimator"):
		return 0.0
	var seconds: Variant = host.get_node("EnemyAnimator").get("death_anim_seconds")
	return float(seconds) if seconds != null else 0.0

## Returns the default rim colour for this character's faction.
func get_faction_rim_color() -> Color:
	return PLAYER_RIM_COLOR if faction == Faction.PLAYER else ENEMY_RIM_COLOR

## The colour the rim shows right now (mid-flash included).
func get_current_rim_color() -> Color:
	if _rim_material_instance == null:
		return Color(0, 0, 0, 0)
	return _rim_material_instance.get_shader_parameter("rim_color")

func get_current_rim_strength() -> float:
	if _rim_material_instance == null:
		return 0.0
	return _rim_material_instance.get_shader_parameter("rim_strength")

func get_base_rim_color() -> Color:
	return _base_rim_color

func get_base_rim_strength() -> float:
	return _base_rim_strength

func _set_rim(color: Color, strength: float) -> void:
	if _rim_material_instance == null:
		return
	_rim_material_instance.set_shader_parameter("rim_color", color)
	_rim_material_instance.set_shader_parameter("rim_strength", strength)

func _kill_rim_tween() -> void:
	if _rim_tween and _rim_tween.is_valid():
		_rim_tween.kill()
	_rim_tween = null
