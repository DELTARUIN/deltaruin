class_name SaveSystem
extends RefCounted
## 存档系统（游戏级）：按槽读写 JSON 存档，支持复制与清除。
## GameManager 仅转发 API，具体逻辑都在这里；save_dir 可注入，便于测试替换目录。

const SLOT_COUNT := 3 ## 存档槽总数（与 ArchiveSelectState.SLOT_COUNT 一致）

var save_dir := "user://saves" ## 存档目录（测试可注入临时目录）


#region 存档 API

## 保存数据到指定槽；槽号非法或写入失败返回 false
func save_game(slot: int, data: SaveData) -> bool:
	if not _is_valid_slot(slot) or data == null:
		return false
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		GameLogger.error("创建存档目录失败 %s: %s" % [save_dir, error_string(err)], "Save")
		return false
	var f := FileAccess.open(_slot_path(slot) + ".tmp", FileAccess.WRITE)
	if f == null:
		GameLogger.error("写存档失败 slot=%d: %s" % [slot, error_string(FileAccess.get_open_error())], "Save")
		return false
	f.store_string(JSON.stringify(data.to_dict(), "\t"))
	f.close()
	# 先写临时文件再原子替换，避免写一半崩溃时旧档已被截断销毁
	err = DirAccess.rename_absolute(_slot_path(slot) + ".tmp", _slot_path(slot))
	if err != OK:
		GameLogger.error("替换存档失败 slot=%d: %s" % [slot, error_string(err)], "Save")
		return false
	return true


## 新建存档：只写玩家名，地图与游玩时间保持默认（0 / 空）
func create_save(slot: int, player_name: String) -> bool:
	var data := SaveData.new()
	data.player_name = player_name
	return save_game(slot, data)


## 读取指定槽；槽位为空、文件损坏或槽号非法返回 null
func load_game(slot: int) -> SaveData:
	if not _is_valid_slot(slot) or not FileAccess.file_exists(_slot_path(slot)):
		return null
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		GameLogger.warn("读存档失败 slot=%d: %s" % [slot, error_string(FileAccess.get_open_error())], "Save")
		return null
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err == OK and json.data is Dictionary:
		return SaveData.from_dict(json.data)
	GameLogger.warn("槽 %d 存档损坏，忽略" % slot, "Save")
	return null


## 复制源槽到目标槽（整体覆盖目标）；源为空或槽号非法返回 false
func copy_slot(from_slot: int, to_slot: int) -> bool:
	if not _is_valid_slot(from_slot) or not _is_valid_slot(to_slot):
		return false
	var data := load_game(from_slot)
	if data == null:
		GameLogger.warn("复制失败：槽 %d 为空" % from_slot, "Save")
		return false
	return save_game(to_slot, data)


## 清除指定槽；文件不存在视为已清空返回 true，槽号非法返回 false
func clear_slot(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return true
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		GameLogger.error("清除存档失败 slot=%d: %s" % [slot, error_string(err)], "Save")
		return false
	return true


## 全部槽位快照（定长 SLOT_COUNT，空槽为 null），供存档 UI 刷新显示
func get_all_slots() -> Array:
	var slots := []
	slots.resize(SLOT_COUNT)
	for i: int in SLOT_COUNT:
		slots[i] = load_game(i)
	return slots


#endregion


#region 内部

func _is_valid_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		GameLogger.warn("非法槽号: %d" % slot, "Save")
		return false
	return true


func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, slot]


#endregion
