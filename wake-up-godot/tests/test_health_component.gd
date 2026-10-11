extends SceneTree

var failures : int = 0
var passes : int = 0
var full_count : int = 0
var depleted_count : int = 0
var changes : Array = []

func check(condition : bool, label : String) -> void:
	if condition:
		passes += 1
	else:
		failures += 1
		print("FAIL: ", label)

func _on_changed(new_health : int, old_health : int) -> void:
	changes.append([new_health, old_health])

func _on_full() -> void:
	full_count += 1

func _on_depleted() -> void:
	depleted_count += 1

func _initialize() -> void:
	var hc : HealthComponent = preload("res://scenes/components/health_component.gd").new()
	hc.health_changed.connect(_on_changed)
	hc.health_full.connect(_on_full)
	hc.health_depleted.connect(_on_depleted)

	check(hc.health == 100, "starts at 100")
	check(hc.is_full() and not hc.is_dead(), "full at 100")

	check(hc.increase_health() == 0, "increase at 100 returns 0")
	check(changes.is_empty() and full_count == 0, "increase at 100 emits no signal")

	check(hc.decrease_health(5) == 5, "decrease(5) returns 5")
	check(hc.health == 95, "decrease(5) gives 95")
	check(changes.size() == 1 and changes[0] == [95, 100], "health_changed values on decrease")
	check(not hc.is_full() and not hc.is_dead(), "neither full nor dead at 95")

	changes.clear()
	var inc1 = hc.increase_health()
	var inc2 = hc.increase_health()
	var inc3 = hc.increase_health()
	var inc4 = hc.increase_health()
	var inc5 = hc.increase_health()
	check(inc1 == 1 and inc2 == 1 and inc3 == 1 and inc4 == 1 and inc5 == 1, "increase (5x) each returns 1")
	check(hc.health == 100, "increase (5x) at 95 gives 100")
	check(full_count == 1, "health_full fires once")
	check(changes.size() == 5, "5 health_changed emits on 5 increases")
	check(changes[4] == [100, 99], "health_changed final values")

	check(hc.increase_health() == 0, "increase at 100 returns 0")

	check(hc.decrease_health(0) == 0, "decrease_health(0) returns 0")
	check(hc.health == 100, "decrease(0) leaves health unchanged")

	changes.clear()
	check(hc.decrease_health(-5) == 0, "negative decrease returns 0")
	check(hc.health == 100 and changes.is_empty(), "negative amount leaves health unchanged")

	check(hc.decrease_health(1000) == 100, "decrease(1000) returns 100")
	check(hc.health == 0, "decrease(1000) gives 0")
	check(depleted_count == 1, "health_depleted fires exactly once")
	check(hc.is_dead() and not hc.is_full(), "dead at 0")

	changes.clear()
	check(hc.decrease_health(1) == 0, "decrease at 0 returns 0")
	check(hc.increase_health() == 0, "increase at 0 returns 0")
	check(hc.health == 0, "health stays 0 when dead")
	check(depleted_count == 1 and changes.is_empty(), "no extra signals when dead")

	hc.free()

	full_count = 0
	depleted_count = 0
	changes.clear()
	var hc2 : HealthComponent = preload("res://scenes/components/health_component.gd").new()
	hc2.health_changed.connect(_on_changed)
	hc2.health_full.connect(_on_full)
	hc2.health_depleted.connect(_on_depleted)

	hc2.health = 95
	var inc_ret = hc2.increase_health(10)
	check(inc_ret == 5, "increase_health(10) at 95 returns 5")
	check(hc2.health == 100, "increase_health(10) at 95 gives 100")
	check(full_count == 1, "health_full fires once")

	changes.clear()
	hc2.health = 90
	inc_ret = hc2.increase_health(3)
	check(inc_ret == 3, "increase_health(3) from 90 returns 3")
	check(hc2.health == 93, "increase_health(3) from 90 gives 93")

	changes.clear()
	inc_ret = hc2.increase_health(-5)
	check(inc_ret == 0, "increase_health(-5) returns 0")
	check(hc2.health == 93, "increase_health(-5) leaves health unchanged")
	check(changes.is_empty(), "increase_health(-5) emits no signal")

	changes.clear()
	inc_ret = hc2.increase_health(0)
	check(inc_ret == 0, "increase_health(0) returns 0")
	check(changes.is_empty(), "increase_health(0) emits no signal")

	hc2.health = 100
	var dec_ret = hc2.decrease_health(10)
	check(dec_ret == 10, "decrease_health(10) from 100 returns 10")
	check(hc2.health == 90, "decrease_health(10) from 100 gives 90")

	hc2.free()
	print("Passed: ", passes, " Failed: ", failures)
	quit(1 if failures > 0 else 0)
