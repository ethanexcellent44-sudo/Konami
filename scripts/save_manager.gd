extends Node

const SAVE_PATH: String = "user://ethan_save.json"

signal save_completed(path: String)
signal save_failed(path: String, error_code: int)
signal load_completed(path: String)
signal load_failed(path: String, error_code: int)

func save_json(data: Dictionary, path: String = SAVE_PATH) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		save_failed.emit(path, open_error)
		return open_error
	file.store_string(JSON.stringify(data, "\t"))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		save_failed.emit(path, write_error)
		return write_error
	save_completed.emit(path)
	return OK

func load_json(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_failed.emit(path, ERR_FILE_NOT_FOUND)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_failed.emit(path, FileAccess.get_open_error())
		return {}
	var contents: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(contents)
	if not parsed is Dictionary:
		load_failed.emit(path, ERR_PARSE_ERROR)
		return {}
	load_completed.emit(path)
	return parsed as Dictionary
