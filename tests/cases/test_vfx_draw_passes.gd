extends "res://tests/framework/test_case.gd"

# P1: hit_spark.tscn / enemy_death.tscn shipped with draw_pass_1 = null, so VFXManager fired
# particles that drew nothing. Every particle system under vfx/ must draw an unshaded mesh.

const VFX_DIR := "res://vfx/"

func test_every_vfx_particle_system_draws_an_unshaded_mesh() -> void:
	var checked := 0
	for file in DirAccess.get_files_at(VFX_DIR):
		if not file.ends_with(".tscn"):
			continue
		var root: Node = (load(VFX_DIR + file) as PackedScene).instantiate()
		var systems: Array = root.find_children("*", "GPUParticles3D", true, false)
		if root is GPUParticles3D:
			systems.push_front(root)
		for node in systems:
			var p := node as GPUParticles3D
			checked += 1
			var label := "%s/%s" % [file, p.name]
			assert_not_null(p.draw_pass_1, "%s needs a draw_pass_1 mesh" % label)
			if p.draw_pass_1 == null:
				continue
			var mat := p.draw_pass_1.surface_get_material(0) as StandardMaterial3D
			assert_not_null(mat, "%s's mesh carries a StandardMaterial3D" % label)
			if mat:
				assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "%s is unshaded" % label)
				assert_true(mat.vertex_color_use_as_albedo, "%s takes its colour from the particle colour/ramp" % label)
		root.free()
	assert_true(checked >= 3, "HitSpark, EnemyDeath and its Smoke were checked (%d)" % checked)

func test_spark_and_death_bursts_are_hdr_and_the_death_is_magenta() -> void:
	var spark: GPUParticles3D = (load("res://vfx/hit_spark.tscn") as PackedScene).instantiate()
	var death: GPUParticles3D = (load("res://vfx/enemy_death.tscn") as PackedScene).instantiate()
	var spark_mat := spark.draw_pass_1.surface_get_material(0) as StandardMaterial3D
	assert_gt(spark_mat.albedo_color.r, 1.0, "Spark albedo is over-bright (blooms past glow_hdr_threshold)")
	assert_eq(spark.amount, 24)
	assert_almost_eq(spark.lifetime, 0.25, 0.0001)
	assert_true((spark.process_material as ParticleProcessMaterial).particle_flag_align_y, "Sparks streak along their velocity")
	var ramp := ((death.process_material as ParticleProcessMaterial).color_ramp as GradientTexture1D).gradient
	assert_true(ramp.get_color(0).is_equal_approx(Color(1, 0, 0.666667, 1)), "Death burst starts magenta #FF00AA")
	assert_lt(ramp.get_color(ramp.get_point_count() - 1).v, 0.1, "...and ramps to near-black")
	assert_not_null(death.get_node_or_null("Smoke"), "The death burst has a Smoke child")
	spark.free()
	death.free()

func test_firing_a_spark_leaves_it_emitting_and_the_death_restarts_the_smoke() -> void:
	var vfx: Node = load("res://vfx/vfx_manager.gd").new()
	add_child(vfx)
	assert_eq(vfx._spark_pool.size(), 12, "P1: spark pool grew 8 -> 12")
	vfx._on_hit_landed(Vector3(0, 1, 0), "light")
	var fired: GPUParticles3D = vfx._spark_pool[0]
	assert_true(fired.emitting, "A fired spark is emitting")
	vfx._on_enemy_died(Vector3(0, 1, 0))
	var death: GPUParticles3D = vfx._death_pool[0]
	assert_true(death.emitting, "A fired death burst is emitting")
	assert_true((death.get_node("Smoke") as GPUParticles3D).emitting, "...and so is its smoke")
	vfx.free()
