extends Node
## 全局日志系统（Autoload 名称：GameLogger）
##
## 用法：
##   GameLogger.info("玩家 %s 加入" % [name], "Network")
##   GameLogger.warn("血量过低", "Combat")
##   GameLogger.error("资源加载失败: %s" % path)
##   GameLogger.debug("帧耗时 %d ms" % ms)
##
## 进阶：
##   if GameLogger.is_level_enabled(GameLogger.Level.DEBUG):
##       GameLogger.debug(heavy_dump())

enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4, OFF = 5 }

const LEVEL_NAMES := ["DEBUG", "INFO", "WARN", "ERROR", "FATAL", "OFF"]
const LEVEL_COLORS := [
	"\u001b[90m",    # DEBUG 灰
	"\u001b[32m",    # INFO  绿
	"\u001b[33m",    # WARN  黄
	"\u001b[31m",    # ERROR 红
	"\u001b[1;91m",  # FATAL 亮红加粗
	"",
]
const ANSI_RESET := "\u001b[0m"
const ANSI_DIM   := "\u001b[2m"

# ---------------- 配置 ----------------
@export_group("过滤等级")
@export var min_console_level: Level = Level.DEBUG
@export var min_file_level:    Level = Level.INFO

@export_group("文件输出")
@export var write_to_file:       bool   = true
@export var log_dir:             String = "user://logs"
@export var log_file_prefix:     String = "game"
@export var max_file_size_kb:    int    = 4096   # 4 MB 触发轮转
@export var max_files:           int    = 10     # 最多保留多少个日志文件
@export var flush_every_write:   bool   = true   # 崩溃也不丢日志

@export_group("格式")
@export var use_colors:     bool = true
@export var include_caller: bool = true

## 每次写日志都会发出，便于接入游戏内控制台 / UI
signal log_emitted(level: int, tag: String, message: String, time: String)

# ---------------- 内部状态 ----------------
var _file: FileAccess = null
var _current_path: String = ""
var _current_size: int = 0
var _self_path: String = ""
var _cached_sec: int = -1
var _cached_time: String = ""


# ============================================================
# 生命周期
# ============================================================
func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_self_path = get_script().resource_path

	# Release 构建默认屏蔽 DEBUG 控制台输出（可按需调整）
	if not OS.is_debug_build():
		min_console_level = maxi(min_console_level, Level.INFO)

	if write_to_file:
		_open_log_file()

	info("日志系统启动 | console=%s file=%s path=%s" % [
		LEVEL_NAMES[min_console_level],
		LEVEL_NAMES[min_file_level],
		_current_path if _file != null else "<disabled>",
	], "GameLogger")


func _exit_tree() -> void:
	close()


# ============================================================
# 公开 API
# ============================================================
func debug(msg: String, tag: String = "", args: Array = []) -> void:
	_log(Level.DEBUG, msg, tag, args)

func info(msg: String, tag: String = "", args: Array = []) -> void:
	_log(Level.INFO, msg, tag, args)

func warn(msg: String, tag: String = "", args: Array = []) -> void:
	_log(Level.WARN, msg, tag, args)

func error(msg: String, tag: String = "", args: Array = []) -> void:
	_log(Level.ERROR, msg, tag, args)

func fatal(msg: String, tag: String = "", args: Array = []) -> void:
	_log(Level.FATAL, msg, tag, args)

func log_at(level: int, msg: String, tag: String = "", args: Array = []) -> void:
	_log(level, msg, tag, args)

## 供 "开销较大的日志前" 判断是否需要构造消息
func is_level_enabled(level: int) -> bool:
	if level >= Level.OFF:
		return false
	return level >= min_console_level \
		or (write_to_file and level >= min_file_level) \
		or log_emitted.has_connections()

## 运行时动态修改过滤等级
func set_levels(console_level: int, file_level: int) -> void:
	min_console_level = console_level as Level
	min_file_level    = file_level as Level

func flush() -> void:
	if _file != null:
		_file.flush()

func close() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


