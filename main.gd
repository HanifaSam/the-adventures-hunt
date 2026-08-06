extends Node2D

var player1: CharacterBody2D
var camera: Camera2D
var start_pos_p1 := Vector2(150, 300)

var lives: int = 3
var score: int = 0
var time_remaining: float = 1200.0 
var is_game_over: bool = false
var current_world: int = 1
var chaos_mult: float = 1.0 

var level_coins: int = 0
var coins_needed: int = 5
var boss_defeated: bool = false

var current_outfit: int = 0
var outfits = [
	{
		"pants": "#2c3e50", "boots": "#7f8c8d", "shirt": "#f1c40f",
		"grip": "#8b4513", "blade": "#a9a9a9", "scarf": "#3498db", "scarf_dark": "#2980b9",
		"hat_base": "#e74c3c", "hat_top": "#c0392b"
	},
	{
		"pants": "#111111", "boots": "#000000", "shirt": "#222222",
		"grip": "#330000", "blade": "#e74c3c", "scarf": "#8e44ad", "scarf_dark": "#5b2c6f",
		"hat_base": "#111111", "hat_top": "#000000"
	},
	{
		"pants": "#ecf0f1", "boots": "#bdc3c7", "shirt": "#f1c40f",
		"grip": "#d35400", "blade": "#f39c12", "scarf": "#ffffff", "scarf_dark": "#bdc3c7",
		"hat_base": "#f39c12", "hat_top": "#e67e22"
	}
]

const SPEED = 380.0
const JUMP_VELOCITY = -680.0
var gravity = 1200.0

var jumps_left: int = 2
var jump_button_released: bool = true

var attack_cooldown: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0

var platforms = []
var enemies = []
var coins = []
var spikes = []
var particles = []
var hazards = []
var side_bosses = []
var snow = []
var thorn_walls = []
var wave_visuals = []
var teleporters = []
var parrots = []
var lava_drips = []
var wind_particles = []

var is_teleporting: bool = false
var active_boss: CharacterBody2D
var disaster_timer: float = 0.0
var lava_y_level: float = 1500.0
var lava_surge: float = 0.0
var wave_anim_time: float = 0.0

