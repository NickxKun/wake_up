extends CanvasLayer

## Minimalist, sleek player HUD on the bottom-left with health bar, shield bar, and score counters.

@export var health_component : HealthComponent:
	set(value):
		health_component = value
		if is_node_ready() and health_component != null:
			_bind_health_component()

## Color palette for health states
@export var color_healthy : Color = Color(0.12, 0.82, 0.62, 1.0) # Teal-emerald
@export var color_mid : Color = Color(0.98, 0.72, 0.20, 1.0)     # Amber-gold
@export var color_low : Color = Color(0.95, 0.24, 0.24, 1.0)     # Crimson
@export var color_damage_flash : Color = Color(1.0, 1.0, 1.0, 1.0)# Crisp white flash
@export var color_heal_flash : Color = Color(0.4, 1.0, 0.8, 1.0)  # Cyan flash

## Color palette for shield states
@export var color_shield : Color = Color(0.18, 0.82, 0.98, 1.0)   # Electric cyan
@export var color_shield_flash : Color = Color(1.0, 1.0, 1.0, 1.0)# White flash

@onready var shield_row : HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/ShieldRow") as HBoxContainer
@onready var shield_badge : Label = get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/ShieldBadge") as Label
@onready var shield_bar : ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/BarContainer/ProgressBar") as ProgressBar
@onready var shield_damage_bar : ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/BarContainer/DamageBar") as ProgressBar
@onready var shield_value : Label = get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/ShieldValue") as Label
@onready var shield_status : Label = get_node_or_null("MarginContainer/VBoxContainer/ShieldRow/ShieldStatus") as Label

@onready var operative_row : HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/OperativeRow") as HBoxContainer
@onready var class_tag : Label = get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/ClassTag") as Label
@onready var ability_tag : Label = get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/AbilityTag") as Label
@onready var ability_status : Label = get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/AbilityStatus") as Label
@onready var turret_tag : Label = get_node_or_null("MarginContainer/VBoxContainer/OperativeRow/TurretTag") as Label

@onready var progress_bar : ProgressBar = $MarginContainer/VBoxContainer/HealthRow/BarContainer/ProgressBar
@onready var damage_bar : ProgressBar = $MarginContainer/VBoxContainer/HealthRow/BarContainer/DamageBar
@onready var value_label : Label = $MarginContainer/VBoxContainer/HealthRow/HealthValue
@onready var hp_badge : Label = $MarginContainer/VBoxContainer/HealthRow/HpBadge

@onready var kills_value : Label = $MarginContainer/VBoxContainer/StatsRow/KillsBox/KillsValue
@onready var deaths_value : Label = $MarginContainer/VBoxContainer/StatsRow/DeathsBox/DeathsValue

@onready var pip_0 : ColorRect = $MarginContainer/VBoxContainer/HealthRow/DashRow/PipsBox/Pip0
@onready var pip_1 : ColorRect = $MarginContainer/VBoxContainer/HealthRow/DashRow/PipsBox/Pip1
@onready var pip_2 : ColorRect = $MarginContainer/VBoxContainer/HealthRow/DashRow/PipsBox/Pip2
@onready var cooldown_bar : ProgressBar = $MarginContainer/VBoxContainer/HealthRow/DashRow/CooldownContainer/CooldownBar
@onready var cooldown_status : Label = $MarginContainer/VBoxContainer/HealthRow/DashRow/CooldownStatus
@onready var dash_badge : Label = get_node_or_null("MarginContainer/VBoxContainer/HealthRow/DashRow/DashBadge") as Label

var _fill_style : StyleBoxFlat
var _bar_tween : Tween
var _ghost_tween : Tween
var _flash_tween : Tween
var _pulse_tween : Tween

var _shield_fill_style : StyleBoxFlat
var _shield_bar_tween : Tween
var _shield_ghost_tween : Tween
var _shield_flash_tween : Tween

var _last_kills : int = -1
var _last_deaths : int = -1
var _player_ref : WeakRef = null
var _pips : Array[ColorRect] = []

