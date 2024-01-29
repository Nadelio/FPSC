extends CharacterBody3D

# constants
const SPEED = 5
const WALK_SPEED = 300
const CROUCH_SPEED = 200
const SPRINT_SPEED = 400
const SLIDE_SPEED = 500
const WALL_RUN_SPEED = 500
const JUMP_VELOCITY = 6
const ground_friction = 0.8
const air_friction = pow(0.1, 8)

# @onreadys
@onready var camera = $Camera3D
@onready var AbilityCD = $AbilityCD
@onready var DashCheck = $DashCollideCheck
@onready var WallCheck1 = $WallCheck1
@onready var WallCheck2 = $WallCheck2
@onready var WallCheck = $WallCheck1 # temporary assignment, will be changed by code

# signals
signal state(state)
signal speed(current_speed)
signal movement(movement)

# get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# misc varables
var current_speed = 0
var slow_physics = 0
var jump_count = 0
var dash_count = 1
var slow_clamp = 5
var mouse_sense = 0.1
var gain_speed = 0
var gain_speed_threshold = 5
var dashDistance = 10
var origin
var collision_point
var wall_angle = 0

# direction vectors
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

func update_wall_angle():
	if(WallCheck1.is_colliding()):
		WallCheck = WallCheck1 # change WallCheck to WallCheck1
	elif(WallCheck2.is_colliding()):
		WallCheck = WallCheck2 # change WallCheck to WallCheck2
	
	if(WallCheck.is_colliding()):
		# update hypotenuse length
		origin = DashCheck.global_transform.origin
		collision_point = DashCheck.get_collision_point()
		var hypotenuse = origin.distance_to(collision_point)
		
		# update adjacent length
		origin = DashCheck.global_transform.origin
		collision_point = WallCheck.get_collision_point()
		var adjacent = origin.distance_to(collision_point)
		
		# update wall_angle
		wall_angle = rad_to_deg(cos(adjacent/hypotenuse))
		return wall_angle

func double_jump(): # double jump logic
	if(jump_count == 1):
		return true
	else:
		return false

func wall_jump(direct, delta): # wall jump processes
	if(Input.is_action_just_pressed("jump") and is_on_wall()):
		emit_signal("movement", "wall jump")
		velocity.x = direct.x * WALK_SPEED * delta
		velocity.z = direct.z * WALK_SPEED * delta
		velocity.y += 2 * JUMP_VELOCITY

func dash(): # dash logic
	if(dash_count == 1):
		return true
	else:
		return false

func flow_state(speed_clamp, flow, norm, direct, norm_speed, delta): # flow_state function
	if(gain_speed >= gain_speed_threshold): # change to flow state
		emit_signal("state", flow)
		velocity.x += direct.x * SPEED * delta
		velocity.z += direct.z * SPEED * delta
		gain_speed = gain_speed_threshold
	else: # change to normal state
		emit_signal("state", norm)
		velocity.x = direct.x * norm_speed * delta
		velocity.z = direct.z * norm_speed * delta

	# speed limit code
	if(velocity.x > speed_clamp):
		velocity.x = speed_clamp
	elif(velocity.x < -speed_clamp):
		velocity.x = -speed_clamp
	if(velocity.z > speed_clamp):
		velocity.z = speed_clamp
	elif(velocity.z < -speed_clamp):
		velocity.z = -speed_clamp

func update_horizontal_direction(direction : Vector3, new_direction : Vector3):
	direction.x = new_direction.x
	direction.z = new_direction.z

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # capture mouse
	DashCheck.exclude_parent = true
	DashCheck.collide_with_areas = true
	DashCheck.collide_with_bodies = true

func _input(event):
	#get mouse input for camera rotation
	if event is InputEventMouseMotion: # credit to Garbaj
		rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _process(_delta): # currently unused
	pass