var bg_layer: Node2D
var ui_layer: CanvasLayer
var time_label: Label
var lives_label: Label
var score_label: Label
var coins_label: Label
var wardrobe_label: Label
var msg_label: Label
var world_label: Label
var notif_label: Label
var slide_frame: ColorRect
var quote_label: Label
var boss_hp_bg: ColorRect
var boss_hp_fill: ColorRect
var boss_name_label: Label 
var blackout_rect: ColorRect
var bg_modulate: CanvasModulate
var lava_rect: ColorRect
var waves_container: Node2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#3498db"))
	get_tree().root.set_default_canvas_item_texture_filter(Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	_setup_enviroment()
	_setup_level_for_world(1)
	_setup_player()
	_setup_ui()

func _rect(p: Node, s: Vector2, pos: Vector2, c: Color) -> ColorRect:
	var r = ColorRect.new()
	r.size = s; r.position = pos; r.color = c
	p.add_child(r)
	return r

func _poly(p: Node, pts: PackedVector2Array, c: Color) -> Polygon2D:
	var r = Polygon2D.new()
	r.polygon = pts; r.color = c
	p.add_child(r)
	return r

func _physics_process(delta: float) -> void:
	if is_game_over: return
	_handle_teleporters(delta)
	if not is_teleporting: 
		_handle_attack(delta)
		_handle_player1(delta)
	_handle_enemies(delta); _handle_coins(); _handle_spikes(); _handle_hazards(delta)
	_handle_bosses(delta); _handle_lava(delta); _handle_thorns()
	_handle_particles(delta); _handle_wind_and_snow(delta); _animate_scarf()
	_handle_parrots(delta); _handle_lava_drips(delta)
	if player1.position.y > lava_y_level or player1.position.y > 1600:
		if not is_teleporting: _lose_life()
	_handle_timers(delta); _update_ui()
	if is_instance_valid(camera): camera.position = camera.position.lerp(player1.position, 0.1)

func _unhandled_input(e: InputEvent) -> void:
	if is_game_over and e is InputEventKey and e.pressed and e.keycode == KEY_R:
		get_tree().reload_current_scene()
	if not is_game_over and e is InputEventKey and e.pressed and e.keycode == KEY_C:
		current_outfit = (current_outfit + 1) % 3
		_apply_outfit()
		_play_sfx("coin")

func _play_sfx(type: String) -> void:
	var p = AudioStreamPlayer.new()
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS; s.mix_rate = 22050
	var d = PackedByteArray(); var f = 439.0; var n = 2205
	match type:
		"jump": n = 2500; f = 300.0
		"slash": n = 2200; f = 600.0
		"coin": n = 2000; f = 880.0
		"hit": n = 4000; f = 100.0
		"disaster": n = 5000; f = 80.0
	for i in range(n):
		var t = float(i) / 22050.0; var cf = f
		if type == "jump": cf += t * 2000.0
		elif type == "slash": cf = max(100.0, f - t * 1500.0)
		elif type == "coin" and i > 1000: cf *= 1.3
		elif type == "disaster": cf += sin(t * 50.0) * 40.0
		d.append(clamp(int((sin(t * cf * TAU) + 1.0) * 127.5), 0, 255))
	s.data = d; p.stream = s; add_child(p); p.play(); p.finished.connect(p.queue_free)

func _setup_player() -> void:
	player1 = CharacterBody2D.new()
	player1.position = start_pos_p1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(26, 50)
	shape.shape = rect
	player1.add_child(shape)
	
	var spr = Node2D.new()
	spr.name = "Sprite"
	player1.add_child(spr)
	
	var scarf_tail = _poly(spr, PackedVector2Array([Vector2(-10,-12), Vector2(-22,0), Vector2(-17,5), Vector2(-5,-8)]), Color.WHITE)
	scarf_tail.name = "Scarf_Tail"
	
	_rect(spr, Vector2(22, 12), Vector2(-11, 4), Color.WHITE).name = "Pants"
	_rect(spr, Vector2(26, 8), Vector2(-13, 16), Color.WHITE).name = "Boots"
	_rect(spr, Vector2(24, 16), Vector2(-12, -12), Color.WHITE).name = "Shirt"
	_rect(spr, Vector2(4, 10), Vector2(0, -10), Color.WHITE).name = "SwordGrip"
	_poly(spr, PackedVector2Array([Vector2(-2,-40), Vector2(6,-30), Vector2(6,-10), Vector2(-2,-10), Vector2(-2,-30)]), Color.WHITE).name = "Blade" 
	_rect(spr, Vector2(18, 12), Vector2(-9, -24), Color("#ffdabc")).name = "Face" 
	_rect(spr, Vector2(4, 4), Vector2(3, -21), Color("#2c3e50")).name = "Eye" 
	_rect(spr, Vector2(26, 6), Vector2(-13, -14), Color.WHITE).name = "ScarfWrap"
	_rect(spr, Vector2(22, 8), Vector2(-11, -32), Color.WHITE).name = "HatBase"
	_rect(spr, Vector2(14, 6), Vector2(-7, -38), Color.WHITE).name = "HatTop"
	
	var slsh = _poly(spr, PackedVector2Array([Vector2(15,-30), Vector2(45,-20), Vector2(55,0), Vector2(45,20), Vector2(15,30), Vector2(30,0)]), Color(0,1,1,0.8))
	slsh.name = "SlashEffect"; slsh.visible = false
	
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.limit_bottom = 1200
	add_child(camera)
	add_child(player1)
	_apply_outfit() 

func _apply_outfit() -> void:
	if not is_instance_valid(player1): return
	var spr = player1.get_node("Sprite")
	var o = outfits[current_outfit]
	spr.get_node("Pants").color = Color(o["pants"])
	spr.get_node("Boots").color = Color(o["boots"])
	spr.get_node("Shirt").color = Color(o["shirt"])
	spr.get_node("SwordGrip").color = Color(o["grip"])
	spr.get_node("Blade").color = Color(o["blade"])
	spr.get_node("ScarfWrap").color = Color(o["scarf"])
	spr.get_node("Scarf_Tail").color = Color(o["scarf_dark"])
	spr.get_node("HatBase").color = Color(o["hat_base"])
	spr.get_node("HatTop").color = Color(o["hat_top"])

func _handle_player1(delta: float) -> void:
	if not player1.is_on_floor(): player1.velocity.y += gravity * delta
	else: jumps_left = 2
		
	var jmp = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	if jmp and jump_button_released and jumps_left > 0:
		player1.velocity.y = JUMP_VELOCITY
		jumps_left -= 1; jump_button_released = false
		_play_sfx("jump"); _spawn_parts(player1.position + Vector2(0,20), Color.WHITE)
	elif not jmp: jump_button_released = true

	var dir = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir += 1.0
	
	if dir != 0.0:
		player1.velocity.x = move_toward(player1.velocity.x, dir * SPEED, SPEED * 8.0 * delta)
		player1.get_node("Sprite").scale.x = dir
	else:
		player1.velocity.x = move_toward(player1.velocity.x, 0, SPEED * 10.0 * delta)
		
	if current_world == 2: player1.velocity.x -= 400.0 * delta 
	player1.move_and_slide()

func _animate_scarf() -> void:
	if not is_instance_valid(player1): return
	var scarf = player1.get_node_or_null("Sprite/Scarf_Tail")
	if scarf:
		var spd = abs(player1.velocity.x) / SPEED
		var p_step = floor(sin(Time.get_ticks_msec() * 0.015) * 3.0)
		if not player1.is_on_floor(): scarf.rotation_degrees = -25.0 + (p_step * 3.0)
		elif spd > 0.1: scarf.rotation_degrees = -15.0 - (spd * 20.0) + p_step
		else: scarf.rotation_degrees = p_step * 2.0

func _handle_attack(d: float) -> void:
	if attack_cooldown > 0: attack_cooldown -= d
	if is_attacking:
		attack_timer -= d
		if attack_timer <= 0: is_attacking = false; player1.get_node("Sprite/SlashEffect").visible = false
	if (Input.is_key_pressed(KEY_P) or Input.is_key_pressed(KEY_F)) and attack_cooldown <= 0 and not is_attacking:
		is_attacking = true; attack_timer = 0.2; attack_cooldown = 0.35
		_play_sfx("slash"); player1.get_node("Sprite/SlashEffect").visible = true
		var a_pos = player1.position + Vector2(player1.get_node("Sprite").scale.x * 35, 0)
		_spawn_parts(a_pos, Color(outfits[current_outfit]["blade"]))
		thorn_walls = _hit_list(thorn_walls, a_pos, 90.0, true, Color("#0e4c28"))
		enemies = _hit_list(enemies, a_pos, 75.0, false, Color.WHITE)
		for b in side_bosses:
			if is_instance_valid(b):
				var hit_distance = 160.0 if b == active_boss else 100.0
				if a_pos.distance_to(b.position) < hit_distance:
					var hp = b.get_meta("hp") - 1
					b.set_meta("hp", hp); _play_sfx("hit"); _spawn_parts(b.position, Color.RED)
					if hp <= 0: 
						score += 3000; b.queue_free()
						if current_world == 4: _victory_finish()
						else: boss_defeated = true 

func _hit_list(arr: Array, pos: Vector2, rad: float, is_thorn: bool, col: Color) -> Array:
	var rem = []
	for x in arr:
		if is_instance_valid(x):
			if pos.distance_to(x.position) < rad:
				_spawn_parts(x.position, col if is_thorn else x.get_node("Visual").color)
				x.queue_free()
				if is_thorn: _spawn_boss(3400, 420, 3)
				else: score += 250
			else: rem.append(x)
	return rem

func _setup_enviroment() -> void:
	bg_modulate = CanvasModulate.new(); add_child(bg_modulate)
	bg_layer = Node2D.new(); add_child(bg_layer) 
	lava_rect = _rect(self, Vector2(4000, 800), Vector2(-500, 1500), Color(0.9, 0.2, 0.1, 0.8))
	waves_container = Node2D.new(); waves_container.visible = false; add_child(waves_container)
	for i in range(8): wave_visuals.append(_poly(waves_container, PackedVector2Array([Vector2(-60,0), Vector2(0,-30), Vector2(60,0), Vector2(40,40), Vector2(-40,40)]), Color("#2980b9")))

func _build_backgrounds(w: int) -> void:
	for c in bg_layer.get_children(): c.queue_free() 
	if w == 1: 
		for i in range(6):
			var px = i * 400 - 200; var col = Color("#2ecc71").darkened(0.2 if i%2==0 else 0.3); var b_size = 35.0
			for row in range(12):
				var w_blocks = 4 + (row * 2)
				_rect(bg_layer, Vector2(w_blocks * b_size, b_size), Vector2(px - (w_blocks * b_size / 2.0), 350 + (i%2)*50 + (row * b_size)), col)
	elif w == 2: 
		for i in range(5):
			var px = i * 500; var b_size = 25.0
			for row in range(24):
				var w_blocks = 1 + (row * 2); var row_width = w_blocks * b_size; var start_x = px - (row_width / 2.0); var start_y = 100 + (row * b_size)
				if row < 5: _rect(bg_layer, Vector2(row_width, b_size), Vector2(start_x, start_y), Color.WHITE)
				elif row == 5 or row == 6:
					for b in range(w_blocks):
						_rect(bg_layer, Vector2(b_size, b_size), Vector2(start_x + (b * b_size), start_y), Color.WHITE if randf() > 0.4 else Color("#7fb3d5"))
				else: _rect(bg_layer, Vector2(row_width, b_size), Vector2(start_x, start_y), Color("#7fb3d5"))
	elif w == 4:
		RenderingServer.set_default_clear_color(Color("#e67e22")) 
		for i in range(6):
			var px = i * 500 - 300
			_poly(bg_layer, PackedVector2Array([Vector2(px, 700), Vector2(px+300, 200 + (i%2)*80), Vector2(px+600, 700)]), Color("#1a242f"))
			_poly(bg_layer, PackedVector2Array([Vector2(px+100, 700), Vector2(px+300, 100), Vector2(px+500, 700)]), Color("#1c2833"))
			_poly(bg_layer, PackedVector2Array([Vector2(px+250, 700), Vector2(px+300, 500), Vector2(px+350, 700)]), Color("#e74c3c"))

func _setup_level_for_world(w: int) -> void:
	for a in [platforms, enemies, coins, spikes, thorn_walls, teleporters, parrots, lava_drips, wind_particles, side_bosses, hazards, particles, snow]: 
		for x in a: 
			if is_instance_valid(x): 
				if x is Dictionary: x["n"].queue_free() 
				else: x.queue_free()
		a.clear()
	
	active_boss = null; boss_defeated = false; level_coins = 0; coins_needed = 3 + (w * 2)
	_build_backgrounds(w)
	_create_plat(400, 600, 1000, 80, w); _create_plat(1600, 500, 800, 80, w)
	_create_plat(2600, 550, 800, 80, w); _create_plat(3600, 500, 1000, 80, w)
	if w < 4: _create_plat(4200, 500, 400, 80, w); _create_tp(4200, 460)
	
	var e_space = max(100, 500 - (w * 100))
	var s_space = max(120, 350 - (w * 70))
	var p_space = 250 
	
	for x in range(600, 3200, p_space):
		_create_plat(x, randf_range(320, 440), 150, 30, w)
		_create_coin(x, randf_range(200, 280))
		if x % e_space < p_space: _create_minion(x, 280, w)
		if x % s_space < p_space: _create_spike(x, 560)
			
	if w == 3:
		var t = StaticBody2D.new(); t.position = Vector2(3000, 450)
		var s = CollisionShape2D.new(); var r = RectangleShape2D.new(); r.size = Vector2(60, 120)
		s.shape = r; t.add_child(s)
		_poly(t, PackedVector2Array([Vector2(-30,-60), Vector2(0,-80), Vector2(30,-60), Vector2(20,60), Vector2(-20,60)]), Color("#0c4725"))
		add_child(t); thorn_walls.append(t)
	elif w < 4: _spawn_boss(3400, 420, w)
	else: _spawn_boss(camera.position.x + 700, -200, w)

func _create_plat(x: float, y: float, w: float, h: float, z: int) -> void:
	var b = StaticBody2D.new(); b.position = Vector2(x,y)
	var s = CollisionShape2D.new(); var r = RectangleShape2D.new(); r.size = Vector2(w,h)
	s.shape = r; b.add_child(s)
	var v = _rect(b, Vector2(w,h), Vector2(-w/2, -h/2), Color("#2ecc71")); v.name = "BaseVisual"
	var gh = Node2D.new(); gh.name = "GrassHolder"; b.add_child(gh)
	for gx in range(int(-w/2), int(w/2), 12): _rect(gh, Vector2(6,8), Vector2(gx, -h/2 - 6), Color("#27ae60"))
	add_child(b); platforms.append(b)

func _create_spike(x: float, y: float) -> void:
	var s = Area2D.new(); s.position = Vector2(x,y)
	_poly(s, PackedVector2Array([Vector2(-15,15), Vector2(0,-15), Vector2(15,15)]), Color("#bdc3c7"))
	add_child(s); spikes.append(s)

func _create_coin(x: float, y: float) -> void:
	var c = Area2D.new(); c.position = Vector2(x,y)
	var pts = PackedVector2Array()
	for i in range(8): pts.append(Vector2(cos(i*(TAU/8))*12, sin(i*(TAU/8))*16))
	_poly(c, pts, Color("#f1c40f")); add_child(c); coins.append(c)

func _create_minion(x: float, y: float, z: int) -> void:
	var e = CharacterBody2D.new(); e.position = Vector2(x,y)
	var s = CollisionShape2D.new(); var r = RectangleShape2D.new(); r.size = Vector2(32,32)
	s.shape = r; e.add_child(s)
	var color_arr = [Color("#2ecc71"), Color("#aed6f1"), Color("#47450b"), Color("#e74c3c")]
	var v = _poly(e, PackedVector2Array([Vector2(-16,-16), Vector2(16,-16), Vector2(16,16), Vector2(-16,16)]), color_arr[z-1]); v.name = "Visual"
	_rect(v, Vector2(6,6), Vector2(-6,-6), Color.YELLOW); e.set_meta("dir", -1)
	add_child(e); enemies.append(e)

func _spawn_boss(x: float, y: float, w: int) -> void:
	var b = CharacterBody2D.new(); b.position = Vector2(x,y)
	var s = CollisionShape2D.new(); var r = RectangleShape2D.new(); r.size = Vector2(100,100)
	s.shape = r; b.add_child(s)
	var v = Node2D.new(); v.name = "Visual"; b.add_child(v); var hp = 5
	
	if w == 1: 
		hp = 6
		_rect(v, Vector2(40,60), Vector2(-20,-10), Color("#5c3a21"))
		_poly(v, PackedVector2Array([Vector2(-60,0), Vector2(0,-70), Vector2(60,0), Vector2(30,30), Vector2(-30,30)]), Color("#2ecc71"))
		_rect(v, Vector2(10,10), Vector2(-20,-10), Color.RED); _rect(v, Vector2(10,10), Vector2(10,-10), Color.RED)
		for f in [-50, 50]: _poly(v, PackedVector2Array([Vector2(f,-10), Vector2(f+20,10), Vector2(f,30), Vector2(f-20,10)]), Color("#5c3a21"))
	elif w == 2: 
		hp = 8
		_poly(v, PackedVector2Array([Vector2(-30,-40), Vector2(30,-40), Vector2(40,20), Vector2(0,50), Vector2(-40,20)]), Color("#85c1e9"))
		_poly(v, PackedVector2Array([Vector2(-15,-60), Vector2(15,-60), Vector2(25,-30), Vector2(-25,-30)]), Color("#d6eaf8"))
		_rect(v, Vector2(10,10), Vector2(-12,-45), Color("#1b4f72")); _rect(v, Vector2(10,10), Vector2(2,-45), Color("#1b4f72"))
		for f in [-50, 50]: _poly(v, PackedVector2Array([Vector2(f,-10), Vector2(f+15,15), Vector2(f-15,15)]), Color("#aed6f1"))
	elif w == 3: 
		hp = 10
		_poly(v, PackedVector2Array([Vector2(-20,20), Vector2(20,20), Vector2(30,60), Vector2(-30,60)]), Color("#1e8449"))
		_poly(v, PackedVector2Array([Vector2(-50,-30), Vector2(0,-60), Vector2(50,-30), Vector2(30,20), Vector2(-30,20)]), Color("#8e44ad"))
		_poly(v, PackedVector2Array([Vector2(-40,-20), Vector2(40,-20), Vector2(20,10), Vector2(-20,10)]), Color.BLACK)
		for tx in range(-30, 30, 15): _poly(v, PackedVector2Array([Vector2(tx,-20), Vector2(tx+10,-20), Vector2(tx+5,-5)]), Color.WHITE)
		_rect(v, Vector2(8,8), Vector2(-15,-40), Color.YELLOW); _rect(v, Vector2(8,8), Vector2(7,-40), Color.YELLOW)
	elif w == 4: 
		hp = 15
		_poly(v, PackedVector2Array([Vector2(-100,80), Vector2(100,80), Vector2(60,-60), Vector2(-60,-60)]), Color("#1c2833"))
		_poly(v, PackedVector2Array([Vector2(-60,-60), Vector2(60,-60), Vector2(30,-80), Vector2(-30,-80)]), Color("#c0392b"))
		_rect(v, Vector2(15, 80), Vector2(-30, -60), Color("#e74c3c")); _rect(v, Vector2(10, 50), Vector2(20, -60), Color("#f39c12"))
		_rect(v, Vector2(15,15), Vector2(-40,-20), Color("#f1c40f")); _rect(v, Vector2(15,15), Vector2(25,-20), Color("#f1c40f"))
		_poly(v, PackedVector2Array([Vector2(-20,-80), Vector2(20,-80), Vector2(50,-130), Vector2(-50,-130)]), Color(0.5, 0.5, 0.5, 0.7))
		
	b.set_meta("hp", hp); b.set_meta("max_hp", hp); active_boss = b 
	add_child(b); side_bosses.append(b)

func _handle_bosses(d: float) -> void:
	var r = []
	for b in side_bosses:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			var dir_normal = (player1.position - b.position).normalized()
			b.position += dir_normal * (30.0 + (chaos_mult * 20.0)) * d
			var v = b.get_node_or_null("Visual")
			if v: v.position.y = sin(Time.get_ticks_msec() * 0.005) * 5.0
			
			if b == active_boss:
				if player1.is_on_floor() and player1.position.distance_to(b.position) < 800.0:
					disaster_timer += d
					var atk_spd = max(0.4, 1.2 - (chaos_mult * 0.3))
					if disaster_timer >= atk_spd: 
						disaster_timer = 0.0
						_boss_attack()
				elif player1.position.distance_to(b.position) >= 800.0:
					disaster_timer = 0.0 
			
			if current_world != 4 and player1.position.distance_to(b.position) < 50.0: 
				_lose_life()
			r.append(b)
	side_bosses = r

func _boss_attack() -> void:
	if not is_instance_valid(active_boss) or not is_instance_valid(player1): return
	_play_sfx("disaster")
	var type = randi() % 2
	if current_world == 4: type = randi() % 3
	var pos = active_boss.position; var dir = (player1.position - pos).normalized()
	
	if current_world == 1:
		if type == 0:
			for i in [-1, 0, 1]: _fire_hz(pos, [Vector2(-8,-4),Vector2(8,-4),Vector2(8,4),Vector2(-8,4)], Color("#6e2c00"), dir.rotated(i * 0.2) * 320)
		else: _fire_hz(Vector2(player1.position.x, camera.position.y - 400), [Vector2(-10,-20),Vector2(10,-20),Vector2(10,20),Vector2(-10,20)], Color("#5c3a21"), Vector2(0, 300)) 
	elif current_world == 2:
		if type == 0: 
			for i in [-1, 0, 1]: _fire_hz(pos, [Vector2(-5,0),Vector2(0,-10),Vector2(5,0),Vector2(0,10)], Color.CYAN, dir.rotated(i * 0.3) * 250) 
		else: _fire_hz(Vector2(player1.position.x + randf_range(-100,100), camera.position.y - 400), [Vector2(-8,-20),Vector2(8,-20),Vector2(0,20)], Color.WHITE, Vector2(0, 400)) 
	elif current_world == 3:
		if type == 0: _fire_hz(pos, [Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)], Color("#8e44ad"), dir * 280) 
		else: _fire_hz(pos, [Vector2(-6,-6),Vector2(6,-6),Vector2(6,6),Vector2(-6,6)], Color("#d35400"), Vector2(dir.x * 200, -400), true) 
	elif current_world == 4:
		if type == 0: 
			for i in range(5): 
				var m_pos = Vector2(player1.position.x + randf_range(-400, 400), camera.position.y - 450)
				_fire_hz(m_pos, [Vector2(-15,-15),Vector2(15,-15),Vector2(15,15),Vector2(-15,15)], Color("#d35400"), (player1.position - m_pos).normalized() * randf_range(150, 250))
		elif type == 1: 
			for i in [-2, -1, 0, 1, 2]: _fire_hz(pos + Vector2(0,-50), [Vector2(-10,10),Vector2(0,-15),Vector2(10,10)], Color("#e74c3c"), dir.rotated(i * 0.25) * 400)
		else: _fire_hz(pos + Vector2(0,-50), [Vector2(-12,-12),Vector2(12,-12),Vector2(12,12),Vector2(-12,12)], Color("#f1c40f"), dir * 650) 