const COLOR_PIP_FULL : Color = Color(0.2, 0.95, 0.9, 1.0)
const COLOR_PIP_EMPTY : Color = Color(0.12, 0.18, 0.24, 0.65)
const COLOR_PIP_CHARGING : Color = Color(0.98, 0.68, 0.22, 0.85)

func _ready() -> void:
	_setup_styles()
	_pips = [pip_0, pip_1, pip_2]
	if dash_badge != null:
		dash_badge.text = "STAMINA"
	if health_component != null:
		_bind_health_component()

	var char_data : Node = get_node_or_null("/root/CharacterData")
	if char_data != null:
		var cls : int = int(char_data.get("current_class"))
		var rem : float = float(char_data.get("ability_cooldown_remaining"))
		var max_cd : float = float(char_data.call("get_max_cooldown", cls))
		update_operative_display(cls, rem, max_cd)
		if char_data.has_signal("class_changed") and not char_data.class_changed.is_connected(_on_class_changed):
			char_data.class_changed.connect(_on_class_changed)
		if char_data.has_signal("ability_cooldown_updated") and not char_data.ability_cooldown_updated.is_connected(_on_ability_cooldown_updated):
			char_data.ability_cooldown_updated.connect(_on_ability_cooldown_updated)

func _on_class_changed(new_class: int, _info: Dictionary) -> void:
	var char_data : Node = get_node_or_null("/root/CharacterData")
	var rem : float = float(char_data.get("ability_cooldown_remaining")) if char_data != null else 0.0
	var max_cd : float = float(char_data.call("get_max_cooldown", new_class)) if char_data != null else 0.0
	update_operative_display(new_class, rem, max_cd)

func _on_ability_cooldown_updated(remaining: float, max_cd: float) -> void:
	var char_data : Node = get_node_or_null("/root/CharacterData")
	var cls : int = int(char_data.get("current_class")) if char_data != null else 0
	update_operative_display(cls, remaining, max_cd)

func update_operative_display(class_id: int, remaining_cd: float = 0.0, _max_cd: float = 0.0) -> void:
	if not is_instance_valid(class_tag) or not is_instance_valid(ability_tag) or not is_instance_valid(ability_status):
		return
	var char_data : Node = get_node_or_null("/root/CharacterData")
	var cfg : Dictionary = {}
	if char_data != null and char_data.has_method("get_class_config"):
		cfg = char_data.call("get_class_config", class_id)

	var callsign : String = cfg.get("callsign", "Operative")
	var class_name_str : String = cfg.get("name", "Astronaut").to_upper()
	var theme_col : Color = cfg.get("theme_color", Color(0.2, 0.75, 1.0))
	var ab_name : String = cfg.get("ability_name", "Ability")
	var ab_key : String = cfg.get("ability_key", "[F]")

	class_tag.text = "◈ %s // %s" % [callsign.to_upper(), class_name_str]
	class_tag.add_theme_color_override("font_color", theme_col)

	ability_tag.text = "%s %s" % [ab_key, ab_name.to_upper()]

	if remaining_cd <= 0.01:
		ability_status.text = "READY"
		ability_status.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6, 1.0))
	else:
		ability_status.text = "CD: %.1fs" % remaining_cd
		ability_status.add_theme_color_override("font_color", Color(0.98, 0.68, 0.22, 1.0))

