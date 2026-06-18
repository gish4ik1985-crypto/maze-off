extends Node2D

# Тьма-преследователь: медленно ползёт к игроку сквозь стены. Пока игрок
# в её ауре — свет тратится быстрее. Противодействие: щит (останавливает
# разрядку), рывок (оторваться), станции (на подзарядке урона нет).

const SPEED := 95.0
const AURA := 130.0          # радиус ускоренной разрядки
const BLOCK_RADIUS := 55.0   # вплотную — глушит зарядку станции

var target: Node2D = null

func _ready() -> void:
	# Зловещее тёмно-фиолетовое свечение, чтобы тьму было видно приближающейся
	var lt := PointLight2D.new()
	lt.texture = MazeTextures.make_light(170)
	lt.color = Color(0.35, 0.1, 0.5)
	lt.energy = 0.9
	lt.shadow_enabled = false
	add_child(lt)

	var core := Sprite2D.new()
	core.texture = MazeTextures.make_ball(16, Color(0.15, 0.0, 0.2))
	add_child(core)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = global_position.move_toward(target.global_position, SPEED * delta)
	var dist := global_position.distance_to(target.global_position)
	if dist < AURA:
		# Ускоренная разрядка (щит её игнорирует — он вовсе останавливает разрядку)
		target.apply_event("leak", 0.25)
	if dist < BLOCK_RADIUS:
		# Вплотную тьма гасит зарядку станции (малый радиус — соседняя станция работает)
		target.block_charge(0.2)
