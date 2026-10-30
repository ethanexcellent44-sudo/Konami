extends Node
class_name SoundManager

var whistle_stream: AudioStreamWAV
var kick_stream: AudioStreamWAV
var hard_kick_stream: AudioStreamWAV
var net_stream: AudioStreamWAV
var post_stream: AudioStreamWAV
var save_stream: AudioStreamWAV
var cheer_stream: AudioStreamWAV
var crowd_ambient_stream: AudioStreamWAV
var slide_stream: AudioStreamWAV
var tackle_stream: AudioStreamWAV
var triple_whistle_stream: AudioStreamWAV
var ethan_theme_stream: AudioStreamWAV

var audio_players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer
var theme_player: AudioStreamPlayer
var licensed_theme_stream: AudioStream
var music_volume: float = 0.7
var effects_volume: float = 0.85
const POOL_SIZE: int = 8
const SAMPLE_RATE: int = 22050

func _ready() -> void:
	_generate_audio_assets()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		audio_players.append(p)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.stream = crowd_ambient_stream
	ambient_player.volume_db = -18.0
	add_child(ambient_player)
	ambient_player.play()
	theme_player = AudioStreamPlayer.new()
	theme_player.stream = ethan_theme_stream
	theme_player.volume_db = -13.0
	theme_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(theme_player)
	var licensed_theme_path := "res://assets/music/dandelions.mp3"
	if ResourceLoader.exists(licensed_theme_path):
		licensed_theme_stream = load(licensed_theme_path) as AudioStream

func play_ethan_theme() -> void:
	if is_instance_valid(theme_player):
		theme_player.stream = licensed_theme_stream if is_instance_valid(licensed_theme_stream) else ethan_theme_stream
		theme_player.play()
	if is_instance_valid(ambient_player):
		ambient_player.stop()

func stop_ethan_theme() -> void:
	if is_instance_valid(theme_player):
		theme_player.stop()
	if is_instance_valid(ambient_player):
		ambient_player.play()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	if is_instance_valid(ambient_player):
		ambient_player.volume_db = linear_to_db(maxf(0.001, music_volume * 0.16))
	if is_instance_valid(theme_player):
		theme_player.volume_db = linear_to_db(maxf(0.001, music_volume))

func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	for audio_player in audio_players:
		audio_player.volume_db = linear_to_db(maxf(0.001, effects_volume))

func _get_available_player() -> AudioStreamPlayer:
	for p in audio_players:
		if not p.playing:
			return p
	return audio_players[0]

func play_whistle(double: bool = false) -> void:
	var p := _get_available_player()
	p.stream = whistle_stream
	p.volume_db = -4.0
	p.volume_db += linear_to_db(maxf(0.001, effects_volume))
	p.pitch_scale = 1.05 if double else 1.0
	p.play()

func play_whistle_triple() -> void:
	var p := _get_available_player()
	p.stream = triple_whistle_stream
	p.volume_db = -3.0
	p.volume_db += linear_to_db(maxf(0.001, effects_volume))
	p.pitch_scale = 1.0
	p.play()

func play_slide() -> void:
	var p := _get_available_player()
	p.stream = slide_stream
	p.volume_db = -6.0
	p.volume_db += linear_to_db(maxf(0.001, effects_volume))
	p.pitch_scale = randf_range(0.9, 1.1)
	p.play()

func play_tackle() -> void:
	var p := _get_available_player()
	p.stream = tackle_stream
	p.volume_db = -3.5
	p.volume_db += linear_to_db(maxf(0.001, effects_volume))
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_kick(power_ratio: float = 0.5) -> void:
	var p := _get_available_player()
	if power_ratio > 0.65:
		p.stream = hard_kick_stream
		p.volume_db = lerpf(-4.0, 0.0, power_ratio)
	else:
		p.stream = kick_stream
		p.volume_db = lerpf(-8.0, -3.0, power_ratio)
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_net() -> void:
	var p := _get_available_player()
	p.stream = net_stream
	p.volume_db = -2.0
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()