func _bind_health_component() -> void:
	if health_component == null:
		return
	_update_display(health_component.health, health_component.health, false)
	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)

	if health_component.has_shield:
		if shield_row != null:
			shield_row.visible = true
		_update_shield_display(health_component.shield, health_component.shield, false)
		if not health_component.shield_changed.is_connected(_on_shield_changed):
			health_component.shield_changed.connect(_on_shield_changed)
		if not health_component.shield_depleted.is_connected(_on_shield_depleted):
			health_component.shield_depleted.connect(_on_shield_depleted)
	else:
		if shield_row != null:
			shield_row.visible = false

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var tree : SceneTree = get_tree()
	if tree == null:
		return

	if _player_ref == null or _player_ref.get_ref() == null:
		var p : Node = tree.get_first_node_in_group("player")
		if p != null:
			bind_player(p)

	if health_component != null and health_component.has_shield and shield_status != null:
		if health_component.is_dead():
			shield_status.text = "OFFLINE"
			shield_status.modulate = Color(0.6, 0.6, 0.6, 0.6)
		elif health_component.shield >= HealthComponent.MAX_SHIELD:
			shield_status.text = "READY"
			shield_status.modulate = Color(0.2, 0.95, 0.9, 0.9)
		elif health_component.shield_regen_timer > 0.0:
			shield_status.text = "REGEN IN %.1fs" % health_component.shield_regen_timer
			shield_status.modulate = Color(0.98, 0.72, 0.22, 0.95)
		else:
			shield_status.text = "CHARGING..."
			var pulse : float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
			shield_status.modulate = Color(0.2, 0.95, 0.9, 0.6 + pulse * 0.4)

	# Update active turret health tag for Engineer
	if turret_tag != null:
		var char_data : Node = get_node_or_null("/root/CharacterData")
		var cur_cls : int = int(char_data.get("current_class")) if char_data != null else 0
		if cur_cls == CharacterDataSingleton.CharacterClass.ENGINEER:
			var turrets := tree.get_nodes_in_group("turret")
			var valid_turrets : Array[Node] = []
			for t in turrets:
				if is_instance_valid(t) and not t.is_queued_for_deletion():
					valid_turrets.append(t)

			if valid_turrets.size() == 1:
				var t : Node = valid_turrets[0]
				var hc : HealthComponent = t.get_node_or_null("HealthComponent") as HealthComponent
				var hp : int = hc.health if hc != null else 100
				turret_tag.text = "• TURRET: %d HP" % hp
				if hp <= 30:
					turret_tag.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
				else:
					turret_tag.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15, 1.0))
				turret_tag.visible = true
			elif valid_turrets.size() >= 2:
				var t1 : Node = valid_turrets[0]
				var t2 : Node = valid_turrets[1]
				var hc1 : HealthComponent = t1.get_node_or_null("HealthComponent") as HealthComponent
				var hc2 : HealthComponent = t2.get_node_or_null("HealthComponent") as HealthComponent
				var hp1 : int = hc1.health if hc1 != null else 100
				var hp2 : int = hc2.health if hc2 != null else 100
				turret_tag.text = "• T1: %d HP | T2: %d HP" % [hp1, hp2]
				turret_tag.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15, 1.0))
				turret_tag.visible = true
			else:
				turret_tag.visible = false
		else:
			turret_tag.visible = false

## Binds to player controller to reflect dash stamina and anti-spam cooldown state.
func bind_player(p: Node) -> void:
	_player_ref = weakref(p)
	if p.has_signal("stamina_changed") and not p.stamina_changed.is_connected(_on_stamina_changed):
		p.stamina_changed.connect(_on_stamina_changed)
	if p.has_signal("dash_cooldown_changed") and not p.dash_cooldown_changed.is_connected(_on_dash_cooldown_changed):
		p.dash_cooldown_changed.connect(_on_dash_cooldown_changed)

	var s : float = p.get("stamina") if "stamina" in p else 3.0
	var ms : float = p.get("max_stamina") if "max_stamina" in p else 3.0
	var cd : float = p.get("dash_cooldown_left") if "dash_cooldown_left" in p else 0.0
	var cdm : float = p.get("dash_cooldown") if "dash_cooldown" in p else 0.35
	update_dash_state(s, ms, cd, cdm)

func _on_stamina_changed(curr: float, max_val: float) -> void:
	var p : Node = _player_ref.get_ref() if _player_ref != null else null
	var cd : float = p.get("dash_cooldown_left") if p != null and "dash_cooldown_left" in p else 0.0
	var cdm : float = p.get("dash_cooldown") if p != null and "dash_cooldown" in p else 0.35
	update_dash_state(curr, max_val, cd, cdm)