func _fire_hz(pos: Vector2, pts: Array, col: Color, vel: Vector2, grav: bool = false):
	var h = _poly(self, PackedVector2Array(pts), col)
	h.position = pos; hazards.append({"node": h, "vel": vel, "grav": grav})

func _handle_hazards(d: float) -> void:
	var r = []
	for h in hazards:
		if is_instance_valid(h["node"]):
			if h.get("grav"): h["vel"].y += gravity * d
			h["node"].position += h["vel"] * d; _spawn_parts(h["node"].position, h["node"].color)
			if player1.position.distance_to(h["node"].position) < 35.0: _lose_life(); h["node"].queue_free()
			elif h["node"].position.y > 1500 or abs(h["node"].position.x - camera.position.x) > 1500: h["node"].queue_free() 
			else: r.append(h)
	hazards = r

func _handle_timers(d: float) -> void:
	time_remaining -= d
	if time_remaining <= 0: _game_over("Time Up!")

func _transition_world(new_w: int) -> void:
	if new_w == 4: 
		blackout_rect.visible = true; var tw = get_tree().create_tween()
		tw.tween_property(blackout_rect, "color:a", 1.0, 1.0); await tw.finished
		
	current_world = new_w; _setup_level_for_world(new_w)
	player1.position = start_pos_p1; player1.velocity = Vector2.ZERO
	chaos_mult = (new_w - 1.0); lava_rect.visible = (new_w == 4); waves_container.visible = (new_w == 4)	
	
	var pc_arr = ["#2ecc71", "#ecf0f1", "#6e2c00", "#c0392b"]
	var gc_arr = ["#27ae60", "#ffffff", "#1e8449", "#1e8449"]
	var bg_arr = [Color("#3498db"), Color("#d6eaf8"), Color("#abebc6"), Color("#e67e22")]
	bg_modulate.color = bg_arr[new_w-1]
	world_label.text = "WORLD: " + ["GRASSLANDS", "PIXEL FROST PEAKS", "THORN JUNGLE", "VOLCANO STORM"][new_w-1]
	
	for p in platforms:
		if is_instance_valid(p):
			p.get_node("BaseVisual").color = Color(pc_arr[new_w-1])
			for blade in p.get_node("GrassHolder").get_children(): blade.color = Color(gc_arr[new_w-1])

	if new_w == 4:
		var tw = get_tree().create_tween()
		tw.tween_property(blackout_rect, "color:a", 0.0, 1.0)
		await tw.finished; blackout_rect.visible = false

