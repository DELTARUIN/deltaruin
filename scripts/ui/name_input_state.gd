class_name NameInputState
extends RefCounted
## 新建存档名字输入状态机（纯逻辑）：A–Z 网格输入与「这就是你的名字」确认页。
## 视图在 name_input.gd，节点结构在 archive_menu.tscn；本类不碰节点。

#region 常量

enum Mode { ENTRY, CONFIRM }
enum Action { NONE, START, EXIT }

const MAX_NAME := 12
const BACKSPACE := "退格"
const DECIDE := "决定"

## 键盘三行：A–J / K–T / U–Z + 退格 + 决定（与视图布局一一对应）
const GRID := [
	["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
	["K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"],
	["U", "V", "W", "X", "Y", "Z", BACKSPACE, DECIDE],
]

#endregion

#region 状态

var mode := Mode.ENTRY
var row := 0
var col := 0
var name := ""
var confirm_yes := true

#endregion


## 打开覆盖层时重置到初始态
func reset() -> void:
	mode = Mode.ENTRY
	row = 0
	col = 0
	name = ""
	confirm_yes = true


#region 输入

func move_up() -> void:
	if mode == Mode.CONFIRM:
		confirm_yes = not confirm_yes
		return
	_set_row(row - 1)


func move_down() -> void:
	if mode == Mode.CONFIRM:
		confirm_yes = not confirm_yes
		return
	_set_row(row + 1)


func move_left() -> void:
	if mode == Mode.CONFIRM:
		confirm_yes = not confirm_yes
		return
	col = posmod(col - 1, _row_size(row))


func move_right() -> void:
	if mode == Mode.CONFIRM:
		confirm_yes = not confirm_yes
		return
	col = posmod(col + 1, _row_size(row))


## 确认键：输入页录入字符；确认页「是」返回 START、「否」回输入页
func press_ok() -> Action:
	if mode == Mode.CONFIRM:
		if confirm_yes:
			return Action.START
		mode = Mode.ENTRY
		return Action.NONE
	var cell: String = GRID[row][col]
	if cell == BACKSPACE:
		name = name.substr(0, name.length() - 1)
	elif cell == DECIDE:
		if name != "":
			mode = Mode.CONFIRM
			confirm_yes = true
	elif name.length() < MAX_NAME:
		name += cell
	return Action.NONE


## 取消键：确认页退回输入页，输入页返回 EXIT 由调用方关闭覆盖层
func press_cancel() -> Action:
	if mode == Mode.CONFIRM:
		mode = Mode.ENTRY
		return Action.NONE
	return Action.EXIT


func debug_text() -> String:
	return "[NameInput] mode=%d row=%d col=%d name=%s yes=%s" \
		% [mode, row, col, name, confirm_yes]

#endregion


#region 内部

## 换行并钳制列号（第三行比前两行短）
func _set_row(r: int) -> void:
	row = posmod(r, GRID.size())
	col = mini(col, _row_size(row) - 1)


func _row_size(r: int) -> int:
	return (GRID[r] as Array).size()

#endregion