func play_post() -> void:
	var p := _get_available_player()
	p.stream = post_stream
	p.volume_db = -1.0
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()

func play_save() -> void:
	var p := _get_available_player()
	p.stream = save_stream
	p.volume_db = -3.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_cheer() -> void:
	var p := _get_available_player()
	p.stream = cheer_stream
	p.volume_db = -2.0
	p.pitch_scale = 1.0
	p.play()

func _generate_audio_assets() -> void:
	whistle_stream = _build_whistle()
	kick_stream = _build_kick(false)
	hard_kick_stream = _build_kick(true)
	net_stream = _build_net()
	post_stream = _build_post()
	save_stream = _build_save()
	cheer_stream = _build_cheer()
	crowd_ambient_stream = _build_crowd_ambient()
	slide_stream = _build_slide()
	tackle_stream = _build_tackle()
	triple_whistle_stream = _build_triple_whistle()
	ethan_theme_stream = _build_ethan_theme()

func _build_ethan_theme() -> AudioStreamWAV:
	var duration := 8.0
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	var bass_notes: Array[float] = [55.0, 55.0, 65.41, 73.42, 49.0, 49.0, 73.42, 65.41]
	var lead_notes: Array[float] = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63, 196.0, 261.63]
	for i in range(count):
		var time := float(i) / float(SAMPLE_RATE)
		var beat := fposmod(time, 1.0)
		var step := int(floor(time)) % bass_notes.size()
		var bass := sin(time * bass_notes[step] * TAU) * 0.28
		var lead_envelope := exp(-beat * 3.8) * (0.5 + 0.5 * sin(beat * PI))
		var lead := sin(time * lead_notes[step] * TAU) * lead_envelope * 0.12
		var chord := (sin(time * 130.81 * TAU) + sin(time * 164.81 * TAU) + sin(time * 196.0 * TAU)) * 0.035
		var kick_envelope := exp(-beat * 12.0)
		var kick := sin(time * (62.0 + kick_envelope * 45.0) * TAU) * kick_envelope * 0.22
		samples[i] = bass + lead + chord + kick
	return _build_stream(_pack_samples(samples), true)

