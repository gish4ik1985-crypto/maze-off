extends Node2D

# Накал-синергия «огненный след рывка» (GAMEDESIGN.md §4): при высоком жаре
# несомого Накала (режим «Накал») Рывок оставляет короткоживущее огненное
# пятно, замедляющее наступивших врагов. Враги (pursuer.gd) — обычные Node2D
# без физического тела (двигаются по сетке, не CharacterBody2D), поэтому
# область действия проверяется вручную по дистанции каждый кадр (тот же
# приём, что у dark_station.gd), а не через Area2D body_entered.

const RADIUS := 40.0
const LIFETIME := 1.6
const SLOW_DUR := 1.0

var _t: float = 0.0
var _spr: Sprite2D
var _lt: PointLight2D

func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = MazeTextures.make_light(int(RADIUS * 2.2))
	_spr.modulate = Color(1.0, 0.45, 0.15, 0.5)
	add_child(_spr)

	_lt = PointLight2D.new()
	_lt.texture = MazeTextures.make_light(int(RADIUS * 3.2))
	_lt.color = Color(1.0, 0.4, 0.1)
	_lt.energy = 0.6
	_lt.shadow_enabled = false
	add_child(_lt)

func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(1.0 - _t / LIFETIME, 0.0, 1.0)
	if _spr:
		_spr.modulate.a = 0.5 * k
	if _lt:
		_lt.energy = 0.6 * k
	if _t >= LIFETIME:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("apply_burn_slow"):
			if global_position.distance_to(e.global_position) <= RADIUS:
				e.apply_burn_slow(SLOW_DUR)
