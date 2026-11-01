class_name HealthComponent
extends Node

## Emitted whenever health changes.
signal health_changed(new_health : int, old_health : int)
## Emitted when health reaches the minimum.
signal health_depleted
## Emitted when health reaches the maximum.
signal health_full

## Emitted whenever shield value changes.
signal shield_changed(new_shield : float, old_shield : float)
## Emitted when shield reaches 0.
signal shield_depleted
## Alias for shield_depleted for code readability.
signal shield_broken
## Emitted when shield reaches maximum.
signal shield_full
## Emitted when shield regen begins after delay.
signal shield_regen_started

const MIN_HEALTH : int = 0
const MAX_HEALTH : int = 100

const MIN_SHIELD : float = 0.0
const MAX_SHIELD : float = 100.0

## Whether this entity has a personal regenerating energy shield.
@export var has_shield : bool = false
## Delay in seconds after taking damage before shield regeneration starts.
@export var shield_regen_delay : float = 5.0
## Recovery rate in units per second (0 to 100 in 5 seconds = 20.0).
@export var shield_regen_rate : float = 20.0

## Whether this entity has innate cellular health regeneration (Medic class only).
@export var passive_health_regen : bool = false
## Delay in seconds after taking damage before health regeneration starts.
@export var health_regen_delay : float = 4.0
## Health recovery rate in HP per second (+3 HP/s).
@export var health_regen_rate : float = 3.0

## Current health, always clamped between MIN_HEALTH and MAX_HEALTH.
var health : int = MAX_HEALTH:
	set(value):
		health = clampi(value, MIN_HEALTH, MAX_HEALTH)

## Current shield, always clamped between MIN_SHIELD and MAX_SHIELD.
var shield : float = MAX_SHIELD:
	set(value):
		shield = clampf(value, MIN_SHIELD, MAX_SHIELD)

## Countdown timer until shield regeneration begins.
var shield_regen_timer : float = 0.0
## Countdown timer until health regeneration begins (for Medic).
var health_regen_timer : float = 0.0
var _health_regen_accum : float = 0.0

## When true, prevents any damage (Godmode).
var is_invulnerable : bool = false

func _process(delta: float) -> void:
	if is_dead():
		return

	# Handle Shield Regeneration
	if has_shield and shield < MAX_SHIELD:
		if shield_regen_timer > 0.0:
			shield_regen_timer = maxf(shield_regen_timer - delta, 0.0)
			if shield_regen_timer <= 0.0:
				shield_regen_started.emit()
		else:
			var old_shield : float = shield
			shield = minf(shield + shield_regen_rate * delta, MAX_SHIELD)
			if shield != old_shield:
				shield_changed.emit(shield, old_shield)
			if shield >= MAX_SHIELD:
				shield_full.emit()

	# Handle Passive Health Regeneration (Medic specialization)
	if passive_health_regen and health < MAX_HEALTH:
		if health_regen_timer > 0.0:
			health_regen_timer = maxf(health_regen_timer - delta, 0.0)
		else:
			_health_regen_accum += health_regen_rate * delta
			if _health_regen_accum >= 1.0:
				var hp_to_add : int = int(_health_regen_accum)
				_health_regen_accum -= float(hp_to_add)
				increase_health(hp_to_add)

## Increments health by amount (default 1). Returns amount actually added, clamped to MAX_HEALTH.
func increase_health(amount : int = 1) -> int:
	if amount < 0:
		push_error("HealthComponent: increase_health amount must not be negative.")
		return 0
	if amount == 0:
		return 0
	if is_full():
		return 0
	if is_dead():
		return 0
	var old_health : int = health
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health, old_health)
	if is_full():
		health_full.emit()
	return health - old_health

## Decreases health or shield, clamped to minimums. Returns the amount actually applied.
func decrease_health(amount : int = 1) -> int:
	if is_invulnerable:
		return 0
	if amount < 0:
		push_error("HealthComponent: decrease_health amount must not be negative.")
		return 0
	if amount == 0:
		return 0
	if is_dead():
		return 0

	# Reset Medic health regeneration delay countdown on taking damage
	if passive_health_regen:
		health_regen_timer = health_regen_delay
		_health_regen_accum = 0.0

	# Shield mechanic:
	# Damage is absorbed by shield first.
	# Timer resets to 5.0 seconds on any damage taken.
	# If mid-regen, regen halts immediately because shield_regen_timer is reset.
	# Only once shield hits 0 will player take damage to health.
	if has_shield:
		shield_regen_timer = shield_regen_delay
		if shield > 0.0:
			var old_shield : float = shield
			if shield >= float(amount):
				shield -= float(amount)
				shield_changed.emit(shield, old_shield)
				if shield <= 0.0:
					shield = 0.0
					shield_depleted.emit()
					shield_broken.emit()
				return amount
			else:
				var overflow : float = float(amount) - shield
				shield = 0.0
				shield_changed.emit(0.0, old_shield)
				shield_depleted.emit()
				shield_broken.emit()

				var health_damage : int = ceili(overflow)
				var old_health : int = health
				health = maxi(health - health_damage, MIN_HEALTH)
				health_changed.emit(health, old_health)
				if is_dead():
					health_depleted.emit()
				return int(old_shield) + (old_health - health)

	var old_health : int = health
	health = maxi(health - amount, MIN_HEALTH)
	health_changed.emit(health, old_health)
	if is_dead():
		health_depleted.emit()
	return old_health - health

## Alias for decrease_health to support standard damage calls.
func take_damage(amount : int = 1) -> int:
	return decrease_health(amount)

## Alias for increase_health to support standard heal calls.
func heal(amount : int = 1) -> int:
	return increase_health(amount)

## Increments shield by amount. Clamped to MAX_SHIELD.
func increase_shield(amount : float) -> float:
	if not has_shield or amount <= 0.0 or is_dead():
		return 0.0
	var old_shield : float = shield
	shield = minf(shield + amount, MAX_SHIELD)
	var diff : float = shield - old_shield
	if diff > 0.0:
		shield_changed.emit(shield, old_shield)
		if is_shield_full():
			shield_full.emit()
	return diff

## Restores shield to full and resets regen countdown.
func reset_shield() -> void:
	var old_shield : float = shield
	shield = MAX_SHIELD
	shield_regen_timer = 0.0
	if old_shield != MAX_SHIELD:
		shield_changed.emit(shield, old_shield)
		shield_full.emit()

func is_dead() -> bool:
	return health <= MIN_HEALTH

func is_full() -> bool:
	return health >= MAX_HEALTH

func is_shield_full() -> bool:
	return shield >= MAX_SHIELD

func is_shield_broken() -> bool:
	return shield <= MIN_SHIELD

