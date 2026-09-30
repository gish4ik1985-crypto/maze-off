extends CanvasLayer

# Набор навыков (v6.5, GAMEDESIGN §86). С собой берётся не всё: слоты растут
# по кампании 2 → 3 → 4 (в забеге сразу 4). Экран открывается из паузы и с
# экрана результатов. Клик по навыку в запасе кладёт его в свободный слот, а
# если слоты полны — ждёт клика по слоту, который он заменит.

signal closed

var editable: bool = true        # false — смотреть можно, менять нельзя (погоня)
var _slot_row: HBoxContainer
var _reserve: HFlowContainer
var _msg: Label
var _d_name: Label
var _d_desc: Label
var _pick: String = ""           # навык из запаса, ждущий слот для замены

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameConfig.loadout_auto()
	_build()
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	GameConfig.loadout_auto()
	if not GameConfig.test_mode:
		GameConfig.save_game()
	emit_signal("closed")
	queue_free()

func _info(id: String) -> Dictionary:
	var sm = load("res://skills_menu.gd")
	var en: bool = GameConfig.locale == "en"
	var base: Dictionary = (sm.SKILL_INFO as Dictionary).get(id, {})
	var name_: String = str(base.get("name", id))
	var desc: String = str(base.get("desc", ""))
	if en and (sm.SKILL_INFO_EN as Dictionary).has(id):
		var e: Dictionary = sm.SKILL_INFO_EN[id]
		name_ = str(e.get("name", name_))
		desc = str(e.get("desc", desc))
	if id == "mark":
		name_ = "Mark" if en else "Метка"
		desc = "Burns a mark on your ground: it holds longer than plain smouldering. Paid in Light, not Will." if en else \
			"Ставит на земле горящую метку: она держит землю дольше обычного тления. Платит Светом, а не Волей."
	var key_: String = str(base.get("key", ""))
	if id == "mark":
		key_ = "M"
	return {"name": name_, "key": key_, "desc": desc}

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.06, 1.0)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(700, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = GameConfig.tt("НАБОР НАВЫКОВ", "SKILL LOADOUT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	col.add_child(title)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", 15)
	col.add_child(_msg)

	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 14)
	col.add_child(_slot_row)

	var rl := Label.new()
	rl.text = GameConfig.tt("В запасе (нажми, чтобы взять)", "In reserve (click to take)")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.add_theme_font_size_override("font_size", 15)
	rl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	col.add_child(rl)

	_reserve = HFlowContainer.new()
	_reserve.alignment = FlowContainer.ALIGNMENT_CENTER
	_reserve.add_theme_constant_override("h_separation", 10)
	_reserve.add_theme_constant_override("v_separation", 10)
	col.add_child(_reserve)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.panel_stylebox(Color(0.45, 0.6, 0.9, 0.4)))
	box.custom_minimum_size = Vector2(0, 96)
	col.add_child(box)
	var dv := VBoxContainer.new()
	box.add_child(dv)
	_d_name = Label.new()
	_d_name.add_theme_font_size_override("font_size", 18)
	dv.add_child(_d_name)
	_d_desc = Label.new()
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.add_theme_font_size_override("font_size", 14)
	_d_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	dv.add_child(_d_desc)

	var back_btn := UIStyle.make_button(GameConfig.t("back_arrow"), _close, 130, 44, 18)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left = 20
	back_btn.offset_top = 14
	add_child(back_btn)

func _skill_button(id: String, w: int, h: int) -> Button:
	var d := _info(id)
	var b := UIStyle.make_button("%s  [%s]" % [d["name"], d["key"]], Callable(), w, h, 14)
	b.icon = SkillIcons.make(id, 44)
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.mouse_entered.connect(func() -> void: _describe(id))
	return b

func _describe(id: String) -> void:
	var d := _info(id)
	_d_name.text = "%s  [%s]" % [d["name"], d["key"]]
	_d_name.add_theme_color_override("font_color", SkillIcons.color_of(id))
	_d_desc.text = str(d["desc"])

func _refresh() -> void:
	var gc = GameConfig
	var slots: int = gc.loadout_slots()
	var en: bool = gc.locale == "en"
	if not editable:
		_msg.text = gc.tt("За тобой погоня — набор менять нельзя. Сначала оторвись.", "You are being chased — the loadout can't change. Shake it off first.")
		_msg.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	elif _pick != "":
		_msg.text = gc.tt("Набор полон: нажми слот, который заменит выбранный навык.", "Loadout is full: click the slot the chosen skill will replace.")
		_msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	else:
		_msg.text = gc.tt("Слоты: %d из %d. Апекс берёт форму из навыков набора.", "Slots: %d of %d. The Apex takes its form from your loadout.") % [gc.loadout.size(), slots]
		_msg.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	for c in _slot_row.get_children():
		c.queue_free()
	var cap := 4
	for i in cap:
		var b: Button
		if i < gc.loadout.size() and i < slots:
			var id: String = str(gc.loadout[i])
			b = _skill_button(id, 150, 104)
			b.disabled = not editable
			b.pressed.connect(func() -> void: _on_slot(i))
		elif i < slots:
			b = UIStyle.make_button(gc.tt("пусто", "empty"), Callable(), 150, 104, 15)
			b.disabled = true
			b.process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			var at: int = gc.LOADOUT_SLOT3_LEVEL if i == 2 else gc.LOADOUT_SLOT4_LEVEL
			b = UIStyle.make_button(gc.tt("🔒 с уровня %d", "🔒 from level %d") % at, Callable(), 150, 104, 14)
			b.disabled = true
			b.process_mode = Node.PROCESS_MODE_ALWAYS
		_slot_row.add_child(b)
	for c in _reserve.get_children():
		c.queue_free()
	var any := false
	for id in gc.LOADOUT_POOL:
		if not bool(gc.skills_unlocked.get(id, false)) or gc.loadout.has(id):
			continue
		any = true
		var rb := _skill_button(id, 150, 104)
		rb.disabled = not editable
		if _pick == id:
			rb.modulate = Color(1.0, 0.95, 0.6)
		rb.pressed.connect(func() -> void: _on_reserve(id))
		_reserve.add_child(rb)
	if not any:
		var l := Label.new()
		l.text = gc.tt("Все найденные навыки уже в наборе.", "Every skill you own is already in your loadout.")
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
		_reserve.add_child(l)
	if _d_name.text == "":
		_d_name.text = gc.tt("Наведи на навык", "Hover a skill")

func _on_slot(i: int) -> void:
	if not editable or i >= GameConfig.loadout.size():
		return
	var id: String = str(GameConfig.loadout[i])
	if _pick != "":
		GameConfig.loadout_swap(id, _pick)
		_pick = ""
	else:
		GameConfig.loadout_toggle(id)   # снять
	_refresh()

func _on_reserve(id: String) -> void:
	if not editable:
		return
	if GameConfig.loadout.size() < GameConfig.loadout_slots():
		GameConfig.loadout_toggle(id)
		_pick = ""
	else:
		_pick = "" if _pick == id else id
	_refresh()