func _build_stream(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = data.size() / 2
	return s

func _pack_samples(float_samples: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(float_samples.size() * 2)
	for i in range(float_samples.size()):
		var val: float = float_samples[i]
		var int_val := clampi(int(val * 32000.0), -32767, 32767)
		if int_val < 0:
			int_val += 65536
		bytes[i * 2] = int_val & 0xFF
		bytes[i * 2 + 1] = (int_val >> 8) & 0xFF
	return bytes

func _build_whistle() -> AudioStreamWAV:
	var duration := 0.38
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		# Dual-frequency referee whistle beat
		var f1 := 2600.0
		var f2 := 2750.0
		var flutter := sin(t * 45.0 * TAU) * 0.15
		var w1 := sin(t * (f1 + flutter * 80.0) * TAU)
		var w2 := sin(t * (f2 + flutter * 80.0) * TAU)
		var env := 1.0
		if t < 0.03:
			env = t / 0.03
		elif t > duration - 0.08:
			env = (duration - t) / 0.08
		samples[i] = (w1 + w2) * 0.45 * env
	return _build_stream(_pack_samples(samples))

func _build_kick(is_hard: bool) -> AudioStreamWAV:
	var duration := 0.22 if is_hard else 0.16
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	var start_freq := 210.0 if is_hard else 165.0
	var end_freq := 45.0
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var progress := t / duration
		var freq := lerpf(start_freq, end_freq, progress * progress)
		phase += freq / float(SAMPLE_RATE)
		var sine_val := sin(phase * TAU)
		var env := exp(-progress * (8.5 if is_hard else 11.0))
		var noise := randf_range(-1.0, 1.0) * exp(-progress * 28.0) * 0.4
		samples[i] = (sine_val * 0.8 + noise) * env
	return _build_stream(_pack_samples(samples))

func _build_net() -> AudioStreamWAV:
	var duration := 0.45
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	var filter_acc := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var progress := t / duration
		var white := randf_range(-1.0, 1.0)
		filter_acc = lerpf(filter_acc, white, 0.22)
		var env := sin(progress * PI) * exp(-progress * 2.8)
		samples[i] = filter_acc * env * 0.65
	return _build_stream(_pack_samples(samples))

func _build_post() -> AudioStreamWAV:
	var duration := 0.65
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var c1 := sin(t * 880.0 * TAU) * exp(-t * 8.0)
		var c2 := sin(t * 1760.0 * TAU) * 0.5 * exp(-t * 12.0)
		var c3 := sin(t * 2640.0 * TAU) * 0.25 * exp(-t * 16.0)
		samples[i] = (c1 + c2 + c3) * 0.75
	return _build_stream(_pack_samples(samples))

func _build_save() -> AudioStreamWAV:
	var duration := 0.18
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var progress := t / duration
		var freq := lerpf(120.0, 50.0, progress)
		var thud := sin(t * freq * TAU)
		var slap := randf_range(-1.0, 1.0) * exp(-progress * 20.0) * 0.35
		samples[i] = (thud * 0.7 + slap) * exp(-progress * 9.0)
	return _build_stream(_pack_samples(samples))

func _build_cheer() -> AudioStreamWAV:
	var duration := 2.2
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	var f1 := 0.0
	var f2 := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var white := randf_range(-1.0, 1.0)
		f1 = lerpf(f1, white, 0.12)
		f2 = lerpf(f2, white, 0.25)
		var swell := 0.0
		if t < 0.4:
			swell = t / 0.4
		elif t < 1.4:
			swell = 1.0
		else:
			swell = (duration - t) / 0.8
		samples[i] = (f1 * 0.6 + f2 * 0.4) * swell * 0.7
	return _build_stream(_pack_samples(samples))

func _build_crowd_ambient() -> AudioStreamWAV:
	var duration := 4.0
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	var val := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := randf_range(-1.0, 1.0)
		val = lerpf(val, noise, 0.06)
		var gentle_pulse := 0.7 + 0.3 * sin(t * 0.8 * TAU)
		samples[i] = val * gentle_pulse * 0.3
	return _build_stream(_pack_samples(samples), true)

func _build_slide() -> AudioStreamWAV:
	var duration := 0.35
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	var filter := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var progress := t / duration
		var noise := randf_range(-1.0, 1.0)
		filter = lerpf(filter, noise, 0.32)
		var env := sin(progress * PI) * exp(-progress * 2.2)
		samples[i] = filter * env * 0.7
	return _build_stream(_pack_samples(samples))

func _build_tackle() -> AudioStreamWAV:
	var duration := 0.2
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var progress := t / duration
		var thud := sin(t * 140.0 * TAU) * exp(-progress * 14.0)
		var slap := randf_range(-1.0, 1.0) * exp(-progress * 25.0) * 0.4
		samples[i] = (thud * 0.8 + slap) * 0.9
	return _build_stream(_pack_samples(samples))

func _build_triple_whistle() -> AudioStreamWAV:
	var duration := 1.2
	var count := int(SAMPLE_RATE * duration)
	var samples: Array = []
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var blast_active := false
		var local_t := 0.0
		if t >= 0.0 and t < 0.22:
			blast_active = true
			local_t = t / 0.22
		elif t >= 0.32 and t < 0.54:
			blast_active = true
			local_t = (t - 0.32) / 0.22
		elif t >= 0.65 and t < 1.15:
			blast_active = true
			local_t = (t - 0.65) / 0.50

		if blast_active:
			var f1 := 2600.0
			var f2 := 2750.0
			var flutter := sin(t * 48.0 * TAU) * 0.15
			var w1 := sin(t * (f1 + flutter * 80.0) * TAU)
			var w2 := sin(t * (f2 + flutter * 80.0) * TAU)
			var env := sin(local_t * PI)
			samples[i] = (w1 + w2) * 0.45 * env
		else:
			samples[i] = 0.0
	return _build_stream(_pack_samples(samples))
