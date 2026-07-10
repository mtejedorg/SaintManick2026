extends Node
class_name IntensityController

## The resting tempo of the game. 128 is the Slice's resting tempo, not a canonical game-wide BPM.
@export var base_bpm: float = 128.0
## The tempo boost applied per active enemy in the arena.
@export var per_enemy_boost: float = 2.0
## The maximum tempo boost that can be dynamically applied.
@export var max_boost: float = 16.0

var _boss_active: bool = false

func _ready() -> void:
	if not SignalBus.beat.is_connected(_on_beat):
		SignalBus.beat.connect(_on_beat)
	if not SignalBus.boss_spawned.is_connected(_on_boss_spawned):
		SignalBus.boss_spawned.connect(_on_boss_spawned)
	if not SignalBus.boss_died.is_connected(_on_boss_died):
		SignalBus.boss_died.connect(_on_boss_died)
	if not SignalBus.boss_reset.is_connected(_on_boss_reset):
		SignalBus.boss_reset.connect(_on_boss_reset)

func _on_beat(layer: String, _beat_index: int) -> void:
	if layer == "primary":
		update_tempo()

func _on_boss_spawned(_boss_name: String) -> void:
	_boss_active = true

func _on_boss_died() -> void:
	_boss_active = false
	update_tempo()

func _on_boss_reset() -> void:
	_boss_active = false
	update_tempo()

func get_active_enemy_count() -> int:
	var active_components: Array = []
	var hurtboxes = get_tree().get_nodes_in_group("enemy_hurtbox")
	for hurtbox in hurtboxes:
		if is_instance_valid(hurtbox) and hurtbox.is_inside_tree() and not hurtbox.is_queued_for_deletion():
			if _is_dormant(hurtbox.owner):
				continue
			var hc = hurtbox.get("health_component")
			if hc and is_instance_valid(hc) and not hc.is_queued_for_deletion():
				if hc.get("current_health") != null and hc.current_health > 0.0:
					if not active_components.has(hc):
						active_components.append(hc)
	return active_components.size()

## Scene-placed bosses/minibosses (Enforcer pre-zone-07, Headliner pre-activation) join
## "enemy_hurtbox" in Hurtbox3D._ready() the moment the vertical slice loads, well before
## their fight ever starts. Left uncounted-for, they'd permanently inflate the tempo
## formula: the game would never rest at base_bpm, and the beat would silently shift the
## instant a boss dies. Both expose their own dormancy flag on the hurtbox's owner (the
## scene root): Enforcer -> is_active, Headliner -> is_active_boss. Object.get() returns
## null for a missing property, and null never equals false, so regular enemies (which
## have neither property) are unaffected.
func _is_dormant(owner_node: Node) -> bool:
	if owner_node == null:
		return false
	if owner_node.get("is_active") == false:
		return true
	if owner_node.get("is_active_boss") == false:
		return true
	return false

func update_tempo() -> void:
	if _boss_active:
		return
	
	var active_enemy_count = get_active_enemy_count()
	var target_bpm = base_bpm + min(active_enemy_count * per_enemy_boost, max_boost)
	Conductor.target_bpm = target_bpm
