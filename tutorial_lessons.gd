class_name TutorialLessons

# УРОКИ ОБУЧЕНИЯ — по одному понятию на урок (GAMEDESIGN §84, v6.3).
#
# Раньше обучение было тремя «этапами»: в первом одиннадцать понятий подряд
# (стойка, осколок, три навыка, враг, станция, земля, Метка, тяга), а уроки-
# попапы были абзацами по 300-400 знаков. Игра же с v5.7 подаёт всё по одному:
# навыки находят реликвиями, механики приходят раз в 2-3 уровня. Обучение
# повторяет тот же порядок — один урок = одно понятие, короткий мини-лабиринт со
# своим выходом, 2-3 шага, реплика-урок в одно-два предложения.
#
# Формат урока:
#   title / title_en — название в списке уроков и в переходе между ними;
#   size   — размер мини-лабиринта (столбцы, строки);
#   extras — что ставить в лабиринт сверх обычного: "enemy" (безобидный
#            Блуждающий), "pit" (яма-провал), "dark" (тёмная станция);
#   steps  — шаги по порядку; ПОСЛЕДНИЙ всегда "exit" (условие — сама победа).
#
# Формат шага:
#   done   — как засчитывается: move, stance, shard, station, enemy, claim,
#            draft, combo, pit, dark, exit, либо "skill:<id>" (применил навык);
#   target — куда стрелка-указатель: shard, station, exit, enemy, pit, dark;
#   goal / lesson (+ _en) — цель в верхней строке и реплика-урок при выполнении
#            (пустая реплика — без паузы).
#
# ПРАВИЛО: новый тип условия = ветка в main.gd::_tut_step_done И в
# tools/verify.gd (симуляция шага), иначе проверка «каждый шаг выполним» упадёт.

