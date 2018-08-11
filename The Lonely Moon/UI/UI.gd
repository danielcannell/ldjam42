extends Container

signal spawn_satellite

export (PackedScene) var shop_item

var shop_items = []


func _ready():
    get_node("Economy").connect("update_balance", self, "set_money")

    # Create buttons from config
    for x in global.MENU_CONFIG:
        var btn = shop_item.instance()
        btn.connect("clicked", self, "btn_clicked", [btn])
        btn.connect("finished", self, "btn_finished", [btn])
        btn.set_thing(x)
        shop_items.append(btn)
        get_node("Shop/Shop/Background/Container/Tiles").add_child(btn)

    set_money(0)


func create_notification(text):
    get_node("Notifications").add_notification(text)


func btn_clicked(btn):
    var thing = btn.thing
    var cost = thing.cost
    get_node("Economy").spend_money(cost)
    create_notification("Spent " + str(cost) + " btc")


func btn_finished(btn):
    var thing = btn.thing
    var type = thing.type
    var id = thing.id

    if type == "satellite":
        make_satellite(id, thing.display_name)
    elif type == "fundraise":
        make_fundraise(id)
    elif type == "ark":
        get_tree().change_scene("res://Victory.tscn")


func make_satellite(id, name):
    emit_signal("spawn_satellite", id)
    create_notification(name + " launched!")


func make_fundraise(id):
    get_node("Economy").make_fundraise(id)


func set_money(amt):
    get_node("Shop/Money/Background/Labels/Amount").text = str(floor(amt))

    # Disable buttons based on cost
    for item in shop_items:
        item.set_enabled(item.thing.cost <= amt)


func _on_Playfield_satellite_summary(delta, state):
    get_node("Economy").receive_state(delta, state)