func _handle_lava(d: float) -> void:
	if current_world != 4:
		lava_rect.visible = false; lava_y_level = 1600.0; return
	for i in range(wave_visuals.size()):
		if is_instance_valid(wave_visuals[i]):
			wave_visuals[i].position = Vector2((camera.position.x - 400) + (i*120) + cos(wave_anim_time*0.8), 580 + sin(wave_anim_time+i)*25.0)
	wave_anim_time += d * 3.0; lava_surge += d * 1.5; lava_rect.visible = true
	lava_y_level = 850.0 - (sin(lava_surge) * 120.0); lava_rect.position.y = lava_y_level

func _handle_parrots(d: float) -> void:
	if current_world != 3: return
	if parrots.size() < 4 and randf() < 0.01:
		var p = _poly(self, PackedVector2Array([Vector2(0,-5), Vector2(10,0), Vector2(0,5), Vector2(-10,0)]), [Color.RED, Color.BLUE, Color.GREEN][randi()%3])
		p.position = camera.position + Vector2(randf_range(-600, 600), randf_range(-300, 0))
		parrots.append({"n": p, "dir": 1 if randf() > 0.5 else -1, "time": 0.0})
	
	var r = []
	for p in parrots:
		if is_instance_valid(p["n"]):
			p["time"] += d * 15.0; p["n"].position.x += p["dir"] * 150.0 * d; p["n"].scale.y = sin(p["time"]) 
			if p["n"].position.distance_to(camera.position) > 1000: p["n"].queue_free()
			else: r.append(p)
	parrots = r

