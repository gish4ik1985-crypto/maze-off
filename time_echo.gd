extends Node2D

# Эхо времени (GAMEDESIGN.md §7) — тусклый статичный отпечаток: здесь игрок
# бывал в прошлый забег этого же номера уровня (main.gd::_spawn_time_echoes).
# Не анимируется и не тратит ресурсы на _process — просто мягкое пятно света,
# яркость которого зависит от recency (0 — самый ранний участок пути прошлого
# забега, 1 — последний перед победой): свежая память ярче старой.

var recency: float = 0.5

func _ready() -> void:
	var spr := Sprite2D.new()
	spr.texture = MazeTextures.make_light(26)
	var a: float = lerpf(0.05, 0.20, recency)
	spr.modulate = Color(0.6, 0.65, 0.95, a)
	add_child(spr)
