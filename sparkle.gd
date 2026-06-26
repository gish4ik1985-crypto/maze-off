extends CPUParticles2D

# Разовый всплеск светящихся искр; сам удаляется после жизни. Параметры
# (spark_color/amount/speed) задаются снаружи ДО add_child. Используется при
# подборе осколка, прохождении уровня и т.п.

var spark_color: Color = Color(1.0, 0.86, 0.45)
var spark_amount: int  = 16
var spark_speed: float = 180.0

func _ready() -> void:
	texture = MazeTextures.make_ball(6, Color(1, 1, 1))
	one_shot = true
	explosiveness = 1.0
	amount = spark_amount
	lifetime = 0.55
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 6.0
	direction = Vector2(0, -1)
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = spark_speed * 0.35
	initial_velocity_max = spark_speed
	damping_min = 90.0
	damping_max = 170.0
	scale_amount_min = 0.5
	scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([spark_color, Color(spark_color.r, spark_color.g, spark_color.b, 0.0)])
	color_ramp = ramp
	z_index = 4
	emitting = true
	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()
