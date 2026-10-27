extends Node
## Global Signal Bus Autoload
## All cross-domain events should be routed through here to decouple systems.

# --- Player Events ---
signal player_health_changed(new_health: float, max_health: float)
signal player_shield_changed(new_shield: float, max_shield: float)
## Emitted whenever the player takes damage (HealthComponent.damaged is per-node; this is
## the bus-wide equivalent so systems like the VCR overlay (M10) can react without a direct
## node reference).
signal player_damaged(damage_info: DamageInfo)
signal player_died()
signal player_life_lost(current_lives: int)
## T3: emitted after a checkpoint respawn (life lost with lives remaining — NOT game over).
## Bosses reset to dormant, uncleared encounters despawn+re-arm, zone triggers re-arm.
signal player_respawned()
signal ability_meter_changed(current: float, max_meter: float)
## F9: Bass Drop armed (true, waiting for the next downbeat) / detonated (false). The HUD
## ability bar shows the armed state; Nick's rim holds white-hot while armed.
signal bass_drop_armed(armed: bool)
## K3 (D6): a dash/roll landed on the beat (the cyan rim flash plays on Nick). Audio hooks
## its short tick here; nothing is required to listen.
signal beat_dodge_landed()

# --- Run Events ---
## Emitted at the end of GameManager.start_new_run(). Global systems that carry state
## across scene changes (Conductor tempo, IntensityController boss lock, AudioManager boss
## music flag) reset here so a game over/abandon mid-boss can't leak into the next run.
signal run_started()

# --- Combat Events ---
signal combo_increased(current_combo: int)
signal combo_dropped()
signal combo_reset()  # Alias emitted alongside combo_dropped for HUD clarity
## Emitted once when the combo counter hits its cap (M11, GDD §6.1) — HUD celebrates with
## a glitch/explode flourish. Fires only on the frame the cap is reached, not every
## subsequent hit while capped.
signal combo_capped()
signal hit_stop_requested(duration: float, time_scale: float)
signal camera_shake_requested(strength: float, duration: float)
signal player_hit_landed(damage_info: DamageInfo)
## Emitted by Hurtbox3D when a player attack connects. hit_type: "light" or "heavy".
signal hit_landed(position: Vector3, hit_type: String)
## F12: a player attack connected with a boss state shield (Enforcer/Headliner) and was
## absorbed — no damage, no meter, but it is NOT a whiff: the combo counter keeps the chain
## alive (without incrementing) and VFX may spark at `position`.
signal hit_blocked(position: Vector3)
## Emitted by enemy _on_died() before queue_free so VFX can burst at the death position.
signal enemy_died(position: Vector3)
## P7: a HealthComponent shield was knocked from > 0 to 0 by a hit (the Bruiser's 80, Nick's
## own). VFX bursts steel sparks at `position` with a shake; AudioManager plays shield_break.
signal shield_broken(position: Vector3)
## P10: a brief full-screen white flash (ComboFlash plays it): peak alpha, fade seconds.
signal screen_flash_requested(alpha: float, duration: float)


# --- Music/Rhythm Events ---
signal beat(layer: String, beat_index: int)
signal downbeat(layer: String, measure_index: int)
signal tempo_changed(new_bpm: float)

# --- Camera Events ---
signal camera_shift_requested(top_down: bool, target_path: Path3D, transition_time: float)
## H1: a camera_shift_requested tween landed (StateTransitioning._on_tween_finished), i.e.
## the rail/jump constraints for `top_down` are now applied to the player.
signal camera_shift_finished(top_down: bool)
signal miniboss_defeated()

# --- Zone Events ---
signal zone_entered(zone_name: String)
## H4: a short full-screen banner (the UI connects it to the zone card), e.g. a boss phase
## cue. `hold` is the seconds the text stays fully visible.
signal banner_requested(text: String, hold: float)

# --- Boss Events ---
signal boss_spawned(boss_name: String)
signal boss_health_changed(current: int, maximum: int)
## U5: the active boss's shield state for the HUD strip on the boss bar. The slice's bosses
## have an on/off shield, so they emit (max, max) when it goes up and (0, max) when it drops.
signal boss_shield_changed(current: float, max_shield: float)
signal boss_died()
## T3: a boss returned to dormant because the player lost a life (checkpoint respawn).
## HUD hides the boss bar; AudioManager stops boss music. Distinct from boss_died so
## nothing awards/celebrates on a reset.
signal boss_reset()

# Input actions (jump/dash/roll/attack_light/attack_heavy/ability_ultimate) are now real
# entries in project.godot's [input] section (M9) with keyboard + gamepad bindings —
# no more runtime InputMap registration here.
