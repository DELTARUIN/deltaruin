extends GutTest
## GameLogger 全局日志系统测试：等级过滤 / 信号 / args 格式化 / 文件写入与轮转

const LoggerScript := preload("res://scripts/autoload/game_logger.gd")
const TEST_DIR := "user://logs_test_game_logger"

var logger: Node = null
var captured: Array = []


func before_each() -> void:
	captured = []
	_cleanup_dir()
	logger = LoggerScript.new()


func after_each() -> void:
	if logger != null:
		logger.close()
		logger.free()
		logger = null
	_cleanup_dir()


## 测试用例结束后清空测试日志目录
func _cleanup_dir() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(TEST_DIR.path_join(n))
		n = dir.get_next()
	dir.list_dir_end()


## 读取测试目录下所有 .log 文件内容拼成一个字符串
func _read_all_logs() -> String:
	var text := ""
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return text
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir() and n.ends_with(".log"):
			var f := FileAccess.open(TEST_DIR.path_join(n), FileAccess.READ)
			if f != null:
				text += f.get_as_text()
				f.close()
		n = dir.get_next()
	dir.list_dir_end()
	return text


# ============================================================
# 等级过滤
# ============================================================
func test_is_level_enabled_follows_console_level() -> void:
	logger.write_to_file = false
	add_child(logger)
	assert_true(logger.is_level_enabled(LoggerScript.Level.DEBUG), "默认 DEBUG 级别下全开")
	logger.set_levels(LoggerScript.Level.ERROR, LoggerScript.Level.OFF)
	assert_false(logger.is_level_enabled(LoggerScript.Level.INFO), "console=ERROR 时 INFO 被过滤")
	assert_true(logger.is_level_enabled(LoggerScript.Level.FATAL), "FATAL 始终放行")


func test_is_level_enabled_off_returns_false() -> void:
	logger.write_to_file = false
	add_child(logger)
	assert_false(logger.is_level_enabled(LoggerScript.Level.OFF), "OFF 级别恒为 false")


func test_is_level_enabled_ignores_signal_connections() -> void:
	# 无信号连接、console=OFF、文件关闭时，任何级别都不启用
	logger.write_to_file = false
	add_child(logger)
	logger.set_levels(LoggerScript.Level.OFF, LoggerScript.Level.OFF)
	assert_false(logger.is_level_enabled(LoggerScript.Level.DEBUG), "全部关闭时不启用")
	# 连接信号后 is_level_enabled 恢复 true（UI 控制台需要完整流）
	logger.log_emitted.connect(func(_l: int, _t: String, _m: String, _ts: String) -> void: pass)
	assert_true(logger.is_level_enabled(LoggerScript.Level.DEBUG), "有信号订阅者时始终启用")


func test_file_level_filters_file_output() -> void:
	logger.write_to_file = true
	logger.log_dir = TEST_DIR
	logger.set_levels(LoggerScript.Level.DEBUG, LoggerScript.Level.WARN)
	add_child(logger)
	logger.info("should_not_appear")
	logger.warn("should_appear")
	logger.close()
	var text := _read_all_logs()
	assert_false(text.contains("should_not_appear"), "file_level=WARN 时 INFO 不写文件")
	assert_true(text.contains("should_appear"), "WARN 写入文件")


# ============================================================
# 信号与格式化
# ============================================================
func test_log_emitted_signal_carries_level_tag_message() -> void:
	logger.write_to_file = false
	add_child(logger)
	logger.log_emitted.connect(func(level: int, tag: String, msg: String, _ts: String) -> void:
		captured.append([level, tag, msg]))
	logger.warn("血量过低", "Combat")
	assert_eq(captured.size(), 1, "应发出一次信号")
	assert_eq(captured[0][0], LoggerScript.Level.WARN)
	assert_eq(captured[0][1], "Combat")
	assert_eq(captured[0][2], "血量过低")


func test_args_formatting() -> void:
	logger.write_to_file = false
	add_child(logger)
	logger.log_emitted.connect(func(_l: int, _t: String, msg: String, _ts: String) -> void:
		captured.append(msg))
	logger.info("x=%s y=%d", "", ["abc", 42])
	assert_eq(captured[0], "x=abc y=42", "args 数组应格式化进消息")


func test_level_above_off_is_dropped() -> void:
	logger.write_to_file = false
	add_child(logger)
	logger.log_emitted.connect(func(_l: int, _t: String, _m: String, _ts: String) -> void:
		captured.append(1))
	logger.log_at(LoggerScript.Level.OFF, "dropped")
	logger.log_at(99, "dropped")
	assert_eq(captured.size(), 0, ">= OFF 的级别直接丢弃")


func test_set_levels_clamps_values_via_as() -> void:
	logger.write_to_file = false
	add_child(logger)
	logger.set_levels(3, 2)
	assert_eq(logger.min_console_level, 3)
	assert_eq(logger.min_file_level, 2)


# ============================================================
# 文件写入与轮转
# ============================================================
func test_file_output_contains_plain_line() -> void:
	logger.write_to_file = true
	logger.log_dir = TEST_DIR
	add_child(logger)
	logger.info("hello file", "Tag")
	logger.close()
	var text := _read_all_logs()
	assert_true(text.contains("hello file"), "消息写入文件")
	assert_true(text.contains("[INFO ]"), "行内含等级名（%-5s 左对齐）")
	assert_true(text.contains("[Tag]"), "行内含标签")


func test_rotation_creates_numbered_file() -> void:
	logger.write_to_file = true
	logger.log_dir = TEST_DIR
	logger.max_file_size_kb = 1  # 1KB 即轮转
	add_child(logger)
	var filler := "x".repeat(100)
	for i in 30:
		logger.info("%s %d" % [filler, i])
	logger.close()
	var rotated: String = logger._current_path.get_basename() + ".1.log"
	assert_true(FileAccess.file_exists(rotated), "超限后应产生 .1.log 轮转文件")
