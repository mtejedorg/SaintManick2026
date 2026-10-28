extends CanvasLayer
## Batch Q7: scene transitions -- a static helper, NOT an autoload. SceneTransition.go(tree,
## path) adds one of these to tree.root (so it survives the scene change): a #0a0a12 cover with
## a dim "ACQUIRING SIGNAL..." line fades in, the scene loads on a thread
## (ResourceLoader.load_threaded_request), change_scene_to_packed swaps it in, the cover fades
## out and frees itself. Under --headless, or while the capture tool runs, there is no fade:
## the scene loads synchronously and swaps at once.
##
## Usage: const SceneTransition = preload("res://ui/transition/scene_transition.gd")
##        SceneTransition.go(get_tree(), "res://levels/slice/vertical_slice.tscn")
## Every menu's `change_scene` Callable seam defaults to a method that calls this.

const SELF_PATH := "res://ui/transition/scene_transition.gd"
const LAYER := 100
const FADE_TIME := 0.25
const COVER_COLOR := Color("0a0a12")
## Three ASCII dots: Share Tech Mono is not guaranteed to carry U+2026.
const LABEL_TEXT := "ACQUIRING SIGNAL..."
const CAPTURE_DIR := "res://tools/capture/"

## True while a transition is on screen: a second go() during it is ignored (a double press).
static var _busy: bool = false

var target_path: String = ""
var _cover: ColorRect
var _loading: bool = false

## Changes the scene to `path`. Returns immediately; the swap happens over the next frames.
static func go(tree: SceneTree, path: String) -> void:
	if tree == null or path == "":
		return
	if is_instant(tree):
		var packed := ResourceLoader.load(path) as PackedScene
		if packed:
			tree.change_scene_to_packed(packed)
		else:
			tree.change_scene_to_file(path)
		return
	if _busy:
		return
	_busy = true
	var cover_layer: CanvasLayer = (load(SELF_PATH) as GDScript).new()
	cover_layer.set("target_path", path)
	tree.root.add_child(cover_layer)

## No fade (and a synchronous load) under --headless or while the capture tool drives the game.
static func is_instant(tree: SceneTree) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var scene := tree.current_scene
	return scene != null and scene.scene_file_path.begins_with(CAPTURE_DIR)

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = COVER_COLOR
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP # swallow clicks during the swap
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.modulate.a = 0.0
	add_child(_cover)
	var label := Label.new()
	label.text = LABEL_TEXT
	label.theme_type_variation = &"DimLabel"
	label.theme = load("res://ui/theme/neon_theme.tres") as Theme
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cover.add_child(label)
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", 1.0, FADE_TIME)
	tween.tween_callback(_start_load)

func _start_load() -> void:
	if ResourceLoader.load_threaded_request(target_path) != OK:
		_swap(null)
		return
	_loading = true

func _process(_delta: float) -> void:
	if not _loading:
		return
	match ResourceLoader.load_threaded_get_status(target_path):
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading = false
			_swap(ResourceLoader.load_threaded_get(target_path) as PackedScene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = false
			_swap(null)

func _swap(packed: PackedScene) -> void:
	var tree := get_tree()
	if packed:
		tree.change_scene_to_packed(packed)
	else:
		tree.change_scene_to_file(target_path) # reports the load error the usual way
	# The new scene enters at the end of this frame; reveal it on the next.
	await tree.process_frame
	await tree.process_frame
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_finish)

func _finish() -> void:
	_busy = false
	queue_free()

func _exit_tree() -> void:
	_busy = false