func _handle_lava_drips(d: float) -> void:
	if current_world != 4: return
	if randf() < 0.1: 
		var drip = _rect(self, Vector2(6,6), camera.position + Vector2(randf_range(-600, 600), -350), Color("#e67e22"))
		lava_drips.append({"n": drip, "v": 0.0})
		
	var r = []
	for l in lava_drips:
		if is_instance_valid(l["n"]):
			l["v"] += gravity * d; l["n"].position.y += l["v"] * d
			if l["n"].position.y > 1000: l["n"].queue_free()
			else: r.append(l)
	lava_drips = r

func _handle_wind_and_snow(d: float) -> void:
	if current_world != 2: return
	if wind_particles.size() < 12 and randf() < 0.1:
		var wp = _rect(self, Vector2(randf_range(60, 150), 2), camera.position + Vector2(500, randf_range(-400, 200)), Color(1,1,1,0.6))
		wind_particles.append({"n": wp, "v": randf_range(600, 1000)})
		
	var rem_w = []
	for w in wind_particles:
		if is_instance_valid(w["n"]):
			w["n"].position.x -= w["v"] * d
			if w["n"].position.x < camera.position.x - 500: w["n"].queue_free()
			else: rem_w.append(w)
	wind_particles = rem_w

	if snow.size() < 25:
		var p = _poly(self, PackedVector2Array([Vector2(-3,-3), Vector2(3,-3), Vector2(3,3), Vector2(-3,3)]), Color.WHITE)
		p.position = camera.position + Vector2(randf_range(-600, 600), -350)
		snow.append({"n": p, "s": randf_range(100, 200)})
		
	var r = []
	for s in snow:
		if is_instance_valid(s["n"]):
			s["n"].position.y += s["s"] * d; s["n"].position.x += sin(Time.get_ticks_msec() * 0.003) * 0.5
			if s["n"].position.y < camera.position.y + 400: r.append(s) 
			else: s["n"].queue_free()
	snow = r

