# AI Development Guidelines

Guidelines for AI agents working in this repository (`wake_up` / Godot 4.x).

---

## 1. Prime Directives

1. **Always Deliver Polish**: Every feature must feel intentional and finished. Include smooth transitions/tweens, visual and audio feedback, clear UI states, and responsive controls. Do not leave placeholder shortcuts or unhandled edge cases.
2. **Carefully Plan Before Executing**: For non-trivial tasks (refactors, new subsystems, multi-scene modifications), break the work down into a clear, phased plan before writing code. Align on architectural decisions first.

---

## 2. Godot & GDScript Standards

- **Static Typing**: Use explicit type annotations for all variables, function arguments, and return types (`var speed: float = 5.0`, `func take_damage(amount: int) -> void:`).
- **Component-Driven Architecture**: Prefer small, reusable components (like `HealthComponent`) attached as child nodes over massive monolithic scripts.
- **Signals & Decoupling**: Use signals for child-to-parent or decoupled communication (`signal health_depleted`). Use dependency injection or groups (`is_in_group("player")`) rather than fragile hardcoded paths.
- **Node Caching**: Use `@onready` with explicit types for node dependencies (`@onready var animation: Node = $Animation`). Check for null when dependencies may be optional.
- **Scene & Resource Safety**:
  - Keep scenes modular and testable in isolation.
  - Preserve Godot `.uid` files and do not manually tamper with internal UID hashes unless editing metadata.
  - Configure inputs and singletons via `project.godot` rather than ad-hoc global state.

---

## 3. Workflow & Verification

1. **Inspect First**: Read relevant scenes (`.tscn`) and scripts (`.gd`) before making edits.
2. **Atomic Changes**: Keep changes focused and clean. Avoid unrelated formatting churn.
3. **Validate**: Verify scene tree integrity, collision layers/masks, and script references. When automated tests exist (e.g., `tests/`), run them to prevent regressions.
