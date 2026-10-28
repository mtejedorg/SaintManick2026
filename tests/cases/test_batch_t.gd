extends "res://tests/framework/test_case.gd"

# Batch T: T1 the zone card shows its text once slid in, T2 enemy body heights, T3 no
# "material is null" on a same-frame free of a Nick body and an enemy body, T4 reduce-flashes
# + land / run_stop clips, T5 Zone 10 labels, T6 Nick's cyan accents and the bionic arm.

const CARD := "res://ui/hud/zone_title_card.tscn"
const HUD := "res://ui/hud/hud.tscn"
const RUNNER := "res://characters/enemies/runner/runner.tscn"
const BRUISER := "res://characters/enemies/bruiser/bruiser.tscn"
const PLAYER := "res://characters/player/player.tscn"
const NICK_VISUAL := "res://characters/player/nick_visual.tscn"
const BODY := "res://characters/shared/enemy_body_visual.tscn"
const SLICE_PATH := "res://levels/slice/vertical_slice.tscn"
const NICK_TEX := "res://3D_Assets/Characters/Nick/nick_body_v2_0.png"
const NICK_TEX_BACKUP := "res://3D_Assets/Characters/Nick/nick_body_v2_0_magenta_backup.png"

var _nodes: Array[Node] = []
var _reduce_before: bool

func before_each() -> void:
	GameManager.is_test = true
	_reduce_before = SaveManager.profile.reduce_flashes

func after_each() -> void:
	super.after_each()
	SaveManager.profile.reduce_flashes = _reduce_before
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n

func _floor(z: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, -1.5, z) # top at y = -1 = a player capsule's bottom at y 0
	add_child(body)
	return _keep(body) as StaticBody3D

# --- T1 --------------------------------------------------------------------------------

func _assert_card_reads(card: Control, text: String, label: String) -> void:
	assert_eq(card.label.text, text, "%s: label text" % label)
	assert_true(card.label.visible, "%s: label visible" % label)
	assert_gt(card.label.get_combined_minimum_size().x, 0.0, "%s: the label has a width" % label)
	assert_almost_eq(card.modulate.a, 1.0, 0.001, "%s: the card is fully opaque" % label)
	assert_true(card.visible, "%s: the card is visible" % label)
	var rect: Rect2 = card.label.get_global_rect()
	assert_true(rect.position.x >= -0.5 and rect.end.x <= card.get_viewport_rect().size.x + 0.5, "%s: the label sits on screen once slid in (%s)" % [label, str(rect)])

func test_t1_the_zone_card_shows_its_text_after_the_slide_in() -> void:
	var card: Control = _keep(load(CARD).instantiate())
	add_child(card)
	card.show_text("SECTOR 01 — STREET ENTRANCE")
	assert_false(card.eyebrow_label.visible, "No eyebrow on a plain card")
	await get_tree().create_timer(card.SLIDE_IN_TIME + 0.25).timeout
	_assert_card_reads(card, "SECTOR 01 — STREET ENTRANCE", "zone card")
	assert_false(card.eyebrow_label.visible, "...and it stays hidden once slid in")

func test_t1_the_boss_card_shows_the_eyebrow_and_the_next_card_hides_it() -> void:
	var card: Control = _keep(load(CARD).instantiate())
	add_child(card)
	card.show_text("HEADLINER", 0.3, true, "LIVE ON AIR")
	await get_tree().create_timer(card.SLIDE_IN_TIME + 0.25).timeout
	_assert_card_reads(card, "HEADLINER", "boss card")
	assert_true(card.eyebrow_label.visible, "The boss card shows its eyebrow")
	assert_eq(card.eyebrow_label.text, "LIVE ON AIR", "Eyebrow text")
	card.show_text("SECTOR 02 — X")
	assert_false(card.eyebrow_label.visible, "A card without an eyebrow hides it again")

func test_t1_the_hud_hosted_card_reads_after_a_zone_entered() -> void:
	var hud: CanvasLayer = _keep(load(HUD).instantiate())
	add_child(hud)
	SignalBus.zone_entered.emit("SECTOR 01 — STREET ENTRANCE")
	await get_tree().create_timer(0.65).timeout
	_assert_card_reads(hud.zone_title_card, "SECTOR 01 — STREET ENTRANCE", "HUD card")

# --- T2 --------------------------------------------------------------------------------

func _bone_span(e: Node3D) -> float:
	var sk := e.find_child("Skeleton3D", true, false) as Skeleton3D
	var lo := INF
	var hi := -INF
	for i in sk.get_bone_count():
		var y := (sk.global_transform * sk.get_bone_global_pose(i).origin).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo

func _parked_enemy(path: String, z: float) -> Node3D:
	var e: Node3D = _keep(load(path).instantiate())
	e.position = Vector3(0.0, 800.0, z)
	add_child(e)
	e.set_physics_process(false)
	return e

