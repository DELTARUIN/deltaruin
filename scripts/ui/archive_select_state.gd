class_name ArchiveSelectState
extends RefCounted
## 存档选择菜单的纯逻辑状态机（不依赖任何节点，便于 GUT 测试）。
## 渲染与输入由 archive_select.gd 驱动，本类只负责状态与转移规则。

enum State {
	SLOT_SELECTED, ## 选槽：光标在三个存档槽之间
	CONFIRM_OPEN,  ## 二次确认：当前槽就地展开「开始/返回」
}

enum ConfirmItem {
	START, ## 二次确认「开始」
	BACK,  ## 二次确认「返回」
}

## 确认/取消键产生的动作：场景脚本据此发 file_selected / exit_requested 信号
enum Action {
	NONE,   ## 本次操作无动作
	SELECT, ## 确认「开始」
	EXIT,   ## 选槽态按取消
}

#region 常量

const SLOT_COUNT := 3

#endregion

#region 状态字段

var state: State = State.SLOT_SELECTED
var cursor := 0                          ## 当前焦点槽（0 起）
var confirm_item: ConfirmItem = ConfirmItem.START ## 二次确认当前项
var selected_slot := -1                  ## 最近一次确认「开始」的槽号（-1 = 未选择）

#endregion


#region 查询

## 调试信息（F 键打印）
func debug_text() -> String:
	var sub := ""
	if state == State.CONFIRM_OPEN:
		sub = " item=%s" % ConfirmItem.keys()[confirm_item]
	return "state=%s cursor=%d%s" % [State.keys()[state], cursor, sub]

#endregion


#region 转移

## 上移：选槽态在槽间循环；确认态切换「开始/返回」（不切换槽）
func move_up() -> void:
	_move_vertical(-1)


## 下移：同上
func move_down() -> void:
	_move_vertical(1)


## 左移：仅确认态生效，在「开始/返回」间切换
func move_left() -> void:
	_toggle_confirm_item()


## 右移：同左移
func move_right() -> void:
	_toggle_confirm_item()


## 确认键：选槽态展开二次确认；确认态执行开始（产生 SELECT）或返回。
## 返回本次确认产生的动作（SELECT），由场景脚本发信号；菜单自身不冻结。
func press_ok() -> Action:
	var action := Action.NONE
	match state:
		State.SLOT_SELECTED:
			state = State.CONFIRM_OPEN
			confirm_item = ConfirmItem.START
		State.CONFIRM_OPEN:
			if confirm_item == ConfirmItem.START:
				selected_slot = cursor
				action = Action.SELECT
			else:
				state = State.SLOT_SELECTED
	return action


## 取消键：确认态收起确认（焦点不变）；选槽态产生 EXIT 动作。
## 返回本次取消产生的动作（EXIT），由场景脚本发信号。
func press_cancel() -> Action:
	match state:
		State.CONFIRM_OPEN:
			state = State.SLOT_SELECTED
			return Action.NONE
		_:
			return Action.EXIT


## 垂直移动的状态分派
func _move_vertical(dir: int) -> void:
	match state:
		State.SLOT_SELECTED:
			cursor = posmod(cursor + dir, SLOT_COUNT)
		State.CONFIRM_OPEN:
			_toggle_confirm_item()


## 切换二次确认当前项（开始↔返回）；仅确认态生效
func _toggle_confirm_item() -> void:
	if state == State.CONFIRM_OPEN:
		confirm_item = ConfirmItem.BACK if confirm_item == ConfirmItem.START else ConfirmItem.START

#endregion
