extends Node3D

var car: DriftCar
var camera: Camera3D
var speed_label: Label
var drift_label: Label
var score_label: Label
var help_label: Label
var drift_score := 0.0
var combo := 1.0
var combo_bank := 0.0
var camera_position := Vector3(0, 6, 12)

func _ready() -> void:
	_build_world()
	car = DriftCar.new()
	car.position = Vector3(0, 0.75, 0)
	add_child(car)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72
	add_child(camera)
	_build_ui()

func _process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	var backward := car.global_transform.basis.z
	var desired := car.global_position + backward * 10.5 + Vector3.UP * 5.2
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 4.0))
	camera.look_at(car.global_position + Vector3.UP * 1.2 + (-backward * 3.0), Vector3.UP)
	speed_label.text = "%03d км/ч" % int(car.speed_kmh)
	if car.drifting:
		combo = minf(combo + delta * 0.15, 5.0)
		combo_bank += delta * (car.speed_kmh * 0.5 + absf(car.drift_angle) * 2.0) * combo
		drift_label.text = "ДРИФТ  %d°   ×%.1f" % [int(absf(car.drift_angle)), combo]
		drift_label.modulate = Color("65f2d0")
	else:
		if combo_bank > 0:
			drift_score += combo_bank
			combo_bank = 0.0
		combo = 1.0
		drift_label.text = "РУЧНИК: ПРОБЕЛ"
		drift_label.modulate = Color("b7c6d8")
	score_label.text = "ОЧКИ: %d" % int(drift_score + combo_bank)

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("87b2c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9cad5")
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.5
	add_child(sun)
	_add_static_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0), Color("343e4c"))
	# Painted drift rings and lane lines.
	for r in [16.0, 30.0, 48.0]:
		for i in range(96):
			var angle := TAU * float(i) / 96.0
			var strip := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(0.20, 0.015, 1.15)
			strip.mesh = cube
			strip.position = Vector3(sin(angle) * r, 0.018, cos(angle) * r)
			strip.rotation.y = angle
			var paint := StandardMaterial3D.new()
			paint.albedo_color = Color("d5b85f") if r == 30.0 else Color("8999a8")
			strip.material_override = paint
			add_child(strip)
	for x in [-80.0, 80.0]:
		for z in range(-80, 81, 16):
			_add_static_box(Vector3(3, 3, 9), Vector3(x, 1.5, z), Color("c46c4e"))
	for z in [-80.0, 80.0]:
		for x in range(-64, 65, 16):
			_add_static_box(Vector3(9, 3, 3), Vector3(x, 1.5, z), Color("c46c4e"))
	for x in [-45.0, 45.0]:
		for z in [-45.0, 45.0]:
			_add_static_box(Vector3(4, 2, 4), Vector3(x, 1, z), Color("e6a75d"))

func _add_static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var title := _label(root, "DRIFT DISTRICT  ·  PROTOTYPE 0.2", Vector2(24, 18), 24)
	title.modulate = Color("65f2d0")
	speed_label = _label(root, "000 км/ч", Vector2(24, 57), 30)
	drift_label = _label(root, "РУЧНИК: ПРОБЕЛ", Vector2(24, 101), 20)
	score_label = _label(root, "ОЧКИ: 0", Vector2(24, 135), 22)
	help_label = _label(root, "WASD / стрелки — ехать   •   ПРОБЕЛ — ручник   •   R — вернуть машину", Vector2(24, 173), 15)
	var controls := Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(controls)
	_add_touch_button(controls, "◀", Vector2(25, -105), Vector2(78, 72), "left")
	_add_touch_button(controls, "▶", Vector2(110, -105), Vector2(78, 72), "right")
	_add_touch_button(controls, "ГАЗ", Vector2(-195, -105), Vector2(78, 72), "throttle")
	_add_touch_button(controls, "ТОРМ", Vector2(-110, -105), Vector2(78, 72), "brake")
	_add_touch_button(controls, "РУЧНИК", Vector2(-195, -190), Vector2(163, 66), "handbrake")
	var reset := Button.new()
	reset.text = "↻ СБРОС"
	reset.position = Vector2(-128, 18)
	reset.size = Vector2(108, 42)
	reset.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	reset.pressed.connect(func(): car.reset_to_start())
	root.add_child(reset)

func _label(parent: Node, value: String, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color("111c2b"))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l

func _add_touch_button(parent: Control, value: String, offset: Vector2, size: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = value
	button.size = size
	button.position = offset
	button.anchor_left = 1.0 if offset.x < 0 else 0.0
	button.anchor_right = button.anchor_left
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.add_theme_font_size_override("font_size", 20)
	button.button_down.connect(func(): _set_touch(action, true))
	button.button_up.connect(func(): _set_touch(action, false))
	parent.add_child(button)

func _set_touch(action: String, pressed: bool) -> void:
	match action:
		"left": car.touch_left = pressed
		"right": car.touch_right = pressed
		"throttle": car.touch_throttle = pressed
		"brake": car.touch_brake = pressed
		"handbrake": car.touch_handbrake = pressed