func test_t2_the_runner_and_bruiser_stand_at_their_authored_heights() -> void:
	# Measured on the posed skeleton (bone origins: head top and toe tips sit ~0.05 m beyond
	# them). Runner: 0.95 x Nick's body = ~1.7 m; Bruiser 1.22 x = ~2.2 m. The Runner is NOT
	# half Nick's height in the engine -- the round-4 capture read it that way off perspective
	# and Nick's wide combat crouch.
	var runner := _parked_enemy(RUNNER, 22000.0)
	var bruiser := _parked_enemy(BRUISER, 22020.0)
	for i in 5:
		await get_tree().process_frame
	var r := _bone_span(runner)
	var b := _bone_span(bruiser)
	assert_true(r >= 1.6 and r <= 1.8, "Runner stands 1.6-1.8 m (got %.2f)" % r)
	assert_true(b >= 2.0 and b <= 2.3, "Bruiser stands 2.0-2.3 m (got %.2f)" % b)
	assert_gt(b / r, 1.2, "The Bruiser towers over the Runner (%.2f x)" % (b / r))

# --- T3 --------------------------------------------------------------------------------

const T3_SCRIPT := """extends SceneTree
func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var nodes := []
	for p in ["res://characters/player/player.tscn", "res://characters/enemies/runner/runner.tscn", "res://characters/enemies/bruiser/bruiser.tscn"]:
		var inst: Node = (load(p) as PackedScene).instantiate()
		holder.add_child(inst)
		nodes.append(inst)
	for f in 3:
		await process_frame
	for n in nodes:
		n.free()
	for f in 3:
		await process_frame
	print("T3_DONE")
	quit(0)
"""

func test_t3_freeing_a_nick_body_and_an_enemy_body_raises_no_material_errors() -> void:
	var script_path := "user://t3_probe_%d.gd" % OS.get_process_id()
	var f := FileAccess.open(script_path, FileAccess.WRITE)
	assert_not_null(f, "Scratch script writable")
	if f == null:
		return
	f.store_string(T3_SCRIPT)
	f.close()
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", ProjectSettings.globalize_path(script_path)], out, true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(script_path))
	var text := "\n".join(PackedStringArray(out))
	assert_eq(code, 0, "The scratch scenario exits cleanly")
	assert_true(text.contains("T3_DONE"), "The scratch scenario ran to the end")
	assert_false(text.contains("\"material\" is null"), "No 'Parameter material is null' on the same-frame free")

func test_t3_the_visual_drops_its_surface_overrides_before_it_dies() -> void:
	var v: CharacterVisual = _keep(load(NICK_VISUAL).instantiate())
	add_child(v)
	var sm: MeshInstance3D = v.skinned_meshes[0]
	assert_not_null(sm.get_surface_override_material(0), "Precondition: Nick's body carries a surface override")
	v._release_surface_overrides()
	assert_null(sm.get_surface_override_material(0), "_release_surface_overrides clears it (runs on NOTIFICATION_PREDELETE)")

# --- T4 --------------------------------------------------------------------------------

func test_t4_reduce_flashes_halves_the_white_hot_flashes_and_keeps_the_colour() -> void:
	var v: CharacterVisual = _keep(load(BODY).instantiate())
	add_child(v)
	SaveManager.profile.reduce_flashes = false
	v.flash_rim(Color.WHITE, 5.0, 0.5)
	assert_almost_eq(v.get_current_rim_strength(), 5.0, 0.001, "Full hit flash by default")
	SaveManager.profile.reduce_flashes = true
	v.flash_rim(Color.WHITE, 5.0, 0.5)
	assert_almost_eq(v.get_current_rim_strength(), 2.5, 0.001, "Reduce Flashes halves the hit flash")
	assert_eq(v.get_current_rim_color(), Color.WHITE, "...in the same colour")
	v.flash_rim(CharacterVisual.TELEGRAPH_RIM_COLOR, CharacterVisual.TELEGRAPH_RIM_STRENGTH, 0.5)
	assert_almost_eq(v.get_current_rim_strength(), CharacterVisual.TELEGRAPH_RIM_STRENGTH * 0.5, 0.001, "...and the white-hot telegraph")
	v.flash_rim(Color(1.0, 0.0, 0.667), 4.0, 0.5)
	assert_almost_eq(v.get_current_rim_strength(), 4.0, 0.001, "A coloured pulse is left alone")

func _spawn_player_on_floor(z: float) -> PlayerController:
	_floor(z)
	var p: PlayerController = _keep(load(PLAYER).instantiate())
	p.position = Vector3(0.0, 0.0, z)
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	return p

func test_t4_a_hard_landing_plays_the_land_clip() -> void:
	var p := await _spawn_player_on_floor(24000.0)
	var ctrl := p.animation_controller
	assert_true(ctrl.animation_map.has("land"), "Precondition: the controller maps 'land'")
	p.global_position.y = 2.5
	p.velocity = Vector3(0.0, -12.0, 0.0)
	p.state_machine.transition_to("StateAirborne")
	var seen := false
	for i in 90:
		await get_tree().physics_frame
		if String(ctrl.anim_player.current_animation) == "land":
			seen = true
			break
	assert_true(seen, "A fall at > 6 m/s plays 'land' on touchdown (state %s, clip %s)" % [p.state_machine.current_state.name, ctrl.anim_player.current_animation])

