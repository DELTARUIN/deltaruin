extends GutTest
## SaveData 存档数据类测试：JSON 序列化 roundtrip / 缺失字段默认值 / 未知键容错


func test_to_dict_from_dict_roundtrip() -> void:
	var data := SaveData.new()
	data.player_name = "Kris"
	data.playtime_sec = 3725.0
	data.map_id = "dark_world_ch1"
	data.map_name = "黑暗世界"
	data.map_pos = Vector2(120.5, -64.0)

	var loaded := SaveData.from_dict(data.to_dict())
	assert_eq(loaded.player_name, "Kris")
	assert_eq(loaded.playtime_sec, 3725.0)
	assert_eq(loaded.map_id, "dark_world_ch1")
	assert_eq(loaded.map_name, "黑暗世界")
	assert_eq(loaded.map_pos, Vector2(120.5, -64.0))


func test_to_dict_shape() -> void:
	var data := SaveData.new()
	data.player_name = "Susie"
	data.playtime_sec = 90.0
	data.map_id = "field"
	data.map_name = "草原"
	data.map_pos = Vector2(3.0, 4.0)

	var dict := data.to_dict()
	assert_eq(dict.get("version"), SaveData.VERSION)
	assert_eq(dict.get("player_name"), "Susie")
	assert_eq(dict.get("playtime_sec"), 90.0)
	assert_eq(dict.get("map_id"), "field")
	assert_eq(dict.get("map_name"), "草原")
	assert_eq(dict.get("map_pos"), [3.0, 4.0])


func test_from_dict_missing_fields_uses_defaults() -> void:
	var loaded := SaveData.from_dict({})
	assert_not_null(loaded)
	assert_eq(loaded.player_name, "")
	assert_eq(loaded.playtime_sec, 0.0)
	assert_eq(loaded.map_id, "")
	assert_eq(loaded.map_name, "")
	assert_eq(loaded.map_pos, Vector2.ZERO)


func test_from_dict_ignores_unknown_keys() -> void:
	var loaded := SaveData.from_dict({"hp": 5, "player_name": "Ralsei"})
	assert_not_null(loaded)
	assert_eq(loaded.player_name, "Ralsei")
	assert_eq(loaded.playtime_sec, 0.0)


func test_from_dict_partial_map_pos() -> void:
	var loaded := SaveData.from_dict({"map_pos": [7.5]})
	assert_eq(loaded.map_pos, Vector2(7.5, 0.0))


func test_from_dict_wrong_typed_fields_defaults() -> void:
	# 合法 JSON 但字段类型错（手改档）：不抛运行时错误，按缺失处理
	var loaded := SaveData.from_dict({
		"player_name": 123,
		"playtime_sec": "abc",
		"map_id": [],
		"map_pos": ["a", "b"],
	})
	assert_not_null(loaded)
	assert_eq(loaded.player_name, "")
	assert_eq(loaded.playtime_sec, 0.0)
	assert_eq(loaded.map_id, "")
	assert_eq(loaded.map_pos, Vector2.ZERO)