func _handle_enemies(d: float) -> void:
	var r = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			var dir = e.get_meta("dir")
			e.velocity.y += gravity * d; e.velocity.x = dir * (80.0 + (chaos_mult * 30.0))
			e.move_and_slide()
			if e.is_on_wall(): e.set_meta("dir", dir * -1)
			if player1.position.distance_to(e.position) < 32.0: _lose_life()
			r.append(e)
	enemies = r

func _handle_coins() -> void:
	var r = []
	for c in coins:
		if is_instance_valid(c):
			c.scale.x = sin(Time.get_ticks_msec() * 0.005)
			if player1.position.distance_to(c.position) < 30.0: 
				score += 100; level_coins += 1; _play_sfx("coin")
				_spawn_parts(c.position, Color("#f1c40f")); c.queue_free()
			else: r.append(c)
	coins = r

func _handle_spikes() -> void:
	for s in spikes:
		if is_instance_valid(s) and player1.position.distance_to(s.position) < 40.0: _lose_life()

func _lose_life() -> void:
	_play_sfx("hit"); lives -= 1; jumps_left = 2; jump_button_released = true
	if lives <= 0: _game_over("Game Over!")
	else:
		player1.position = start_pos_p1; player1.velocity = Vector2.ZERO
		lava_surge = 0.0; disaster_timer = 0.0
		_setup_level_for_world(current_world) 

