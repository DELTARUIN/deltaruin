class_name ArchiveSelectState
extends RefCounted
## 存档选择菜单的纯逻辑状态机（不依赖任何节点，便于 GUT 测试）。
## 渲染与输入由 archive_select.gd 驱动，本类只负责状态与转移规则。

enum State {
	SLOT_SELECTED,       ## 选槽：光标在三个存档槽之间
	CONFIRM_OPEN,        ## 二次确认：当前槽就地展开「开始/返回」
	BAR_SELECTED,        ## 底部操作栏：2×3 网格
	CLEAR_SELECT,        ## 消除：选择要消除的槽
	CLEAR_CONFIRM,       ## 消除：槽内确认「是/否」
	CLEAR_CONFIRM_AGAIN, ## 消除：第二问「真的要消除吗？」
	COPY_SELECT_SOURCE,  ## 复制：选择源槽
	COPY_SELECT_TARGET,  ## 复制：选择粘贴目标
	COPY_CONFIRM,        ## 复制：覆盖占用目标前确认「是/否」
}

enum ConfirmItem {
	START, ## 二次确认「开始」
	BACK,  ## 二次确认「返回」
}

## 确认/取消键产生的动作：场景脚本据此发信号或调用存档 API
enum Action {
	NONE,   ## 本次操作无动作
	SELECT, ## 确认「开始」
	EXIT,   ## 选槽态按取消
	CLEAR,  ## 确认消除（对象为 cursor 槽）
	COPY,   ## 确认复制（copy_source → copy_target）
	QUIT,   ## 退出程序
	NO_TARGET, ## 消除/复制入口拦截：三槽全空
}

#region 常量

const SLOT_COUNT := 3

const BAR_COLS := 3      ## 操作栏列数
const BAR_COUNT := 6     ## 操作栏项数
const BAR_COPY := 0      ## 复制
const BAR_CLEAR := 1     ## 消除
const BAR_CHAPTER := 2   ## 选择章节（占位）
const BAR_CH4 := 3       ## 第4章存档（占位）
const BAR_NAMES := 4     ## 人名译法（占位）
const BAR_QUIT := 5      ## 退出程序

## 槽内问句文案（视图经 question_text() 取用）
const QUESTION_CLEAR := "消除这份存档吗？"
const QUESTION_CLEAR_AGAIN := "真的要消除吗？"
const QUESTION_COPY := "覆盖这份存档吗？"

#endregion

#region 状态字段

var state: State = State.SLOT_SELECTED
var cursor := 0                          ## 当前焦点槽（0 起）
var confirm_item: ConfirmItem = ConfirmItem.START ## 二次确认当前项
var selected_slot := -1                  ## 最近一次确认「开始」的槽号（-1 = 未选择）
var bar_index := 0                       ## 操作栏焦点项（0 起）
var confirm_yes := false                 ## 消除/复制确认光标是否在「是」
var copy_source := -1                    ## 复制源槽（-1 = 未选）
var copy_target := -1                    ## 复制目标槽（-1 = 未选）
var occupied: Array[bool] = [] ## 各槽是否有档（脚本按存档快照注入，长度 = SLOT_COUNT）


func _init() -> void:
	occupied.resize(SLOT_COUNT)

#endregion


#region 查询

## 调试信息（F 键打印）
func debug_text() -> String:
	var sub := ""
	match state:
		State.CONFIRM_OPEN:
			sub = " item=%s" % ConfirmItem.keys()[confirm_item]
		State.BAR_SELECTED:
			sub = " bar=%d" % bar_index
		State.CLEAR_CONFIRM, State.CLEAR_CONFIRM_AGAIN, State.COPY_CONFIRM:
			sub = " yes=%s" % confirm_yes
	return "state=%s cursor=%d%s" % [State.keys()[state], cursor, sub]


## 光标是否在槽区（决定槽红心显隐）
func is_slot_cursor() -> bool:
	match state:
		State.SLOT_SELECTED, State.CLEAR_SELECT, State.COPY_SELECT_SOURCE, State.COPY_SELECT_TARGET:
			return true
	return false


## 是否处于消除/复制子流程（隐藏操作栏、显示「取消」）
func is_in_flow() -> bool:
	match state:
		State.CLEAR_SELECT, State.CLEAR_CONFIRM, State.CLEAR_CONFIRM_AGAIN, \
		State.COPY_SELECT_SOURCE, State.COPY_SELECT_TARGET, State.COPY_CONFIRM:
			return true
	return false


## 是否处于是/否确认态
func is_yes_no() -> bool:
	match state:
		State.CLEAR_CONFIRM, State.CLEAR_CONFIRM_AGAIN, State.COPY_CONFIRM:
			return true
	return false


## 是否处于消除子流程（标题映射用）
func is_clear_flow() -> bool:
	match state:
		State.CLEAR_SELECT, State.CLEAR_CONFIRM, State.CLEAR_CONFIRM_AGAIN:
			return true
	return false


## 是否处于复制选目标阶段（源槽黄框）
func is_copy_target_stage() -> bool:
	match state:
		State.COPY_SELECT_TARGET, State.COPY_CONFIRM:
			return true
	return false


## 光标槽当前应显示的问句（空串 = 无）
func question_text() -> String:
	if not is_yes_no():
		return ""
	match state:
		State.CLEAR_CONFIRM:
			return QUESTION_CLEAR
		State.CLEAR_CONFIRM_AGAIN:
			return QUESTION_CLEAR_AGAIN
		State.COPY_CONFIRM:
			return QUESTION_COPY
	return ""

#endregion


#region 转移

## 上移：选槽态在槽间循环；确认态切换「开始/返回」；操作栏换行或回槽区
func move_up() -> void:
	_move_vertical(-1)