func _physics_process(delta):
	update_wall_angle()
	var wall_normal = get_wall_normal() # update wall_normal
	
	current_speed = sqrt(pow(velocity.x, 2) + pow(velocity.z, 2)) # update current speed
	emit_signal("speed", current_speed) # update CurrentSpeed label
	
	# adds gravity
	if not is_on_floor(): # in air check
		velocity.y -= gravity * delta
		velocity.z -= air_friction * delta
		velocity.x -= air_friction * delta
	
	# handles jumping and double jumping
	if Input.is_action_just_pressed("jump") and is_on_floor(): #jump logic
		emit_signal("movement", "jump")
		velocity.y += JUMP_VELOCITY
	
	if(Input.is_action_just_pressed('jump') and (is_on_floor() == false) and (double_jump() == true)): # double jump logic
		emit_signal("movement", "double jump")
		if(velocity.y < 0):
			velocity.y = velocity.y * 0 + JUMP_VELOCITY + JUMP_VELOCITY
		else:
			velocity.y += JUMP_VELOCITY
		jump_count -= 1
	
	# get the input direction and handle the movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back") # Input.get_vector(-x, +x, -y, +y, deadzone) #dead zone range is 0 to 1 and is a float
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# changes the direction, transform.basis is basically the default axis that things are set on, they do not change on their own, you can change them though {x, y, z}
	# comment for line 26: this line specifically gets the directions from line 22 and applies them to the character's transform, then normalizes it, aka "apply transforms" in blender

	# handles all basic movement types
	if(is_sliding()): # sliding processes
		flow_state(55, "flow sliding", "sliding", direction, SLIDE_SPEED, delta)
		
	elif(is_crouched()): # crouching processes
		emit_signal("state", "crouching")
		velocity.x = direction.x * CROUCH_SPEED * delta
		velocity.z = direction.z * CROUCH_SPEED * delta
		
	elif(is_sprinting()): # spriting processes
		flow_state(25, "flow sprinting", "sprinting", direction, SPRINT_SPEED, delta)
		
	elif(direction): # walking processes
		emit_signal("state", "walking")
		velocity.x = direction.x * WALK_SPEED * delta # multplies speed in the x direction by speed as well as the -x or +x (so -1 or +1) (multiples by delta, then adds 10 to stabilize speed)
		velocity.z = direction.z * WALK_SPEED * delta # ditto to line 26 just in the z direction (y is up/down in 3D)
		
	elif(is_on_floor()): # slow down 
		velocity.x = move_toward(velocity.x, 0, ground_friction) # move_toward() is like lerp but https://ask.godotengine.org/81798/difference-between-move_toward-and-lerp
		velocity.z = move_toward(velocity.z, 0, ground_friction) # lines 46 & 47 are smoothly turning down the speed of the player
	
	if(is_on_floor() or is_on_wall()): #refresh double jump
		jump_count = 1
	
	if(slow_physics == slow_clamp): # slow physics processes
		if(is_on_floor() and (is_sliding() == false)): # subtract ground friction
			velocity.x += -1 * ground_friction * direction.x * delta # -1 * 0.7 * -1 or 0 or +1
			velocity.z += -1 * ground_friction * direction.z * delta # -1 * 0.7 * -1 or 0 or +1
		slow_physics = 0
	
	if(Input.is_action_just_pressed("ability") and (dash() == true) and direction): # dashing and future movement logic will be here
		if(DashCheck.is_colliding()): # update dashdistance
			origin = DashCheck.global_transform.origin
			collision_point = DashCheck.get_collision_point()
			dashDistance = origin.distance_to(collision_point)
		
		position.x += dashDistance * direction.x # move dash distance
		position.z += dashDistance * direction.z # move dash distance
		emit_signal("movement", "dash")
		dash_count -= 1 # remove the ability to dash
		AbilityCD.start() # start CD
	
	if(is_on_wall_only() and wall_angle > 30 and wall_angle < 65): # wall running processes (small bug that creates stuttered movement when looking around on a wall)
		velocity.y = 0 # stop downward and upward movement
		
		flow_state(55, "flow wall running", "wall running", wall_normal, WALL_RUN_SPEED, delta) # do wall running
		
		wall_jump(wall_normal, delta) # check for wall jump
	elif(wall_angle < 30 and wall_angle > 65 and Input.is_action_pressed("move_forward")): # wall climbing process // BROKEN
		
		emit_signal("state", "wall climbing")
		
		velocity.x = 0 # stop horizontal movement
		velocity.z = 0 # stop horizontal movement
		velocity.y = SPEED # vertical movement
		
		if(!DashCheck.is_colliding()):
			position.y += 1
		
		wall_jump(wall_normal, delta) # check for wall jump
	
	if(is_on_wall_only() and !direction): # wall hanging processes
		emit_signal("state", "wall hanging")
		
		velocity = Vector3.ZERO # velocity = (0,0,0)
		
		wall_jump(wall_normal, delta) # check for wall jump
	
	slow_physics += 1 # update slow physics
	
	if(velocity == Vector3.ZERO and !is_on_wall_only()): # not moving check
		emit_signal("state", "not moving")
	
	if(gain_speed < 0): # clamp gain speed to always be >= 0
		gain_speed = 0
	
	if(last_dir == direction): # flow state check
		gain_speed += 1
	else:
		gain_speed -= 1
	
	last_dir = direction # update last_dir
	
	move_and_slide()

func _on_ability_cd_timeout():
	dash_count = 1