func _on_dash_cooldown_changed(remaining: float, max_val: float) -> void:
	var p : Node = _player_ref.get_ref() if _player_ref != null else null
	var s : float = p.get("stamina") if p != null and "stamina" in p else 3.0
	var ms : float = p.get("max_stamina") if p != null and "max_stamina" in p else 3.0
	update_dash_state(s, ms, remaining, max_val)

## Updates the HUD dash charge pips and cooldown timer display.
func update_dash_state(stamina: float, _max_stamina: float, cooldown_left: float, cooldown_max: float) -> void:
	if _pips.is_empty():
		_pips = [pip_0, pip_1, pip_2]

	for i in range(_pips.size()):
		var pip : ColorRect = _pips[i]
		if pip == null:
			continue
		if stamina >= float(i + 1):
			pip.color = COLOR_PIP_FULL
		elif stamina > float(i):
			var frac : float = stamina - float(i)
			pip.color = COLOR_PIP_EMPTY.lerp(COLOR_PIP_CHARGING, frac)
		else:
			pip.color = COLOR_PIP_EMPTY

	# Cooldown bar & status are strictly for the fixed dash cooldown
	if cooldown_left > 0.005:
		var cd_frac : float = clampf(1.0 - cooldown_left / maxf(cooldown_max, 0.01), 0.0, 1.0)
		if cooldown_bar != null:
			cooldown_bar.value = cd_frac * 100.0
		if cooldown_status != null:
			cooldown_status.text = "%.1fs" % cooldown_left
			cooldown_status.add_theme_color_override("font_color", Color(0.98, 0.72, 0.22, 0.95))
	else:
		if cooldown_bar != null:
			cooldown_bar.value = 100.0
		if cooldown_status != null:
			cooldown_status.text = "READY"
			cooldown_status.add_theme_color_override("font_color", Color(0.2, 0.95, 0.9, 0.95))

func _setup_styles() -> void:
	var orig_fill : StyleBox = progress_bar.get_theme_stylebox("fill")
	if orig_fill is StyleBoxFlat:
		_fill_style = orig_fill.duplicate()
	else:
		_fill_style = StyleBoxFlat.new()
		_fill_style.corner_radius_top_left = 4
		_fill_style.corner_radius_top_right = 4
		_fill_style.corner_radius_bottom_right = 4
		_fill_style.corner_radius_bottom_left = 4
	_fill_style.bg_color = color_healthy
	progress_bar.add_theme_stylebox_override("fill", _fill_style)

	if shield_bar != null:
		var orig_shield_fill : StyleBox = shield_bar.get_theme_stylebox("fill")
		if orig_shield_fill is StyleBoxFlat:
			_shield_fill_style = orig_shield_fill.duplicate()
		else:
			_shield_fill_style = StyleBoxFlat.new()
			_shield_fill_style.corner_radius_top_left = 4
			_shield_fill_style.corner_radius_top_right = 4
			_shield_fill_style.corner_radius_bottom_right = 4
			_shield_fill_style.corner_radius_bottom_left = 4
		_shield_fill_style.bg_color = color_shield
		shield_bar.add_theme_stylebox_override("fill", _shield_fill_style)

func _on_shield_changed(new_shield: float, old_shield: float) -> void:
	var took_damage : bool = new_shield < old_shield
	_update_shield_display(new_shield, old_shield, took_damage)

func _on_shield_depleted() -> void:
	if shield_value != null:
		shield_value.text = "0"
	if shield_badge != null:
		var tw : Tween = create_tween()
		shield_badge.modulate = Color(1.0, 0.3, 0.3, 1.0)
		tw.tween_property(shield_badge, "modulate", Color(0.2, 0.85, 1.0, 1.0), 0.5)

