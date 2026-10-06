extends SceneTree

# Одноразовый зонд FPS (ROADMAP 3.3): окно на ~15 с, грузит уровень N,
# после прогрева меряет средний FPS за 6 с и печатает FPSRESULT.
# Запуск (ОКОННЫЙ, не headless — нужен реальный рендер):
#   set PROBE_LEVEL=45 && godot --path . -s res://tools/fps_probe.gd
# Удалить после снятия базовой линии.

var level := 1
var frames := 0
var phase := "load"
var sample_frames := 0
var sample_t := 0.0
var load_t0 := 0.0
var load_done := false

func _init() -> void:
	var env := OS.get_environment("PROBE_LEVEL")
	level = int(env) if env != "" else 1

func _process(d: float) -> bool:
	var gc = root.get_node("GameConfig")
	gc.test_mode = true
	# Меряем ЗАПАС: снимаем vsync и лимит кадров, иначе зонд упирается в
	# потолок 60 и не показывает, есть ли голова до слабого железа.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	frames += 1
	match phase:
		"load":
			if frames == 1:
				load_t0 = Time.get_ticks_msec()
				gc.level = level
				change_scene_to_file("res://main.tscn")
			if frames >= 30 and current_scene != null \
					and current_scene.has_method("_cell_neighbors"):
				var ms := Time.get_ticks_msec() - int(load_t0)
				print("FPSLOAD|level=%d|load_ms=%d" % [level, ms])
				phase = "warm"
				frames = 0
		"warm":
			# Прогрев 120 кадров — компиляция шейдеров, кэш текстур.
			if frames >= 120:
				phase = "sample"
				sample_t = 0.0
				sample_frames = 0
		"sample":
			sample_t += d
			sample_frames += 1
			if sample_t >= 6.0:
				print("FPSRESULT|level=%d|fps=%.1f|frames=%d" % [
					level, sample_frames / sample_t, sample_frames])
				quit()
	return false
