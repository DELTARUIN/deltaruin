extends CharacterBody2D

# 直线移动速度
@export var speed: float = 70.0

# 斜向移动速度倍率
@export var diagonal_multiplier: float = 1.0 

# 【新增】加速倍率 (2.0 表示按住X键时速度翻倍)
@export var sprint_multiplier: float = 2.0 

# 节点引用
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# 状态记录
var last_direction: String = "down"
var current_anim: String = ""

func _physics_process(delta: float) -> void:
	# 1. 获取输入 (使用 get_axis 避免 get_vector 的强制归一化)
	var x := Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("ui_up", "ui_down")
	var direction := Vector2(x, y)
	
	# 【新增】判断是否正在加速 (必须同时满足：按下X键 且 正在移动)
	var is_sprinting := Input.is_action_pressed("sprint") and direction != Vector2.ZERO
	
	# 2. 计算速度
	var current_speed = speed
	
	# 如果同时按下了两个轴，应用斜向倍率
	if abs(x) > 0.1 and abs(y) > 0.1:
		current_speed *= diagonal_multiplier
		
	# 【新增】如果正在加速，应用加速倍率
	if is_sprinting:
		current_speed *= sprint_multiplier
		
	velocity = direction * current_speed
	move_and_slide()
	
	# 3. 更新动画 (传入 is_sprinting 参数)
	_update_animation(direction, is_sprinting)

# 独立的动画更新函数
func _update_animation(direction: Vector2, is_sprinting: bool) -> void:
	var target_anim: String
	
	if direction != Vector2.ZERO:
		# 移动中：计算主方向
		var new_direction = _get_dominant_direction(direction)
		# 只有方向真正改变时才更新记录，防止斜向抖动
		if new_direction != last_direction:
			last_direction = new_direction
			
		target_anim = "walk_" + last_direction
	else:
		# 静止时：播放最后方向的待机动画
		target_anim = "idle_" + last_direction
		
	# 只有在动画名称改变时才调用 play，防止动画重置卡顿
	if current_anim != target_anim:
		current_anim = target_anim
		# 确保动画存在再播放，防止报错
		if anim_sprite.sprite_frames.has_animation(target_anim):
			anim_sprite.play(target_anim)
		else:
			# 如果名字拼错了，这里会输出警告，方便你排查
			push_warning("找不到动画: " + target_anim + "，请检查 AnimatedSprite2D 的动画命名！")
			
	# 【新增】动态调整动画播放速度，防止加速时脚底打滑
	if is_sprinting:
		anim_sprite.speed_scale = sprint_multiplier
	else:
		anim_sprite.speed_scale = 1.0

# 获取主导方向（四方向判定）
func _get_dominant_direction(dir: Vector2) -> String:
	var abs_x = abs(dir.x)
	var abs_y = abs(dir.y)
	
	# 设置一个微小的死区，避免微小输入导致的方向抖动
	if abs_x < 0.2: abs_x = 0.0
	if abs_y < 0.2: abs_y = 0.0
	
	if abs_x > abs_y:
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"
