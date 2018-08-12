extends Node


const GRAVITY = 0.1


func vel_for_pos(pos):
    var speed = sqrt(GRAVITY * get_node('../Earth').MASS / pos.length())
    return speed * Vector2(pos.y, -pos.x).normalized()


func calculate_accel(pos, massive_bodies):
    var a = Vector2(0, 0)

    for b in massive_bodies:
        var offset = b.pos - pos
        var distance = offset.length()
        a += b.MASS * offset / pow(distance, 3)

    return GRAVITY * a


func integrate_orbit(delta, pos, vel, massive_bodies):
    pos += vel * delta / 2
    vel += calculate_accel(pos, massive_bodies) * delta
    pos += vel * delta / 2
    return [pos, vel]


func predict_orbit(sat):
    var pos = sat.pos
    var vel = sat.vel

    var prev_theta = pos.angle()
    var theta = 0

    var massive_bodies = [get_node('../Earth')]

    var path = [global.metres_to_screen(pos)]

    for i in range(200):
        var delta = min(0.2 / vel.length(), pos.length() / 4)
        var result = integrate_orbit(delta, pos, vel, massive_bodies)
        pos = result[0]
        vel = result[1]

        var new_theta = pos.angle()
        var delta_theta = abs(new_theta - prev_theta)

        if delta_theta > PI:
            delta_theta = abs(delta_theta - 2*PI)

        theta += delta_theta
        prev_theta = new_theta

        if theta > 2*PI or pos.length() < 0.2:
            break

        path.append(global.metres_to_screen(pos))

    return path


func _ready():
    pass


func _physics_process(delta):
    var massive_bodies = [get_node('../Moon'), get_node('../Earth')]
    var satellites = get_node('..').get_satellites()

    for s in satellites:
        var result = integrate_orbit(delta, s.pos, s.vel, massive_bodies)
        s.pos = result[0]
        s.vel = result[1]
        var collision_info = s.move_and_collide_metres(result[0] - s.pos)
        if collision_info:
            print(collision_info.collider.type + " Collision")
            if collision_info.collider.type == "earth":
                get_node("..").destroy_craft(s)
            else:
                print("Satellite Collision!")
