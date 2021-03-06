extends Node2D

signal satellite_summary
signal satellite_selected
signal craft_destroyed
signal craft_collision
signal notify

const Debris = preload("res://Playfield/Satellite/debris/Debris.tscn");
const Explosion = preload("res://Playfield/Satellite/Explosion.tscn");
const SpySatellite = preload("res://Playfield/Satellite/spy_satellite/SpySatellite.tscn");
const CubeSat = preload("res://Playfield/Satellite/cube_sat/CubeSat.tscn");
const CleanupSat = preload("res://Playfield/Satellite/cleanup_sat/CleanupSat.tscn");
const ScienceStation = preload("res://Playfield/Satellite/science_station/ScienceStation.tscn");
const SpaceHotel =  preload("res://Playfield/Satellite/space_hotel/SpaceHotel.tscn");
const Ark =  preload("res://Playfield/Satellite/ark/Ark.tscn");
const Missile = preload("res://Playfield/Satellite/missile/Missile.tscn");
const LaunchVehicle = preload("res://Playfield/LaunchVehicle/LaunchVehicle.tscn");
const UsedLaunchVehicle = preload("res://Playfield/Satellite/used_launch_vehicle/UsedLaunchVehicle.tscn");


const satellites = {
    "debris": Debris,
    "cube_sat": CubeSat,
    "cleanup_sat": CleanupSat,
    "spy_satellite": SpySatellite,
    "science_station": ScienceStation,
    "space_hotel": SpaceHotel,
    "ark": Ark,
    "missile": Missile,
    "used_launch_vehicle": UsedLaunchVehicle
}

var selected_sat = null

var clicks = []
var dragging = false

var laser_charge = 0
var laser_active = false

var inactive_debris = []


func _ready():
    var orbit = get_node('Orbit')
    get_node("LaserCharge/FireButton").connect("button_down", self, "fire_button_pressed")
    get_node("LaserCharge/FireButton").connect("button_up", self, "fire_button_released")


func _unhandled_input(event):
    if event is InputEventMouseButton:
        if event.button_index == 1:
            clicks.append(event)

    if event is InputEventMouseMotion:
        var sb = get_node("SelectionBox")
        var viewport_pos = event.position
        var sb_transform = sb.get_global_transform_with_canvas()
        var local_pos = (viewport_pos - sb_transform.get_origin()) / sb_transform.get_scale()
        get_node("SelectionBox").set_drag_end(local_pos)


func show_satellite_range(id):
    var region = global.SHIP_CONFIG[id].region
    if region:
        var alt_min = global.SPACE_REGIONS[region].alt_min
        var alt_max = global.SPACE_REGIONS[region].alt_max
        var orbit_range = get_node("ShopOrbitRange")
        orbit_range.set_range(alt_min, alt_max)
        orbit_range.visible = true


func hide_satellite_range():
    get_node("ShopOrbitRange").visible = false


func new_craft(type):
    var config = global.ship_config(type)
    var craft
    if type in satellites:
        craft = satellites[type].instance()
        craft.init()
    else:
        return

    add_child(craft)
    craft.add_to_group("satellites")

    var region = config.region
    var alt = 0.3

    var theta = rand_range(0, 2 * PI)
    var x = alt * cos(theta)
    var y = alt * sin(theta)
    var leo_alt = 0.5

    var lv = LaunchVehicle.instance()
    craft.connect("satellite_entered_orbit", self, "_on_satellite_entered_orbit")
    craft.connect("clicked", self, "satellite_clicked")
    craft.launch(lv, Vector2(x, y), leo_alt, get_node('Physics').speed_for_alt(leo_alt))


func _on_satellite_entered_orbit(craft, lv):
    var ulv = UsedLaunchVehicle.instance()
    ulv.init()

    ulv.pos = craft.pos - craft.vel.normalized() * (0.09 + craft.props.debris.radius)
    ulv.set_rotation(craft.vel.angle())
    ulv.vel = craft.vel * 0.9

    self.add_child(ulv)
    ulv.add_to_group("satellites")

    craft.disconnect("satellite_entered_orbit", self, "_on_satellite_entered_orbit")