## 下移：同上
func move_down() -> void:
	_move_vertical(1)


## 左移：确认态切「开始/返回」；操作栏换列；确认框切「是/否」
func move_left() -> void:
	_move_horizontal(-1)


## 右移：同左移
func move_right() -> void:
	_move_horizontal(1)


## 确认键：按当前状态推进；返回本次确认产生的动作（由场景脚本执行）
func press_ok() -> Action:
	match state:
		State.SLOT_SELECTED:
			state = State.CONFIRM_OPEN
			confirm_item = ConfirmItem.START
		State.CONFIRM_OPEN:
			if confirm_item == ConfirmItem.START:
				selected_slot = cursor
				return Action.SELECT
			state = State.SLOT_SELECTED
		State.BAR_SELECTED:
			return _press_ok_on_bar()
		State.CLEAR_SELECT:
			if occupied[cursor]:
				state = State.CLEAR_CONFIRM
				confirm_yes = false
		State.CLEAR_CONFIRM:
			if confirm_yes:
				state = State.CLEAR_CONFIRM_AGAIN
				confirm_yes = false
			else:
				state = State.CLEAR_SELECT
		State.CLEAR_CONFIRM_AGAIN:
			if confirm_yes:
				state = State.BAR_SELECTED
				bar_index = BAR_CLEAR
				return Action.CLEAR
			state = State.CLEAR_CONFIRM
			confirm_yes = false
		State.COPY_SELECT_SOURCE:
			if occupied[cursor]:
				copy_source = cursor
				state = State.COPY_SELECT_TARGET
		State.COPY_SELECT_TARGET:
			return _press_ok_on_copy_target()
		State.COPY_CONFIRM:
			if confirm_yes:
				state = State.BAR_SELECTED
				bar_index = BAR_COPY
				return Action.COPY
			state = State.COPY_SELECT_TARGET
	return Action.NONE


## 取消键：逐级退回；选槽态产生 EXIT 动作
func press_cancel() -> Action:
	match state:
		State.SLOT_SELECTED:
			return Action.EXIT
		State.CONFIRM_OPEN:
			state = State.SLOT_SELECTED
		State.BAR_SELECTED:
			state = State.SLOT_SELECTED
		State.CLEAR_SELECT:
			state = State.BAR_SELECTED
			bar_index = BAR_CLEAR
		State.CLEAR_CONFIRM:
			state = State.CLEAR_SELECT
		State.CLEAR_CONFIRM_AGAIN:
			state = State.CLEAR_CONFIRM
			confirm_yes = false
		State.COPY_SELECT_SOURCE:
			state = State.BAR_SELECTED
			bar_index = BAR_COPY
		State.COPY_SELECT_TARGET:
			state = State.COPY_SELECT_SOURCE
		State.COPY_CONFIRM:
			state = State.COPY_SELECT_TARGET
	return Action.NONE


## 操作栏确认：复制/消除进子流程（全空时拦截）、退出程序产生 QUIT，占位项无动作
func _press_ok_on_bar() -> Action:
	match bar_index:
		BAR_COPY:
			if not occupied.has(true):
				return Action.NO_TARGET
			copy_source = -1
			copy_target = -1
			state = State.COPY_SELECT_SOURCE
		BAR_CLEAR:
			if not occupied.has(true):
				return Action.NO_TARGET
			state = State.CLEAR_SELECT
		BAR_QUIT:
			return Action.QUIT
	return Action.NONE


## 复制目标确认：源槽自身无动作；空目标直接复制；占用目标先确认
func _press_ok_on_copy_target() -> Action:
	if cursor == copy_source:
		return Action.NONE
	copy_target = cursor
	if occupied[cursor]:
		state = State.COPY_CONFIRM
		confirm_yes = false
		return Action.NONE
	state = State.BAR_SELECTED
	bar_index = BAR_COPY
	return Action.COPY


## 垂直移动的状态分派
func _move_vertical(dir: int) -> void:
	match state:
		State.SLOT_SELECTED:
			if dir > 0 and cursor == SLOT_COUNT - 1:
				state = State.BAR_SELECTED
				bar_index = BAR_COPY
			else:
				cursor = posmod(cursor + dir, SLOT_COUNT)
		State.CONFIRM_OPEN:
			_toggle_confirm_item()
		State.BAR_SELECTED:
			var on_second_row := bar_index >= BAR_COLS
			if dir > 0:
				if on_second_row:
					state = State.SLOT_SELECTED
				else:
					bar_index += BAR_COLS
			elif on_second_row:
				bar_index -= BAR_COLS
			else:
				state = State.SLOT_SELECTED
		State.CLEAR_SELECT, State.COPY_SELECT_SOURCE, State.COPY_SELECT_TARGET:
			cursor = posmod(cursor + dir, SLOT_COUNT)
		State.CLEAR_CONFIRM, State.CLEAR_CONFIRM_AGAIN, State.COPY_CONFIRM:
			confirm_yes = not confirm_yes


## 水平移动的状态分派
func _move_horizontal(dir: int) -> void:
	match state:
		State.CONFIRM_OPEN:
			_toggle_confirm_item()
		State.BAR_SELECTED:
			var col := bar_index % BAR_COLS
			bar_index = bar_index - col + posmod(col + dir, BAR_COLS)
		State.CLEAR_CONFIRM, State.CLEAR_CONFIRM_AGAIN, State.COPY_CONFIRM:
			confirm_yes = not confirm_yes


## 切换二次确认当前项（开始↔返回）；仅确认态生效
func _toggle_confirm_item() -> void:
	if state == State.CONFIRM_OPEN:
		confirm_item = ConfirmItem.BACK if confirm_item == ConfirmItem.START else ConfirmItem.START

#endregion