const LESSONS := [
	{
		"title": "Свет и станция", "title_en": "Light and the crystal",
		"size": Vector2i(9, 6), "extras": [],
		"steps": [
			{"done": "move", "target": "",
			 "goal": "Двигайся: стрелки или WASD",
			 "lesson": "Пока идёшь во тьме, твой Свет гаснет. Погаснет совсем — потеряешь жизнь.",
			 "goal_en": "Move: arrow keys or WASD",
			 "lesson_en": "While you move in the dark, your Light fades. If it runs out completely, you lose a life."},
			{"done": "station", "target": "station",
			 "goal": "Дойди до синего кристалла и наберись света",
			 "lesson": "Кристалл — убежище: рядом с ним Свет не гаснет. Здесь же точка возврата.",
			 "goal_en": "Reach the blue crystal and refill your Light",
			 "lesson_en": "A crystal is a refuge: your Light does not fade near it. It is also your checkpoint."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди золотой выход — он не отмечен на карте",
			 "lesson": "",
			 "goal_en": "Find the golden exit. It is not marked on your map",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Осколки и улики", "title_en": "Shards and clues",
		"size": Vector2i(9, 6), "extras": [],
		"steps": [
			{"done": "shard", "target": "shard",
			 "goal": "Собери золотой осколок света",
			 "lesson": "Осколок — глоток Света и УЛИКА о выходе: этаж, сторона света, расстояние. Он же ключ от дверей.",
			 "goal_en": "Collect a golden shard of light",
			 "lesson_en": "A shard is a sip of Light and a CLUE about the exit: floor, compass side, distance. It is also a key for doors."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход. Каждая улика сужает круг поисков",
			 "lesson": "",
			 "goal_en": "Find the exit. Every clue narrows the search",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Тяга воздуха", "title_en": "The draft",
		"size": Vector2i(9, 6), "extras": [],
		"steps": [
			{"done": "draft", "target": "",
			 "goal": "Пройди немного и ОСТАНОВИСЬ — присмотрись к пылинкам",
			 "lesson": "Пылинки плывут к выходу: это тяга воздуха. Она видна, только когда стоишь, и сильнее вблизи выхода.",
			 "goal_en": "Walk a little, then STOP and look at the motes",
			 "lesson_en": "The motes drift toward the exit: that is the draft. It shows only when you stand still, and gets stronger near the exit."},
			{"done": "exit", "target": "exit",
			 "goal": "Иди по течению и найди выход",
			 "lesson": "",
			 "goal_en": "Follow the current and find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Стойка света", "title_en": "Light stance",
		"size": Vector2i(9, 6), "extras": [],
		"steps": [
			{"done": "stance", "target": "",
			 "goal": "Нажми Z, потом X — стойка света (или колесо мыши)",
			 "lesson": "ТУСКЛЫЙ экономит Свет и прячет тебя, но идёшь вслепую. ЯРКИЙ видит дальше, но горит быстрее и заметен издалека.",
			 "goal_en": "Press Z, then X: light stance (or the mouse wheel)",
			 "lesson_en": "DIM saves Light and hides you, but you walk near-blind. BRIGHT sees farther, but burns faster and is seen from afar."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход в удобной тебе стойке",
			 "lesson": "",
			 "goal_en": "Find the exit in the stance you like",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Вспышка", "title_en": "Flash",
		"size": Vector2i(11, 7), "extras": ["enemy"],
		"steps": [
			{"done": "skill:flash", "target": "",
			 "goal": "Нажми Q — Вспышка, чтобы осмотреться",
			 "lesson": "Вспышка озаряет всё вокруг, а в упор БЬЁТ врага. Но яркий свет выдаёт тебя.",
			 "goal_en": "Press Q: Flash, to look around",
			 "lesson_en": "Flash lights up everything around you and HITS an enemy point-blank. But bright light gives you away."},
			{"done": "enemy", "target": "enemy",
			 "goal": "Впереди враг. Подойди и отбейся Вспышкой (Q)",
			 "lesson": "Контакт с врагом гасит Свет. Вспышка в упор бьёт его.",
			 "goal_en": "An enemy ahead. Approach it and fend it off with Flash (Q)",
			 "lesson_en": "Enemy contact drains your Light. A point-blank Flash hits it."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Рывок и ямы", "title_en": "Dash and pits",
		"size": Vector2i(11, 7), "extras": ["pit"],
		"steps": [
			{"done": "skill:dash", "target": "",
			 "goal": "Нажми Shift — Рывок, чтобы сорваться с места",
			 "lesson": "Рывок — быстрый бросок. Сквозь врага он таран: урон ему, не тебе.",
			 "goal_en": "Press Shift: Dash, to burst away",
			 "lesson_en": "Dash is a quick lunge. Through an enemy it is a tackle: damage to it, not to you."},
			{"done": "pit", "target": "pit",
			 "goal": "Впереди яма — разгонись и сделай Рывок (Shift) через неё",
			 "lesson": "Яма — как стена, но во время Рывка ты пролетаешь сквозь неё.",
			 "goal_en": "A pit ahead: get a run-up and Dash (Shift) across it",
			 "lesson_en": "A pit blocks you like a wall, but a Dash carries you straight through it."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Тление", "title_en": "Smother",
		"size": Vector2i(11, 7), "extras": ["enemy"],
		"steps": [
			{"done": "skill:smother", "target": "enemy",
			 "goal": "Впереди враг. Нажми R — Тление, чтобы спрятаться",
			 "lesson": "Тление гасит тебя до искры: враги теряют след. Медленно, но невидимо.",
			 "goal_en": "An enemy ahead. Press R: Smother, to hide",
			 "lesson_en": "Smother dims you to a spark: enemies lose your trail. Slow, but invisible."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Своя земля и Метка", "title_en": "Held ground and the Mark",
		"size": Vector2i(9, 6), "extras": [],
		"steps": [
			{"done": "claim", "target": "",
			 "goal": "Пройди по коридору и оглянись — за тобой остаётся тлеющий след",
			 "lesson": "Клетки, по которым ты прошёл, тлеют: это ТВОЯ земля, на ней Свет тратится медленнее. Тьма отбирает её тем быстрее, чем ярче ты горишь.",
			 "goal_en": "Walk down the corridor and look back: a smouldering trail stays behind you",
			 "lesson_en": "The cells you walk keep smouldering: that ground is YOURS, and Light drains slower on it. The dark takes it back faster the brighter you burn."},
			{"done": "skill:mark", "target": "",
			 "goal": "Нажми M — Метка, чтобы приколоть эту клетку",
			 "lesson": "Метка держит клетку своей 45 секунд. Цена — кусок Света, а не Воли.",
			 "goal_en": "Press M: Mark, to pin this cell",
			 "lesson_en": "A Mark holds a cell as yours for 45 seconds. It costs a chunk of Light, not Will."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Видеть сквозь тьму", "title_en": "Seeing through the dark",
		"size": Vector2i(11, 7), "extras": ["enemy"],
		"steps": [
			{"done": "skill:sonar", "target": "",
			 "goal": "Нажми E — Сонар, чтобы увидеть планировку сквозь стены",
			 "lesson": "Сонар — разведка, не бой: кольцо проходит сквозь стены, послесвечение держит обзор.",
			 "goal_en": "Press E: Sonar, to see the layout through the walls",
			 "lesson_en": "Sonar is recon, not combat: the ring passes through walls and its afterglow keeps you seeing."},
			{"done": "skill:reveal", "target": "",
			 "goal": "Нажми F — Озарение, чтобы разогнать тьму",
			 "lesson": "Озарение раздвигает тьму на весь этаж на несколько секунд. Заряжается от осколков и станций.",
			 "goal_en": "Press F: Reveal, to push back the dark",
			 "lesson_en": "Reveal pushes the dark back across the whole floor for a few seconds. It charges from shards and stations."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Куда идти", "title_en": "Which way to go",
		"size": Vector2i(11, 7), "extras": [],
		"steps": [
			{"done": "skill:guide", "target": "",
			 "goal": "Нажми G — Искра, она укажет путь",
			 "lesson": "Искра сама летит по кратчайшему маршруту: сперва к осколкам, потом к выходу.",
			 "goal_en": "Press G: Guide, it shows the way",
			 "lesson_en": "The spark flies the shortest route on its own: first to shards, then to the exit."},
			{"done": "skill:pulse", "target": "",
			 "goal": "Нажми B — Пульс, чтобы включить звуковой ориентир",
			 "lesson": "Пульс — звуковой ориентир: «пик» учащается, когда идёшь к выходу или к неизведанным коридорам.",
			 "goal_en": "Press B: Pulse, to turn on the audio guide",
			 "lesson_en": "Pulse is an audio guide: the beep quickens as you head toward the exit or unexplored corridors."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Щит и комбо", "title_en": "Shield and the combo",
		"size": Vector2i(11, 7), "extras": ["enemy"],
		"steps": [
			{"done": "skill:shield", "target": "",
			 "goal": "Нажми C — Щит, чтобы поставить защиту",
			 "lesson": "Щит замораживает врага при контакте вместо урона по тебе. Замороженный враг уязвим: +1 урона от любого удара.",
			 "goal_en": "Press C: Shield, to raise a guard",
			 "lesson_en": "Shield freezes an enemy on contact instead of hurting you. A frozen enemy is vulnerable: +1 damage from any hit."},
			{"done": "combo", "target": "enemy",
			 "goal": "Держи Щит и сделай Рывок рядом с врагом — комбо «Щит + Рывок»",
			 "lesson": "Рывок под щитом замораживает врага И бьёт тараном — сильнее, чем по отдельности.",
			 "goal_en": "Hold Shield and Dash near the enemy: the «Shield + Dash» combo",
			 "lesson_en": "Dashing while shielded freezes the enemy AND rams it: stronger than either alone."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
	{
		"title": "Тёмная станция", "title_en": "The dark station",
		"size": Vector2i(11, 7), "extras": ["dark"],
		"steps": [
			{"done": "dark", "target": "dark",
			 "goal": "Впереди тёмная воронка — она тянет твой Свет. Погаси её Вспышкой (Q) или Сонаром (E)",
			 "lesson": "Тёмная станция — воронка: пьёт Свет и подпитывает врагов рядом. Гаси активным навыком или встань у станции света.",
			 "goal_en": "A dark funnel ahead drains your Light. Douse it with Flash (Q) or Sonar (E)",
			 "lesson_en": "A dark station is a funnel: it drinks your Light and buffs enemies nearby. Douse it with a skill or stand near a light station."},
			{"done": "exit", "target": "exit",
			 "goal": "Найди выход",
			 "lesson": "",
			 "goal_en": "Find the exit",
			 "lesson_en": ""},
		],
	},
]

static func count() -> int:
	return LESSONS.size()

static func title_of(i: int) -> String:
	var d: Dictionary = LESSONS[clampi(i, 0, LESSONS.size() - 1)]
	return str(d["title_en"]) if GameConfig.locale == "en" else str(d["title"])

# Поле шага на текущем языке (goal / lesson).
static func field(step: Dictionary, key: String) -> String:
	if GameConfig.locale == "en":
		return str(step.get(key + "_en", step.get(key, "")))
	return str(step.get(key, ""))