func new_missile():
    var missile = satellites["missile"].instance()
    missile.init()

    add_child(missile)
    missile.connect("explode", self, "missile_explode", [missile])
    missile.add_to_group("satellites")

    var alt = 0.3

    var theta = rand_range(0, 2 * PI)
    var x = alt * cos(theta)
    var y = alt * sin(theta)

    missile.launch(Vector2(x, y))


func missile_explode(object, missile):
    if object:
        craft_collision(object, missile)
    else:
        explode(missile.position, missile.props.explosion.scale)
        destroy_craft(missile)


func destroy_craft(craft):
    if selected_sat == craft:
        select_satellite(null)

    emit_signal("craft_destroyed", craft)
    call_deferred("remove_child", craft)
    craft.set_collision_layer_bit(1, false)
    craft.set_collision_layer_bit(0, false)
    craft.remove_from_group("satellites")


func explode(position, scale=1):
    var p = position
    var splode = Explosion.instance()
    add_child(splode)
    splode.scale = splode.scale * scale
    splode.position = p
    splode.connect("animation_finished", self, "remove_child", [splode])
    splode.show()
    splode.play()


func no_debris_collision(craft, name):
    if not craft.invunerable:
        explode(craft.position, craft.props.explosion.scale)
        destroy_craft(craft)

        var craft_name = global.id_display_lookup[craft.type]
        report_collision(craft_name, name)


func moon_collision(craft):
    if craft == get_node("Earth"):
        get_tree().change_scene("res://GameOver.tscn")
        return

    if not craft.invunerable:
        explode(craft.position, craft.props.explosion.scale)
        destroy_craft(craft)

        var name1 = global.id_display_lookup[craft.type]
        var name2 = "Moon"
        report_collision(name1, name2)


func create_debris(pos, vel, amount, radius, impluse):
    var craft
    var angle
    var x
    var y
    var d_radius
    var d_impluse
    var craft_pos
    var craft_vel

    for i in range(amount):
        angle = i * (2 * PI) / amount
        x = cos(angle)
        y = sin(angle)

        d_radius = radius * 0.2 + randf() * radius * 0.9
        d_impluse = impluse * 0.1 + randf() * impluse  * 0.9

        craft_pos = pos + Vector2(d_radius*x, d_radius*y)
        craft_vel = vel + Vector2(d_impluse*x, d_impluse*y)
        craft = Debris.instance()
        craft.init()
        add_child(craft)

        craft.vel = craft_vel
        craft.pos = craft_pos
        craft.active = false

        inactive_debris.append(craft)


func craft_collision(craft1, craft2):
    if craft1.type == "debris" and craft2.type == "debris":
        return

    if not craft1.active or not craft2.active:
        return

    if craft1.type != "debris":
        create_debris(craft1.pos, craft1.vel,
                     craft1.props.debris.amount, craft1.props.debris.radius, craft1.props.debris.impluse)
        explode(craft1.position, craft1.props.explosion.scale)
        destroy_craft(craft1)

    if craft2.type != "debris":
        create_debris(craft2.pos, craft2.vel,
                      craft2.props.debris.amount, craft2.props.debris.radius, craft2.props.debris.impluse)
        explode(craft2.position, craft2.props.explosion.scale)
        destroy_craft(craft2)

    var name1 = global.id_display_lookup[craft1.type]
    var name2 = global.id_display_lookup[craft2.type]
    report_collision(name1, name2)
    emit_signal("craft_collision", craft1, craft2)


func report_collision(name1, name2):
    var message = "%s was destroyed colliding with %s!"
    var namearr = [name1, name2]

    if name1 == "Debris":
        name1 = name2
        name2 = "Debris"

    # If this is only a debris/celestial body object, ignore
    if name2 == "Debris" and ["Earth", "Moon", "Laser"].has(name1):
        return

    emit_signal("notify", message % [name1, name2], global.NOTIFICATION_TYPE.BAD)


func get_satellites(type=null):
    if type == null:
        return get_tree().get_nodes_in_group("satellites")

    var matches = []
    for s in get_tree().get_nodes_in_group("satellites"):
        if s.type == type:
            matches.append(s)
    return matches