func _handle_thorns() -> void:
	var near = false
	for t in thorn_walls:
		if is_instance_valid(t) and player1.position.distance_to(t.position) < 200.0: near = true; break
	if near: notif_label.visible = true; notif_label.text = "Cut Thorns! (F/P)"
	elif notif_label.text.begins_with("Cut"): notif_label.visible = false

func _spawn_parts(pos: Vector2, c: Color) -> void:
	for i in range(12):
		var p = _poly(self, PackedVector2Array([Vector2(-3,-3), Vector2(3,-3), Vector2(3,3), Vector2(-3,3)]), c)
		p.position = pos; var a = randf() * TAU
		particles.append({"n": p, "v": Vector2(cos(a), sin(a)) * randf_range(120, 350), "l": 1.0})

func _handle_particles(d: float) -> void:
	var r = []
	for p in particles:
		if is_instance_valid(p["n"]):
			p["n"].position += p["v"] * d; p["v"].y += gravity * d; p["l"] -= d * 2.5; p["n"].modulate.a = p["l"]
			if p["l"] > 0: r.append(p) 
			else: p["n"].queue_free()
	particles = r

func _create_tp(x: float, y: float) -> void:
	var tp = Area2D.new(); tp.position = Vector2(x, y)
	var s = CollisionShape2D.new(); var r = RectangleShape2D.new(); r.size = Vector2(60,80)
	s.shape = r; tp.add_child(s)
	_rect(tp, Vector2(60,80), Vector2(-30,-40), Color("#7f8c8d"))
	var c = _rect(tp, Vector2(40,60), Vector2(-20,-30), Color("#9b59b6")); c.name = "Core"
	add_child(tp); teleporters.append(tp)

