extends RigidBody3D

const SPEED = 5.0
var y = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position.y = sin(y) + 1.5
	position.x = cos(y)
	y += 1 * delta
