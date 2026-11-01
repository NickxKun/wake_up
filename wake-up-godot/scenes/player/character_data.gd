class_name CharacterDataSingleton
extends Node

## Central repository and manager for playable character classes and operative specializations.
## Defines stats, starter weapons, passive perks, active abilities, and visual identities.

signal class_changed(new_class: int, class_info: Dictionary)
signal ability_used(class_id: int, cooldown: float)
signal ability_cooldown_updated(remaining: float, max_cooldown: float)

enum CharacterClass {
	ASTRONAUT = 0,
	ENGINEER = 1,
	MEDIC = 2,
	EXPLORER = 3,
}

const CLASS_CONFIGS : Dictionary = {
	CharacterClass.ASTRONAUT: {
		"id": CharacterClass.ASTRONAUT,
		"name": "Astronaut",
		"callsign": "Vanguard-01",
		"role": "Balanced Combatant",
		"description": "Standard expeditionary vanguard. Well-rounded combatant equipped with an energy sidearm, balanced agility, and a throwable high-explosive Frag Grenade [MMB].",
		"theme_color": Color(0.2, 0.75, 1.0), # Crisp Cyan
		"secondary_color": Color(0.9, 0.95, 1.0),
		"starter_weapon": 0, # WeaponType.BASIC (Pistol)
		"starter_weapon_name": "Energy Pistol",
		"has_pistol": true,
		"passive_name": "Standard Systems",
		"passive_desc": "Equipped with balanced thrusters and standard kinetic shields.",
		"ability_name": "Frag Grenade",
		"ability_key": "[MMB] Frag Grenade",
		"ability_cooldown": 8.0,
		"camera_size": 4.0,
		"radar_radius": 26.0,
		"can_drive_truck": false,
		"vehicle_weapons": false,
	},
	CharacterClass.ENGINEER: {
		"id": CharacterClass.ENGINEER,
		"name": "Engineer",
		"callsign": "Forge-03",
		"role": "Combat Architect",
		"description": "Defensive mastermind. Deploys autonomous sentry turrets that draw enemy aggro away from him. Starts with a heavy repair wrench and no sidearm.",
		"theme_color": Color(1.0, 0.55, 0.1), # Hazard Orange
		"secondary_color": Color(0.18, 0.20, 0.24),
		"starter_weapon": 5, # WeaponType.WRENCH
		"starter_weapon_name": "Titanium Hydro-Wrench",
		"has_pistol": false, # Strictly no basic pistol!
		"passive_name": "Aggro Decoy & Field Repair",
		"passive_desc": "Hostile bots prioritize attacking active turrets. Wrench repairs damaged turrets and vehicles.",
		"ability_name": "Deploy Sentry Turret",
		"ability_key": "[F]",
		"ability_cooldown": 12.0,
		"camera_size": 4.0,
		"radar_radius": 26.0,
		"can_drive_truck": false,
		"vehicle_weapons": false,
	},
	CharacterClass.MEDIC: {
		"id": CharacterClass.MEDIC,
		"name": "Medic",
		"callsign": "Lifeline-02",
		"role": "Field Surgeon",
		"description": "Team life-support specialist and the sole source of medical restoration. Equipped with a Compact Bio-Shotgun for point-blank defense, innate cellular health self-repair, and expanding Nanite Healing Surge.",
		"theme_color": Color(0.1, 0.9, 0.55), # Emerald Green / Teal
		"secondary_color": Color(0.95, 0.25, 0.35), # Medical Red Accent
		"starter_weapon": 1, # WeaponType.SHOTGUN
		"starter_weapon_name": "Bio-Shotgun",
		"has_pistol": false,
		"passive_name": "Cellular Regeneration",
		"passive_desc": "Innate passive Health recovery (+3 HP/s after 4s without damage). Sole operative with living tissue regeneration.",
		"ability_name": "Nanite Healing Surge",
		"ability_key": "[F]",
		"ability_cooldown": 12.0,
		"camera_size": 4.0,
		"radar_radius": 26.0,
		"can_drive_truck": false,
		"vehicle_weapons": false,
	},
	CharacterClass.EXPLORER: {
		"id": CharacterClass.EXPLORER,
		"name": "Explorer",
		"callsign": "Pathfinder-04",
		"role": "Frontier Scout",
		"description": "Wide-spectrum reconnaissance scout armed with a high-damage Marksman Rifle. Features extended battlefield visibility, 38m radar radius, heavy transport certification, and rear Gatling Turret bed deployment.",
		"theme_color": Color(0.95, 0.78, 0.25), # Expedition Gold / Amber
		"secondary_color": Color(0.28, 0.36, 0.22), # Olive Drab / Bronze
		"starter_weapon": 2, # WeaponType.SNIPER
		"starter_weapon_name": "Marksman Rifle",
		"has_pistol": false,
		"passive_name": "Extended Reconnaissance",
		"passive_desc": "+30% camera visibility zoom, 38m radar range, active dual forward shoulder searchlights, and heavy Space Truck driving certification.",
		"ability_name": "Mounted Vehicle Cannons",
		"ability_key": "[Left-Click driving]",
		"ability_cooldown": 0.0,
		"camera_size": 5.2, # +30% visibility view
		"radar_radius": 38.0, # Extended radar radius
		"can_drive_truck": true, # Authorized to drive heavy transports
		"vehicle_weapons": true, # Fires twin roof cannons while driving
	},
}

var current_class : int = CharacterClass.ASTRONAUT:
	set(val):
		if val in CLASS_CONFIGS:
			current_class = val
			class_changed.emit(current_class, CLASS_CONFIGS[current_class])

var ability_cooldown_remaining : float = 0.0

func _process(delta: float) -> void:
	if ability_cooldown_remaining > 0.0:
		ability_cooldown_remaining = maxf(ability_cooldown_remaining - delta, 0.0)
		ability_cooldown_updated.emit(ability_cooldown_remaining, get_max_cooldown(current_class))

func get_class_config(class_id: int) -> Dictionary:
	return CLASS_CONFIGS.get(class_id, CLASS_CONFIGS[CharacterClass.ASTRONAUT])

func get_current_config() -> Dictionary:
	return CLASS_CONFIGS[current_class]

func get_camera_ortho_size(class_id: int = -1) -> float:
	var target_cls : int = current_class if class_id < 0 else class_id
	var cfg : Dictionary = get_class_config(target_cls)
	return float(cfg.get("camera_size", 4.0))

func get_max_cooldown(class_id: int) -> float:
	var cfg : Dictionary = get_class_config(class_id)
	return float(cfg.get("ability_cooldown", 0.0))

func is_ability_ready() -> bool:
	return ability_cooldown_remaining <= 0.0

func trigger_ability_cooldown(cooldown_time: float = -1.0) -> void:
	if cooldown_time < 0.0:
		cooldown_time = get_max_cooldown(current_class)
	ability_cooldown_remaining = cooldown_time
	ability_used.emit(current_class, cooldown_time)

func select_class(class_id: int) -> void:
	if class_id in CLASS_CONFIGS:
		current_class = class_id
