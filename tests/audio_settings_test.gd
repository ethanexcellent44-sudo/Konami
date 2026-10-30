extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var menu_scene: PackedScene = load("res://scenes/menu.tscn")
	if menu_scene == null:
		_fail("Menu scene failed to load")
		return
	var profile: Node = root.get_node_or_null("ProfileStore")
	if profile == null:
		_fail("ProfileStore autoload is missing in test tree")
		return
	var menu: Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	menu.call("show_section", "SETTINGS")
	var music_slider: HSlider = menu.find_child("MusicVolumeSlider", true, false) as HSlider
	var sfx_slider: HSlider = menu.find_child("SfxVolumeSlider", true, false) as HSlider
	if music_slider == null or sfx_slider == null:
		_fail("Settings screen did not build audio sliders")
		menu.queue_free()
		return
	music_slider.set_value_no_signal(0.35)
	music_slider.value_changed.emit(0.35)
	if absf(float(profile.get("music_volume")) - 0.35) > 0.001:
		_fail("Music slider did not update profile volume")
		menu.queue_free()
		return
	sfx_slider.set_value_no_signal(0.68)
	sfx_slider.value_changed.emit(0.68)
	if absf(float(profile.get("effects_volume")) - 0.68) > 0.001:
		_fail("SFX slider did not update profile volume")
		menu.queue_free()
		return
	print("PASS: audio settings sliders and profile volume updates")
	menu.queue_free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
