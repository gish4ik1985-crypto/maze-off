extends Node

# Глобальные настройки игры (autoload "GameConfig").
# Меняются из меню, читаются при генерации лабиринта.

var cols: int = 16            # ширина лабиринта (клеток)
var rows: int = 10            # высота лабиринта (клеток)
var station_count: int = 8    # число подзарядных станций (базовое)
var player_speed: float = 320.0
var max_energy: float = 1.7   # запас света (макс. заряд)
var drain_per_sec: float = 0.055  # скорость разрядки свечения
var darkness: float = 0.05    # уровень общей темноты (меньше = темнее)
var door_pairs: int = 1       # пар дверей между соседними этажами

var lives: int = 3            # число жизней на уровень

var events_enabled: bool = true       # случайные события
var progressive_enabled: bool = true  # накопительные пассивки

var door_regen_enabled: bool = false  # шанс перегенерации лабиринта при переходе
var door_regen_chance: float = 0.3    # вероятность (0..1)

var darkness_chaser: bool = true      # тьма-преследователь (с уровня 4)

var level: int = 1            # текущий уровень (1..10), растёт при прохождении

# Выбранные пассивные навыки (включаются в меню)
var passives := {
	"save": false,      # разрядка −30%
	"capacity": false,  # макс. заряд +30%
	"charge": false,    # зарядка на станциях +50%
	"range": false,     # радиус свечения +25%
	"legs": false,      # скорость +15%
	"magic": false,     # навыки дешевле и быстрее перезаряжаются
}