func _handle_teleporters(_d: float) -> void:
	if is_teleporting: return
	var at_door = false
	for tp in teleporters:
		if is_instance_valid(tp) and player1.position.distance_to(tp.position) < 40.0:
			at_door = true
			if boss_defeated and level_coins >= coins_needed:
				is_teleporting = true; player1.visible = false; player1.velocity = Vector2.ZERO; _play_sfx("coin") 
				var tw = get_tree().create_tween()
				tw.tween_property(tp.get_node("Core"), "color", Color.WHITE, 0.2)
				tw.tween_property(tp.get_node("Core"), "color", Color("#9b59b6"), 0.2); tw.set_loops(10)
				get_tree().create_tween().tween_property(tp, "modulate:a", 0.0, 4.0)
				await get_tree().create_timer(4.0).timeout
				is_teleporting = false; player1.visible = true
				if current_world < 4: _transition_world(current_world + 1)
				return
			else: notif_label.visible = true; notif_label.text = "LOCKED: Defeat Boss & Collect " + str(coins_needed) + " Coins!"
	if not at_door and notif_label.text.begins_with("LOCKED"): notif_label.visible = false

func _make_lbl(txt: String, pos: Vector2, sz: int, col: Color = Color.WHITE) -> Label:
	var l = Label.new(); l.text = txt; l.position = pos; var f = LabelSettings.new()
	f.font_size = sz; f.outline_size = 4; f.outline_color = Color("#1c2833") 
	f.shadow_size = 2; f.shadow_color = Color(0,0,0,0.5); f.font_color = col
	l.label_settings = f
	return l

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new(); add_child(ui_layer)
	time_label = _make_lbl("TIME: 00:00", Vector2(20, 20), 22); ui_layer.add_child(time_label)
	lives_label = _make_lbl("LIVES: 3", Vector2(20, 50), 22); ui_layer.add_child(lives_label)
	score_label = _make_lbl("SCORE: 0", Vector2(20, 80), 22); ui_layer.add_child(score_label)
	coins_label = _make_lbl("COINS: 0/5", Vector2(20, 110), 22, Color("#f1c40f")); ui_layer.add_child(coins_label) 
	wardrobe_label = _make_lbl("PRESS 'C' TO CHANGE OUTFIT", Vector2(20, 140), 18, Color("#bdc3c7")); ui_layer.add_child(wardrobe_label)
	world_label = _make_lbl("WORLD: GRASSLANDS", Vector2(400, 20), 24); ui_layer.add_child(world_label)
	
	boss_hp_bg = _rect(ui_layer, Vector2(400, 16), Vector2(400, 60), Color("#34495e")) 
	boss_hp_fill = _rect(boss_hp_bg, Vector2(392, 8), Vector2(4, 4), Color("#e74c3c"))
	boss_name_label = _make_lbl("BOSS", Vector2(0, -24), 20, Color("#e74c3c")); boss_hp_bg.add_child(boss_name_label); boss_hp_bg.visible = false
	
	notif_label = _make_lbl("", Vector2(280, 180), 26, Color("#f1c40f")); notif_label.visible = false; ui_layer.add_child(notif_label)
	msg_label = _make_lbl("", Vector2(200, 250), 36); ui_layer.add_child(msg_label)
	
	slide_frame = _rect(ui_layer, Vector2(1000, 500), Vector2(140, 100), Color(0,0,0,0.9)); slide_frame.visible = false
	quote_label = _make_lbl("", Vector2(50, 150), 24, Color("#f1c40f")); quote_label.size = Vector2(900, 200); quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD; slide_frame.add_child(quote_label)
	
	blackout_rect = _rect(ui_layer, Vector2(5000, 5000), Vector2(-1000, -1000), Color.BLACK)
	blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; blackout_rect.color.a = 0.0; blackout_rect.visible = false

func _update_ui() -> void:
	time_label.text = "TIME: %02d:%02d" % [int(time_remaining)/60, int(time_remaining)%60]
	lives_label.text = "LIVES: " + str(lives); score_label.text = "SCORE: " + str(score)
	coins_label.text = "COINS: %d / %d" % [level_coins, coins_needed]
	
	if is_instance_valid(active_boss):
		boss_hp_bg.visible = true
		var hp_ratio = float(active_boss.get_meta("hp")) / float(active_boss.get_meta("max_hp"))
		boss_hp_fill.size.x = hp_ratio * 392.0
		boss_name_label.text = ["TREE BOSS", "ICE GOLEM", "JUNGLE HORROR", "MEGA VOLCANO"][current_world - 1]
	else: boss_hp_bg.visible = false

func _game_over(msg: String) -> void:
	is_game_over = true; msg_label.text = msg + "\nPress 'R' to Restart"

func _victory_finish() -> void:
	is_game_over = true; msg_label.text = "CONGRATULATIONS!\nYOU FINISHED THE GAME!"
	await get_tree().create_timer(2.0).timeout; msg_label.visible = false; slide_frame.visible = true
	quote_label.text = "\"It was a calm beginning, but you never know when the storm is going to hit you.\"\n\n- Press 'R' to Play Again"
