extends Node
## Debug-only screenshot helper for the project site: F12 saves the viewport to user://site_captures/.
## Deliberate exemption from the "only SaveManager touches user://" rule: it writes screenshots, never game data.
## In release builds the node frees itself in _ready().

func _ready() -> void:
	if OS.has_feature("release"):
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if OS.has_feature("release"):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		var image := get_viewport().get_texture().get_image()
		if image == null:
			return
		var dir := "user://site_captures"
		DirAccess.make_dir_recursive_absolute(dir)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		var path := "%s/%s_%d.png" % [dir, stamp, Time.get_ticks_msec() % 1000]
		image.save_png(path)
		print("Saved ", ProjectSettings.globalize_path(path))
