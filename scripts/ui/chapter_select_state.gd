class_name ChapterSelectState
extends RefCounted
## 章节选择菜单的纯逻辑状态机（不依赖任何节点，便于 GUT 测试）。
## 渲染与输入由 chapter_select.gd 驱动，本类只负责状态与转移规则。

enum State {
	ROW_SELECTED, ## 行选中：光标在章节行或页脚项上
	SUBMENU_OPEN, ## 子菜单展开：某行就地展开「游玩/返回」
	FADE_OUT,     ## 渐隐过渡：游玩加载或退出程序
}

enum SubItem {
	PLAY, ## 子菜单「游玩」
	BACK, ## 子菜单「返回」
}

enum Pending {
	NONE, ## 无待办
	PLAY, ## 待办：加载章节
	EXIT, ## 待办：退出程序
}

#region 常量

## 焦点位线性编号：0~7 为章节行，8 为页脚项
const ROW_COUNT := 7
const FOOTER_EXIT := 7
const ITEM_COUNT := 8

#endregion

#region 状态字段

var state: State = State.ROW_SELECTED
var cursor := 0                     ## 当前焦点位（线性编号）
var sub_item: SubItem = SubItem.PLAY ## 子菜单当前项
var pending: Pending = Pending.NONE  ## FADE_OUT 结束后要执行的动作
var loading_row := 0                 ## FADE_OUT(PLAY) 对应的章节行
var locked: Array[bool] = []         ## 各章节行是否锁定（长度 ROW_COUNT）

#endregion


## locked_rows：各章节行锁定状态（长度必须为 ROW_COUNT）
func _init(locked_rows: Array[bool]) -> void:
	assert(locked_rows.size() == ROW_COUNT)
	locked = locked_rows


#region 查询

## 焦点位是否为章节行（区别于页脚项）
func is_row(item: int) -> bool:
	return item >= 0 and item < ROW_COUNT


## 焦点位是否为锁定的章节行（页脚项永远可选）
func is_locked_row(item: int) -> bool:
	return is_row(item) and locked[item]


## 当前焦点是否落在章节行上
func on_row() -> bool:
	return is_row(cursor)


## 调试信息（F 键打印）
func debug_text() -> String:
	var sub := ""
	if state == State.SUBMENU_OPEN:
		sub = " sub=%s" % SubItem.keys()[sub_item]
	return "state=%s cursor=%d%s pending=%s" % [
		State.keys()[state], cursor, sub, Pending.keys()[pending],
	]

#endregion


#region 转移

## 上移：行选中态在线性焦点位间循环（跳过锁定行）；子菜单态切换「游玩/返回」（不切换章节）
func move_up() -> void:
	_move_vertical(-1)


## 下移：同上
func move_down() -> void:
	_move_vertical(1)


## 左移：仅子菜单态生效，在「游玩/返回」间切换
func move_left() -> void:
	_toggle_sub_item()


## 右移：同左移
func move_right() -> void:
	_toggle_sub_item()


## 确认键：行选中态打开子菜单/触发页脚项；子菜单态执行游玩或返回
func press_ok() -> void:
	match state:
		State.ROW_SELECTED:
			if cursor == FOOTER_EXIT:
				_start_fade(Pending.EXIT)
			else:
				state = State.SUBMENU_OPEN
				sub_item = SubItem.PLAY
		State.SUBMENU_OPEN:
			if sub_item == SubItem.PLAY:
				loading_row = cursor
				_start_fade(Pending.PLAY)
			else:
				state = State.ROW_SELECTED
		State.FADE_OUT:
			pass


## 取消键：仅子菜单态生效，收起子菜单且焦点不变
func press_cancel() -> void:
	if state == State.SUBMENU_OPEN:
		state = State.ROW_SELECTED


## FADE_OUT(PLAY) 显示加载字样后、任意键返回菜单时调用
func finish_fade() -> void:
	if state == State.FADE_OUT and pending == Pending.PLAY:
		pending = Pending.NONE
		state = State.ROW_SELECTED


## 垂直移动的状态分派：行选中态移动焦点；子菜单态只切换「游玩/返回」；渐隐态忽略
func _move_vertical(dir: int) -> void:
	match state:
		State.ROW_SELECTED:
			cursor = _next_unlocked_item(cursor, dir)
		State.SUBMENU_OPEN:
			_toggle_sub_item()
		State.FADE_OUT:
			pass


## 切换子菜单当前项（游玩↔返回）；仅子菜单态生效
func _toggle_sub_item() -> void:
	if state == State.SUBMENU_OPEN:
		sub_item = SubItem.BACK if sub_item == SubItem.PLAY else SubItem.PLAY


## 进入渐隐态并记录结束后要执行的动作
func _start_fade(action: Pending) -> void:
	pending = action
	state = State.FADE_OUT


## 下一个可选焦点位：跳过锁定行，页脚项永远可选；找不到返回原位
func _next_unlocked_item(from: int, dir: int) -> int:
	var i := from
	for _attempt: int in ITEM_COUNT:
		i = posmod(i + dir, ITEM_COUNT)
		if not is_locked_row(i):
			return i
	return from

#endregion