func state():
    var st = []
    var debris_count = 0
    for sat in get_satellites():
        if sat.active and sat.type != "debris":
            st.append(sat)
        elif sat.active and sat.type == 'debris':
            debris_count += 1
    var m = get_node('Moon')
    return [st, debris_count, [m.distance, m.start_distance]]


func select_satellite(sat):
    if selected_sat:
        selected_sat.deselect()
    selected_sat = sat

    var good_orbit_range = get_node('GoodOrbitRange')
    var orbit = get_node('Orbit')
    var box = get_node('Selected')

    if sat:
        sat.select()
        var alt_range = sat.alt_range
        if alt_range:
            good_orbit_range.set_range(alt_range[0], alt_range[1])
            good_orbit_range.visible = true
        orbit.visible = true
        box.visible = true
    else:
        good_orbit_range.visible = false
        orbit.visible = false
        box.visible = false

    emit_signal("satellite_selected", sat)


func satellite_clicked(sat, event):
    # Eat this click
    if event in clicks:
        clicks.remove(clicks.find(event))

    dragging = false

    select_satellite(sat)


func fire_button_pressed():
    get_node("Earth").fire_laser()
    laser_active = true


func fire_button_released():
    get_node("Earth").stop_laser()
    laser_active = false


func start_dragging(event):
    dragging = true
    var sb = get_node("SelectionBox")
    var viewport_pos = event.position
    var sb_transform = sb.get_global_transform_with_canvas()
    var local_pos = (viewport_pos - sb_transform.get_origin()) / sb_transform.get_scale()
    sb.set_drag_start(local_pos)
    sb.set_drag_end(local_pos)
    sb.visible = true


func finish_dragging(event):
    if not dragging:
        return

    var sb = get_node("SelectionBox")
    sb.visible = false

    var sats = sb.get_satellites_contained()
    var center = sb.get_center()
    var nearest = null
    var nearest_dist = 99999999999999
    for sat in sats:
        var dist = center.distance_to(sat.position)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = sat
    select_satellite(nearest)


func charge_laser():
    laser_charge = global.LASER_CONFIG.laser_charge["time_earned"]
    get_node("LaserCharge").visible = true
    get_node("Earth").show_laser_cannon()


func _process(delta):
    emit_signal("satellite_summary", delta, state())

    for click in clicks:
        # This click was not eaten by a satellite
        if click.pressed:
            select_satellite(null)
            start_dragging(click)
        else:
            finish_dragging(click)
    clicks.clear()

    if selected_sat:
        var burn_fine = Input.is_action_pressed("burn_fine")
        if Input.is_action_pressed("burn_prograde"):
            selected_sat.burn(delta, true, burn_fine)
        elif Input.is_action_pressed("burn_retrograde"):
            selected_sat.burn(delta, false, burn_fine)

        var predicted_orbit = get_node('Physics').predict_orbit(selected_sat)
        var orbit = get_node('Orbit')
        orbit.points = PoolVector2Array(predicted_orbit)
        orbit.width = 2 * global.current_scale()
        
        get_node("Selected").place(selected_sat.position)

    for d in inactive_debris:
        var colliding_bodies = d.get_node("PlacementArea").get_overlapping_bodies()
        d.get_node("PlacementArea").monitorable = false
        d.get_node("PlacementArea").monitoring = false
        if colliding_bodies:
            destroy_craft(d)
        else:
            d.add_to_group("satellites")
            d.active = true

    if inactive_debris:
        inactive_debris = []

    if laser_active:
        laser_charge -= delta
        if laser_charge <= 0:
            laser_active = false
            get_node("Earth").stop_laser()
            get_node("LaserCharge").visible = false

    if laser_charge > 0:
        get_node("LaserCharge").value = laser_charge / global.LASER_CONFIG.laser_charge.time_earned


func _on_missile_pending():
    pass
    
func _on_missile_launched():
    new_missile()


func handle_game_over():
    get_tree().change_scene('res://GameOver.tscn')
