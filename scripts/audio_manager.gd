extends Node

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var music_volume: float = 0.75
var sfx_volume: float = 0.9

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SfxPlayer"
	sfx_player.bus = SFX_BUS
	add_child(sfx_player)
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if not is_instance_valid(music_player) or stream == null:
		return
	music_player.stream = stream
	music_player.play()
	if loop and stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func stop_music() -> void:
	if is_instance_valid(music_player):
		music_player.stop()

func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if not is_instance_valid(sfx_player) or stream == null:
		return
	sfx_player.stream = stream
	sfx_player.pitch_scale = clampf(pitch, 0.5, 2.0)
	sfx_player.play()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(MUSIC_BUS, music_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(SFX_BUS, sfx_volume)

func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var bus_index: int = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)

func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.001)))
