extends Node

var balance = 0

signal update_balance;

func _ready():
    # Called when the node is added to the scene for the first time.
    # Initialization here
    pass
    
static func constellation_bonus(sat, size):
    return (1 + sat.props.constellation_bonus * (size - 1))

static func ship_income(ship, satellites):
    var props = ship.props
    var state = ship.state()
    
    if props.income == 0:
        return 0

    var constell_size = global.constellation_size(satellites, ship.type)
    var base_income = props.income * constellation_bonus(ship, constell_size)

    if state.uptime < props.time_constant:
        return base_income

    return lerp(base_income, 0.25 * base_income, (state.uptime - props.time_constant) / (4 * props.time_constant))


func receive_state(delta, state):
    var income = 0
    for ship in state:
        if ship.in_range():
            income += delta * ship_income(ship, state)
    balance += income

    emit_signal("update_balance", balance)


func make_fundraise(id):
    var f = global.FUNDRAISE_CONFIG[id]
    var displayname = global.id_display_lookup[id]

    var amt = rand_range(f.raised_min, f.raised_max)
    balance += amt
    emit_signal("update_balance", balance)
    get_node("..").create_notification("\"" + displayname + "\" complete! Earned " + str(floor(amt)) + " btc!", global.NOTIFICATION_TYPE.INFO)


func spend_money(amount):
    balance -= amount
