extends Node

var hit_stop_timer: float = 0.0

func _ready() -> void:
	SignalBus.player_hit_landed.connect(_on_player_hit_landed)
	SignalBus.hit_stop_requested.connect(start_hit_stop)

func _process(delta: float) -> void:
	if hit_stop_timer > 0.0:
		var current_scale = Engine.time_scale
		if current_scale > 0.0:
			var real_delta = delta / current_scale
			hit_stop_timer -= real_delta
			if hit_stop_timer <= 0.0:
				Engine.time_scale = 1.0
				hit_stop_timer = 0.0
		else:
			# Safety fallback if time_scale is somehow 0
			hit_stop_timer = 0.0
			Engine.time_scale = 1.0

func _on_player_hit_landed(_damage_info: DamageInfo) -> void:
	start_hit_stop(0.08, 0.05)

## Overlapping requests (Nick hit while landing a hit) never shorten or weaken a stop that
## is already running: the longer remaining time and the deeper slow-down win.
func start_hit_stop(duration: float, time_scale: float) -> void:
	if hit_stop_timer > 0.0:
		Engine.time_scale = minf(Engine.time_scale, time_scale)
		hit_stop_timer = maxf(hit_stop_timer, duration)
		return
	Engine.time_scale = time_scale
	hit_stop_timer = duration
