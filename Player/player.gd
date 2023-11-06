extends CharacterBody3D


const SPEED = 5
const WALK_SPEED = 300
const CROUCH_SPEED = 200
const SPRINT_SPEED = 400
const SLIDE_SPEED = 500
const JUMP_VELOCITY = 6
const ground_friction = 0.8
const air_friction = pow(0.1, 8)
const dash_distance = 10

@onready var camera = $Camera3D

signal state(state)
signal speed(current_speed)
signal movement(movement)

# get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var slow_physics = 0
var jump_count = 0
var dash_count = 1
var slow_clamp = 5
var mouse_sense = 0.1
var gain_speed = 0
var gain_speed_threshold = 5

var last_dir = Vector3()
var direction = Vector3()

func is_crouched(): # check if crouching
	if(Input.is_action_pressed("crouch")):
		return true

func is_sprinting(): # check if sprinting
	if(Input.is_action_pressed("sprint")):
		return true

func is_sliding(): # check if sliding
	if(is_sprinting() and is_crouched()):
		return true

func double_jump(): # double jump logic
	if(jump_count == 1):
		return true
	else:
		return false

func dash():
	if(dash_count == 1):
		return true
	else:
		return false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	#get mouse input for camera rotation
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _process(delta):
	pass

func _physics_process(delta):
	emit_signal("speed", velocity)
	# adds gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		velocity.z -= air_friction * delta
		velocity.x -= air_friction * delta

	# handles jumping and double jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		emit_signal("movement", "jump")
		velocity.y += JUMP_VELOCITY
	if(Input.is_action_just_pressed('jump') and (is_on_floor() == false) and (double_jump() == true)):
		emit_signal("movement", "double jump")
		velocity.y += JUMP_VELOCITY
		jump_count -= 1

	# get the input direction and handle the movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back") # Input.get_vector(-x, +x, -y, +y, deadzone) #dead zone range is 0 to 1 and is a float
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# changes the direction, transform.basis is basically the default axis that things are set on, they do not change on their own, you can change them though {x, y, z}
	# comment for line 26: this line specifically gets the directions from line 22 and applies them to the character's transform, then normalizes it, aka "apply transforms" in blender

	# HANDLES ALL MOVEMENT SPEED
	if(is_sliding() and direction): # sliding processes
		if(gain_speed >= gain_speed_threshold):
			emit_signal("state", "flow sliding")
			velocity.x += direction.x * SPEED * delta
			velocity.z += direction.z * SPEED * delta
			gain_speed = gain_speed_threshold
		else:
			emit_signal("state", "sliding")
			velocity.x = direction.x * SLIDE_SPEED * delta
			velocity.z = direction.z * SLIDE_SPEED * delta
	
		if(gain_speed < 0):
			gain_speed = 0
		
		if(last_dir == direction):
			gain_speed += 1
		else:
			gain_speed -= 1
		
		if(velocity.x > 55):
			velocity.x = 55
		elif(velocity.x < -55):
			velocity.x = -55
		if(velocity.z > 55):
			velocity.z = 55
		elif(velocity.z < -55):
			velocity.z = -55
		
	elif(is_crouched() and direction): # crouching processes
		emit_signal("state", "crouching")
		velocity.x = direction.x * CROUCH_SPEED * delta
		velocity.z = direction.z * CROUCH_SPEED * delta
		
	elif(is_sprinting() and direction): # spriting processes
		if(gain_speed >= gain_speed_threshold):
			emit_signal("state", "flow sprinting")
			velocity.x += direction.x * SPEED * delta
			velocity.z += direction.z * SPEED * delta
			gain_speed = gain_speed_threshold
		else:
			emit_signal("state", "sprinting")
			velocity.x = direction.x * SPRINT_SPEED * delta
			velocity.z = direction.z * SPRINT_SPEED * delta
	
		if(gain_speed < 0):
			gain_speed = 0
		
		if(last_dir == direction):
			gain_speed += 1
		else:
			gain_speed -= 1
		
		if(velocity.x > 25):
			velocity.x = 25
		elif(velocity.x < -25):
			velocity.x = -25
		if(velocity.z > 25):
			velocity.z = 25
		elif(velocity.z < -25):
			velocity.z = -25
		
	elif(direction): # walking processes
		emit_signal("state", "walking")
		velocity.x = direction.x * WALK_SPEED * delta # multplies speed in the x direction by speed as well as the -x or +x (so -1 or +1) (multiples by delta, then adds 10 to stabilize speed)
		velocity.z = direction.z * WALK_SPEED * delta # ditto to line 26 just in the z direction (y is up/down in 3D)
		
	elif(is_on_floor()): # slow down 
		velocity.x = move_toward(velocity.x, 0, ground_friction) # move_toward() is like lerp but https://ask.godotengine.org/81798/difference-between-move_toward-and-lerp
		velocity.z = move_toward(velocity.z, 0, ground_friction) # lines 46 & 47 are smoothly turning down the speed of the player
	
	if(is_on_floor()): #refresh double jump
		jump_count = 1
	
	if(slow_physics == slow_clamp):
		if(is_on_floor() and (is_sliding() == false)): # subtract ground friction
			velocity.x += -1 * ground_friction * direction.x * delta # -1 * 0.7 * -1 or 0 or +1
			velocity.z += -1 * ground_friction * direction.z * delta # -1 * 0.7 * -1 or 0 or +1
		slow_physics = 0
	
	
	if(Input.is_action_just_pressed("ability") and (dash() == true)):
		emit_signal("movement", "dash")
		position.x += dash_distance * direction.x
		position.z += dash_distance * direction.z
	
	slow_physics += 1
	
	if(velocity == Vector3(0, 0, 0)):
		emit_signal("state", "not moving")
	
	last_dir = direction
	
	move_and_slide()
