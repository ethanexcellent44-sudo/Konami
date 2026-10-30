extends RigidBody2D
class_name FootballBall2D

signal kicked(direction: Vector2, impulse: float)

@export_range(0.05, 1.0, 0.01) var kick_impulse: float = 0.48
@export_range(0.0, 1.0, 0.01) var charge_power: float = 0.0
@export_range(0.0, 200.0, 1.0) var kick_impulse_scale: float = 90.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false

func kick(direction: Vector2, power: float = 1.0) -> void:
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction.is_zero_approx():
		return
	var clamped_power: float = clampf(power, 0.0, 1.0)
	var impulse_strength: float = kick_impulse_scale * kick_impulse * clamped_power
	apply_central_impulse(normalized_direction * impulse_strength)
	kicked.emit(normalized_direction, impulse_strength)

func stop_ball() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
