extends GutTest
## SaveSystem 存档逻辑测试：读写 roundtrip / 复制覆盖 / 清除 / 越界与坏档容错

const TEST_DIR := "user://saves_gut_test"

var sys: SaveSystem


func before_all() -> void:
	sys = SaveSystem.new()
	sys.save_dir = TEST_DIR


func before_each() -> void:
	_wipe_dir()


func after_all() -> void:
	_wipe_dir()
	DirAccess.remove_absolute(TEST_DIR)


func _make_data(name: String, sec: float, map: String, pos: Vector2) -> SaveData:
	var d := SaveData.new()
	d.player_name = name
	d.playtime_sec = sec
	d.map_id = map
	d.map_pos = pos
	return d


## 清空测试目录（保持用例互相独立、顺序无关）
func _wipe_dir() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)


func test_save_then_load_roundtrip() -> void:
	assert_true(sys.save_game(0, _make_data("Kris", 3725.0, "dark_world", Vector2(12.0, -3.5))))
	var loaded := sys.load_game(0)
	assert_not_null(loaded)
	assert_eq(loaded.player_name, "Kris")
	assert_eq(loaded.playtime_sec, 3725.0)
	assert_eq(loaded.map_id, "dark_world")
	assert_eq(loaded.map_pos, Vector2(12.0, -3.5))


func test_load_missing_returns_null() -> void:
	assert_null(sys.load_game(1))


func test_load_corrupt_returns_null() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var f := FileAccess.open(TEST_DIR + "/slot_2.json", FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	assert_null(sys.load_game(2))


func test_copy_slot_copies_and_overwrites() -> void:
	sys.save_game(0, _make_data("A", 1.0, "m0", Vector2.ONE))
	assert_true(sys.copy_slot(0, 1))
	assert_eq(sys.load_game(1).player_name, "A")
	sys.save_game(2, _make_data("B", 2.0, "m2", Vector2.ZERO))
	assert_true(sys.copy_slot(2, 1))
	assert_eq(sys.load_game(1).player_name, "B", "复制覆盖目标槽原数据")


func test_copy_empty_source_fails() -> void:
	assert_false(sys.copy_slot(2, 0))


func test_clear_slot_then_null() -> void:
	sys.save_game(0, _make_data("A", 1.0, "m", Vector2.ZERO))
	assert_true(sys.clear_slot(0))
	assert_null(sys.load_game(0))
	assert_true(sys.clear_slot(1), "无档槽视为已清空")


func test_out_of_range_slot_rejected() -> void:
	var data := _make_data("X", 0.0, "", Vector2.ZERO)
	assert_false(sys.save_game(-1, data))
	assert_false(sys.save_game(SaveSystem.SLOT_COUNT, data))
	assert_null(sys.load_game(-1))
	assert_null(sys.load_game(SaveSystem.SLOT_COUNT))
	assert_false(sys.copy_slot(-1, 0))
	assert_false(sys.copy_slot(0, SaveSystem.SLOT_COUNT))
	assert_false(sys.clear_slot(-1))


func test_create_save_writes_player_name_and_defaults() -> void:
	assert_true(sys.create_save(0, "KRIS"))
	var loaded := sys.load_game(0)
	assert_not_null(loaded)
	assert_eq(loaded.player_name, "KRIS")
	assert_eq(loaded.playtime_sec, 0.0)
	assert_eq(loaded.map_id, "")
	assert_eq(loaded.map_name, "")
	assert_eq(loaded.map_pos, Vector2.ZERO)


func test_create_save_rejects_bad_slot() -> void:
	assert_false(sys.create_save(-1, "X"))
	assert_false(sys.create_save(SaveSystem.SLOT_COUNT, "X"))


func test_get_all_slots_shape() -> void:
	sys.save_game(1, _make_data("M", 5.0, "mid", Vector2(1.0, 2.0)))
	var slots := sys.get_all_slots()
	assert_eq(slots.size(), 3)
	assert_null(slots[0])
	assert_not_null(slots[1])
	assert_null(slots[2])
	assert_eq((slots[1] as SaveData).player_name, "M")
