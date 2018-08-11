extends Node


const GRAVITY = 1


func calculate_accel(s, massive_bodies):
    var a = Vector2(0, 0)
    
    for b in massive_bodies:
        var offset = b.pos - s.pos
        var distance = offset.length()
        a += offset / pow(distance, 3)    
    
    return GRAVITY * a


func _ready():
    pass


func _physics_process(delta):
    var massive_bodies = [get_node('../Moon'), get_node('../Earth')]
    var satellites = get_node('..').get_satellites()
    
    for s in satellites:
        var a = calculate_accel(s, massive_bodies)
        s.vel += a * delta
        var collision_info = s.move_and_collide(global.metres_to_screen(s.vel * delta))
        if collision_info:
            print("Collision!")
            get_node("..").destroy_craft(s)
        