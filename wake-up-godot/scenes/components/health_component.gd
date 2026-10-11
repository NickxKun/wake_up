class_name HealthComponent
extends Node

## Emitted whenever health changes.
signal health_changed(new_health : int, old_health : int)
## Emitted when health reaches the minimum.
signal health_depleted
## Emitted when health reaches the maximum.
signal health_full

const MIN_HEALTH : int = 0
const MAX_HEALTH : int = 100

## Current health, always clamped between MIN_HEALTH and MAX_HEALTH.
var health : int = MAX_HEALTH:
	set(value):
		health = clampi(value, MIN_HEALTH, MAX_HEALTH)

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

## Decreases health, clamped to MIN_HEALTH. Returns the amount actually applied.
func decrease_health(amount : int = 1) -> int:
	if amount < 0:
		push_error("HealthComponent: decrease_health amount must not be negative.")
		return 0
	if amount == 0:
		return 0
	if is_dead():
		return 0
	var old_health : int = health
	health = maxi(health - amount, MIN_HEALTH)
	health_changed.emit(health, old_health)
	if is_dead():
		health_depleted.emit()
	return old_health - health

func is_dead() -> bool:
	return health <= MIN_HEALTH

func is_full() -> bool:
	return health >= MAX_HEALTH
