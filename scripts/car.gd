extends CharacterBody3D
class_name DriftCar

# Arcade RWD drift model, units are metres and seconds.
@export var acceleration := 23.0
@export var reverse_acceleration := 11.0
@export var drag := 0.22
@export var rolling_resistance := 1.6
@export var max_speed := 43.0
@export var steering_strength := 1.9
@export var grip := 7.5
@export var handbrake_grip := 0.8
# Rear-wheel drive: throttle breaks rear traction while steering.
@export var power_oversteer_start_kmh := 16.0
@export var power_oversteer_full_kmh := 55.0
@export var throttle_grip_loss := 0.76
@export var throttle_yaw_kick := 1.2
@export var yaw_inertia := 5.0
@export var yaw_damping := 3.2

var touch_throttle := false
var touch_brake := false
var touch_left := false
var touch_right := false
var touch_handbrake := false
var forward_speed := 0.0
var lateral_speed := 0.0
var drift_angle := 0.0
var speed_kmh := 0.0
var drifting := false
var last_position := Vector3.ZERO
var yaw_velocity := 0.0
var wheelspin := 0.0

func _ready() -> void:
	_build_body()
	last_position = global_position

func _physics_process(delta: float) -> void:
	var gas := maxf(Input.get_action_strength("throttle"), float(touch_throttle))
	var brake := maxf(Input.get_action_strength("brake"), float(touch_brake))
	var steer := clampf(Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left") + float(touch_right) - float(touch_left), -1.0, 1.0)
	var hb := Input.is_action_pressed("handbrake") or touch_handbrake
	if Input.is_action_just_pressed("reset_car"):
		reset_to_start()

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward_speed = velocity.dot(forward)
	lateral_speed = velocity.dot(right)

	# Engine pushes along the chassis forward vector, preserving existing momentum.
	var engine_force := gas * acceleration - brake * (reverse_acceleration if forward_speed < 1.0 else 34.0)
	velocity += forward * engine_force * delta
	velocity -= forward * forward_speed * (rolling_resistance + absf(forward_speed) * drag) * delta * 0.12

	# Power oversteer: steering + throttle unloads the rear tires. At low speed
	# the car still has grip; at moderate speed full throttle starts a slide.
	var speed_kmh_local := absf(forward_speed) * 3.6
	var speed_window := smoothstep(power_oversteer_start_kmh, power_oversteer_full_kmh, speed_kmh_local)
	var power_slide := gas * absf(steer) * speed_window
	wheelspin = move_toward(wheelspin, power_slide, delta * (4.0 if power_slide > wheelspin else 1.8))
	var rear_grip := grip * (1.0 - throttle_grip_loss * wheelspin)
	if hb:
		rear_grip = minf(rear_grip, handbrake_grip)
	# Lower rear grip means lateral velocity survives, creating a real drift angle.
	velocity -= right * lateral_speed * minf(1.0, rear_grip * delta)

	var speed_factor := clampf(absf(forward_speed) / 9.0, 0.0, 1.0)
	var direction := 1.0 if forward_speed >= 0.0 else -1.0
	var target_yaw := steer * steering_strength * speed_factor * direction
	# Engine torque makes the rear step out in the same direction as steering.
	var power_kick := steer * throttle_yaw_kick * wheelspin
	if hb:
		power_kick += steer * 0.55 * speed_factor
	# Yaw has inertia. Countersteer reduces rotation rather than snapping the car.
	var desired_yaw := target_yaw + power_kick
	var response := yaw_inertia if absf(desired_yaw) > absf(yaw_velocity) else yaw_damping
	yaw_velocity = move_toward(yaw_velocity, desired_yaw, response * delta)
	if absf(steer) < 0.05 and not hb:
		yaw_velocity = move_toward(yaw_velocity, 0.0, yaw_damping * delta * (0.45 if wheelspin > 0.1 else 1.0))
	rotate_y(-yaw_velocity * delta)
	velocity.y -= 24.0 * delta
	velocity = velocity.limit_length(max_speed)
	move_and_slide()

	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	speed_kmh = flat_velocity.length() * 3.6
	if flat_velocity.length() > 2.5:
		drift_angle = rad_to_deg(atan2(flat_velocity.dot(global_transform.basis.x), flat_velocity.dot(-global_transform.basis.z)))
	else:
		drift_angle = 0.0
	drifting = speed_kmh > 24.0 and absf(drift_angle) > 12.0 and absf(drift_angle) < 85.0

func reset_to_start() -> void:
	global_position = Vector3(0, 0.75, 0)
	global_rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	yaw_velocity = 0.0
	wheelspin = 0.0

func _build_body() -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.75, 4.0)
	collider.shape = box
	add_child(collider)
	_add_box(Vector3(1.9, 0.55, 4.0), Vector3(0, 0.12, 0), Color("e65c47"))
	_add_box(Vector3(1.55, 0.55, 1.9), Vector3(0, 0.65, -0.2), Color("283d55"))
	_add_box(Vector3(1.62, 0.08, 0.18), Vector3(0, 0.45, -1.88), Color("f5d784"))
	_add_box(Vector3(1.62, 0.10, 0.18), Vector3(0, 0.36, 1.9), Color("a41b24"))
	for side in [-1.0, 1.0]:
		for z in [-1.2, 1.2]:
			_add_box(Vector3(0.38, 0.65, 0.75), Vector3(side * 1.02, -0.18, z), Color("111722"))

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mesh.mesh = m
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mesh.material_override = mat
	add_child(mesh)
