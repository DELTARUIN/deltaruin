class_name SaveData
extends RefCounted
## 单个存档槽的数据（纯逻辑类，可 GUT 单测）。
## 序列化为 JSON 持久化；扩展时只新增字段并在 from_dict 给默认值，旧档可读。

const VERSION := 1 ## 存档格式版本

var player_name := ""            ## 玩家名称
var playtime_sec := 0.0          ## 游玩时间（秒）
var map_id := ""                 ## 所处地图标识（加载定位用）
var map_name := ""               ## 所处地图名称（存档界面显示用）
var map_pos := Vector2.ZERO      ## 地图内坐标


## 序列化为可 JSON 化的字典
func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"player_name": player_name,
		"playtime_sec": playtime_sec,
		"map_id": map_id,
		"map_name": map_name,
		"map_pos": [map_pos.x, map_pos.y],
	}


## 从字典反序列化：缺失或类型不符的字段取默认值、未知键忽略（向前兼容旧档/新档）
static func from_dict(dict: Dictionary) -> SaveData:
	var data := SaveData.new()
	data.player_name = _as_string(dict.get("player_name", ""))
	data.playtime_sec = _as_float(dict.get("playtime_sec", 0.0))
	data.map_id = _as_string(dict.get("map_id", ""))
	data.map_name = _as_string(dict.get("map_name", ""))
	var pos: Variant = dict.get("map_pos", [])
	if pos is Array:
		var x: float = _as_float(pos[0]) if pos.size() > 0 else 0.0
		var y: float = _as_float(pos[1]) if pos.size() > 1 else 0.0
		data.map_pos = Vector2(x, y)
	return data


## 类型守卫：坏档（合法 JSON、错误类型）不抛运行时错误，按缺失处理
static func _as_string(v: Variant) -> String:
	return v if v is String else ""


static func _as_float(v: Variant) -> float:
	return float(v) if (v is float or v is int) else 0.0