func _update_shield_display(new_shield: float, _old_shield: float, took_damage: bool) -> void:
	if shield_value != null:
		shield_value.text = str(ceili(new_shield))

	if shield_bar != null:
		if _shield_bar_tween != null and _shield_bar_tween.is_valid():
			_shield_bar_tween.kill()
		_shield_bar_tween = create_tween()
		_shield_bar_tween.tween_property(shield_bar, "value", new_shield, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if took_damage:
		_flash_shield_bar(color_shield_flash, color_shield)
		if shield_damage_bar != null:
			if _shield_ghost_tween != null and _shield_ghost_tween.is_valid():
				_shield_ghost_tween.kill()
			_shield_ghost_tween = create_tween()
			_shield_ghost_tween.tween_interval(0.25)
			_shield_ghost_tween.tween_property(shield_damage_bar, "value", new_shield, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		if shield_damage_bar != null:
			shield_damage_bar.value = new_shield

func _flash_shield_bar(flash_color: Color, return_color: Color) -> void:
	if _shield_fill_style == null:
		return
	if _shield_flash_tween != null and _shield_flash_tween.is_valid():
		_shield_flash_tween.kill()
	_shield_fill_style.bg_color = flash_color
	_shield_flash_tween = create_tween()
	_shield_flash_tween.tween_property(_shield_fill_style, "bg_color", return_color, 0.2)

func _on_health_changed(new_health : int, old_health : int) -> void:
	var took_damage : bool = new_health < old_health
	_update_display(new_health, old_health, took_damage)

func _update_display(new_health : int, old_health : int, took_damage : bool) -> void:
	value_label.text = str(new_health)
	var target_color : Color = _get_health_color(new_health)

	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween().set_parallel(true)
	_bar_tween.tween_property(progress_bar, "value", float(new_health), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_property(_fill_style, "bg_color", target_color, 0.25)

	if took_damage:
		_flash_bar(color_damage_flash, target_color)
		if _ghost_tween != null and _ghost_tween.is_valid():
			_ghost_tween.kill()
		_ghost_tween = create_tween()
		_ghost_tween.tween_interval(0.25)
		_ghost_tween.tween_property(damage_bar, "value", float(new_health), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		damage_bar.value = float(new_health)
		if new_health > old_health:
			_flash_bar(color_heal_flash, target_color)

	_check_low_health_pulse(new_health)

func _get_health_color(health : int) -> Color:
	var pct : float = float(health) / float(HealthComponent.MAX_HEALTH)
	if pct <= 0.25:
		return color_low
	elif pct <= 0.5:
		return color_mid
	return color_healthy

func _flash_bar(flash_color : Color, return_color : Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_fill_style.bg_color = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fill_style, "bg_color", return_color, 0.2)

func _check_low_health_pulse(health : int) -> void:
	var is_low : bool = health <= 25 and health > 0
	if is_low and _pulse_tween == null:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(hp_badge, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(hp_badge, "modulate", Color(1.0, 1.0, 1.0, 0.6), 0.35).set_trans(Tween.TRANS_SINE)
	elif not is_low and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		hp_badge.modulate = Color.WHITE

## Updates the score indicators (kills and deaths) with kinetic feedback on change.
func update_scores(enemies_killed : int, player_deaths : int) -> void:
	if not is_node_ready():
		await ready

	if enemies_killed != _last_kills:
		var increased : bool = _last_kills != -1 and enemies_killed > _last_kills
		_last_kills = enemies_killed
		kills_value.text = str(enemies_killed)
		if increased:
			_punch_label(kills_value, Color(1.0, 1.0, 0.65), Color.WHITE)

	if player_deaths != _last_deaths:
		var increased : bool = _last_deaths != -1 and player_deaths > _last_deaths
		_last_deaths = player_deaths
		deaths_value.text = str(player_deaths)
		if increased:
			_punch_label(deaths_value, Color(1.0, 0.6, 0.6), Color.WHITE)

func _punch_label(label: Label, flash_color: Color, base_color: Color) -> void:
	label.pivot_offset = label.size / 2.0
	var tween : Tween = create_tween()
	label.modulate = flash_color
	label.scale = Vector2(1.35, 1.35)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", base_color, 0.35)