func test_t4_land_clip_thresholds() -> void:
	var p := await _spawn_player_on_floor(24100.0)
	var ctrl := p.animation_controller
	var state = p.state_machine.get_node("StateAirborne")
	ctrl.play("idle")
	state._play_landing(3.0)
	assert_eq(String(ctrl.anim_player.current_animation), "idle", "A 3 m/s touchdown stays on idle")
	state._play_landing(8.0)
	assert_eq(String(ctrl.anim_player.current_animation), "land", "An 8 m/s touchdown plays land")

func test_t4_run_to_idle_at_speed_plays_run_stop() -> void:
	var p := await _spawn_player_on_floor(24200.0)
	var ctrl := p.animation_controller
	assert_true(ctrl.animation_map.has("run_stop"), "Precondition: the controller maps 'run_stop'")
	p.state_machine.transition_to("StateRun")
	p.velocity.x = 8.0
	var seen := false
	for i in 30:
		await get_tree().physics_frame
		if String(ctrl.anim_player.current_animation) == "run_stop":
			seen = true
			break
	assert_true(seen, "Releasing the stick at > 4 m/s plays 'run_stop' (state %s, clip %s)" % [p.state_machine.current_state.name, ctrl.anim_player.current_animation])

func test_t4_run_stop_thresholds() -> void:
	var p := await _spawn_player_on_floor(24300.0)
	var ctrl := p.animation_controller
	var run_state = p.state_machine.get_node("StateRun")
	ctrl.play("idle")
	run_state._play_run_stop(2.0)
	assert_eq(String(ctrl.anim_player.current_animation), "idle", "A 2 m/s release stays on idle")
	run_state._play_run_stop(7.0)
	assert_eq(String(ctrl.anim_player.current_animation), "run_stop", "A 7 m/s release plants")

# --- T5 --------------------------------------------------------------------------------

func test_t5_zone_ten_labels_and_the_amber_marquee() -> void:
	var slice: Node3D = _keep((load(SLICE_PATH) as PackedScene).instantiate())
	add_child(slice)
	var marquee: Label3D = slice.get_node("Z10_Dressing/Marquee")
	assert_true(marquee.modulate.r >= 3.5 and marquee.modulate.g >= 0.4 and marquee.modulate.g <= 1.0 and marquee.modulate.b < 0.1, "The marquee is HDR amber, red-heavy so the filmic curve keeps it amber (%s)" % str(marquee.modulate))
	assert_true(marquee.outline_modulate.r < 0.5, "...with a dark amber outline")
	assert_almost_eq(slice.get_node("Z10_Dressing/SignHeadlinerLive").pixel_size, 0.0125, 0.0001, "HEADLINER LIVE sign doubled")
	for n in ["FloorB2", "FloorB1", "FloorG", "Floor01", "FloorRoof"]:
		assert_almost_eq(slice.get_node("Z9_Dressing/%s" % n).pixel_size, 0.011719, 0.0001, "%s label halved" % n)

# --- T6 --------------------------------------------------------------------------------

func _count_magenta(path: String) -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var count := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			var hue := c.h * 360.0
			if c.s > 0.35 and hue >= 280.0 and hue <= 340.0:
				count += 1
	return count

func test_t6_nicks_texture_accents_are_cyan_and_the_magenta_original_is_kept() -> void:
	assert_eq(_count_magenta(NICK_TEX), 0, "No saturated magenta left in Nick's texture")
	assert_gt(_count_magenta(NICK_TEX_BACKUP), 1000, "The backup keeps the magenta original")

func test_t6_nick_wears_an_emissive_bionic_arm_on_the_right_forearm() -> void:
	var v: CharacterVisual = _keep(load(NICK_VISUAL).instantiate())
	add_child(v)
	var att := v.get_node_or_null("NickBody/Skeleton3D/BionicArm") as BoneAttachment3D
	assert_not_null(att, "The BionicArm attachment exists")
	if att == null:
		return
	assert_eq(att.bone_name, "mixamorig_RightForeArm", "On the right forearm bone")
	assert_true(att.get_bone_idx() >= 0, "The bone resolves")
	var meshes := att.find_children("*", "MeshInstance3D", false, false)
	assert_eq(meshes.size(), 2, "A sleeve and a wrist ring")
	for mi in meshes:
		var mat := (mi as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		assert_not_null(mat, "%s has a material" % mi.name)
		assert_true(mat.emission_enabled and mat.emission_energy_multiplier >= 4.0, "%s is emissive x4" % mi.name)
		assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "%s is unshaded" % mi.name)
		assert_true(mat.emission.b > 0.9 and mat.emission.r < 0.1, "%s emits cyan" % mi.name)
		assert_false(v.skinned_meshes.has(mi), "%s is an accessory, not part of the tinted/rimmed body" % mi.name)