# ============================================================
# 核心输出
# ============================================================
func _log(level: int, msg: String, tag: String, args: Array) -> void:
	if level >= Level.OFF:
		return

	var to_console := level >= min_console_level
	var to_file := write_to_file and _file != null and level >= min_file_level

	if not to_console and not to_file and not log_emitted.has_connections():
		return

	# 支持 GameLogger.info("x=%s", "", [x]) 的可选格式化
	if not args.is_empty():
		msg = msg % args

	var ts: String = _now_string()
	var lvl: String = LEVEL_NAMES[level]
	var tag_str: String = "" if tag.is_empty() else " [%s]" % tag
	var caller_str: String = ""
	if include_caller and OS.is_debug_build():
		caller_str = _caller_suffix()

	# 文件用纯文本
	var plain := "%s [%-5s]%s%s %s" % [ts, lvl, tag_str, caller_str, msg]

	# 控制台用颜色
	if to_console:
		if use_colors:
			var c: String = LEVEL_COLORS[level]
			print("%s%s%s %s[%-5s]%s%s %s%s" % [
				ANSI_DIM, ts, ANSI_RESET,
				c, lvl, ANSI_RESET,
				tag_str + caller_str, msg, ANSI_RESET,
			])
		else:
			print(plain)

	# 文件
	if to_file:
		_write_line(plain)

	log_emitted.emit(level, tag, msg, ts)


# ============================================================
# 文件写入 & 轮转
# ============================================================
func _open_log_file() -> void:
	if not DirAccess.dir_exists_absolute(log_dir):
		var err := DirAccess.make_dir_recursive_absolute(log_dir)
		if err != OK:
			write_to_file = false
			push_warning("[Logger] 无法创建日志目录 %s (err=%d)" % [log_dir, err])
			return

	var date := Time.get_date_string_from_system()          # 2026-10-24
	_current_path = "%s/%s_%s.log" % [log_dir, log_file_prefix, date]
	_current_size = 0

	# 若当天文件已存在，读取现有大小，超限则先轮转
	if FileAccess.file_exists(_current_path):
		var f := FileAccess.open(_current_path, FileAccess.READ)
		if f != null:
			_current_size = f.get_length()
			f.close()

	if _current_size >= max_file_size_kb * 1024:
		_rotate()

	if not _open_current_path():
		write_to_file = false


func _open_current_path() -> bool:
	# READ_WRITE 要求文件已存在；不存在时用 WRITE 新建
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_current_path) else FileAccess.WRITE
	_file = FileAccess.open(_current_path, mode)
	if _file == null:
		push_warning("[Logger] 无法打开日志文件 %s (err=%d)" % [
			_current_path, FileAccess.get_open_error()])
		return false
	_file.seek_end()
	return true


func _write_line(line: String) -> void:
	if _file == null:
		return
	_file.store_line(line)
	if flush_every_write:
		_file.flush()
	_current_size = _file.get_position()   # 精确获取当前文件大小

	# 超限轮转
	if _current_size >= max_file_size_kb * 1024:
		_rotate()
		if not _open_current_path():
			write_to_file = false


func _rotate() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null

	if not FileAccess.file_exists(_current_path):
		_current_size = 0
		return

	var base := _current_path.get_basename()   # user://logs/game_2026-10-24
	var idx := 1
	var target := ""
	while true:
		target = "%s.%d.log" % [base, idx]
		if not FileAccess.file_exists(target):
			break
		idx += 1

	var err := DirAccess.rename_absolute(_current_path, target)
	if err != OK:
		push_warning("[Logger] 轮转日志失败 (err=%d)" % err)

	_current_size = 0
	_cleanup_old_files()


func _cleanup_old_files() -> void:
	if max_files <= 0:
		return
	var dir := DirAccess.open(log_dir)
	if dir == null:
		return

	var names: Array[String] = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir() and n.begins_with(log_file_prefix) and n.ends_with(".log"):
			names.append(n)
		n = dir.get_next()
	dir.list_dir_end()

	if names.size() <= max_files:
		return

	# 按修改时间排序，删除最旧的
	names.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(log_dir.path_join(a)) \
			< FileAccess.get_modified_time(log_dir.path_join(b))
	)

	var remove_count := names.size() - max_files
	for i in remove_count:
		DirAccess.remove_absolute(log_dir.path_join(names[i]))


# ============================================================
# 工具
# ============================================================
## 时间戳：2026-10-24 12:34:56.789（秒级缓存，高频调用友好）
func _now_string() -> String:
	var unix := Time.get_unix_time_from_system()
	var sec := int(unix)
	if sec != _cached_sec:
		_cached_sec = sec
		var dt := Time.get_datetime_dict_from_system()
		_cached_time = "%04d-%02d-%02d %02d:%02d:%02d" % [
			dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
		]
	var msec := int((unix - float(sec)) * 1000.0)
	return "%s.%03d" % [_cached_time, msec]


## 追踪真正调用 GameLogger 的脚本与行号（跳过 game_logger.gd 自身的栈帧）
func _caller_suffix() -> String:
	var stack := get_stack()
	for i in range(1, stack.size()):
		var src: String = stack[i].get("source", "")
		if src == _self_path:
			continue
		var line: int = stack[i].get("line", 0)
		return " [%s:%d]" % [src.get_file(), line]
	return ""
