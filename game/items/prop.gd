extends NetItem
## Small things in the lobby to pick up, look at, hand round and throw: the rack's pamphlets, the
## magazines on the coffee table, Chlora-Cola cans from the machine, coffee cups and dormitory keys.
## What it is comes from its name ("Pamphlet3_7", "Magazine2", "Soda4", "Cup1", "Fob104"), so every
## player builds the same thing.

const BRAND := "res://assets/branding/"
const FOB_COLOURS := [Color(0.75, 0.15, 0.12), Color(0.15, 0.35, 0.65), Color(0.15, 0.5, 0.3), Color(0.85, 0.55, 0.15)]


func build() -> void:
	mass = 0.2
	steady = true        # stays put in the rack, on its hook or on the table until someone takes it


func _on_xr_picked_up(p) -> void:
	steady = false       # from then on it's an ordinary thing: it tumbles when thrown
	super._on_xr_picked_up(p)


func grab_desktop(rig: Node3D) -> void:
	steady = false
	super.grab_desktop(rig)


func _ready() -> void:
	var n := String(name)
	if n.begins_with("Pamphlet"):
		_paper("pamphlet_%s.png" % n.substr(8).get_slice("_", 0), Vector2(0.1, 0.2), 0.004)
	elif n.begins_with("Magazine"):
		_paper("magazine_%s.png" % n.substr(8), Vector2(0.21, 0.279), 0.006)
	elif n.begins_with("Soda"):
		_can()
	elif n.begins_with("Cup"):
		_cup()
	elif n.begins_with("Fob"):
		_fob(int(n.substr(3)))
	super._ready()


func is_throwable() -> bool:
	return true


## A pamphlet or magazine: a thin sheet in the XY plane, its cover on the +Z side.
func _paper(file: String, size: Vector2, thick: float) -> void:
	var sheet := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(size.x, size.y, thick)
	sheet.mesh = b
	sheet.material_override = _mat(Color(0.9, 0.88, 0.82))
	add_child(sheet)
	var cover := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	cover.mesh = q
	var m := _mat(Color.WHITE)
	m.albedo_texture = load(BRAND + file)
	cover.material_override = m
	cover.position = Vector3(0, 0, thick * 0.5 + 0.0005)
	add_child(cover)
	add_shape_box(Vector3(size.x, size.y, maxf(thick, 0.01)))


## A Chlora-Cola can: the machine's side art wrapped round it, a tin top.
func _can() -> void:
	var r := 0.033
	var h := 0.122
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 20
	for i in segs:
		for k in [[i, 0.0], [i + 1, 0.0], [i + 1, 1.0], [i, 0.0], [i + 1, 1.0], [i, 1.0]]:
			var u: float = float(k[0]) / segs
			var d := Vector3(-cos(u * TAU), 0.0, sin(u * TAU))
			st.set_normal(d)
			st.set_uv(Vector2(u, 1.0 - k[1]))
			st.add_vertex(d * r + Vector3(0, h * (k[1] - 0.5), 0))
	var side := MeshInstance3D.new()
	side.mesh = st.commit()
	var m := _mat(Color.WHITE)
	m.albedo_texture = load(BRAND + "soda_side.png")
	m.roughness = 0.35
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	side.material_override = m
	add_child(side)
	var tin := _mat(Color(0.78, 0.78, 0.76))
	tin.metallic = 1.0
	tin.roughness = 0.3
	for y in [h * 0.5, -h * 0.5]:
		_disc(r, y, tin)
	add_shape_cylinder(r, h)


## A diner coffee cup with coffee in it.
func _cup() -> void:
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.03
	cm.height = 0.09
	c.mesh = cm
	c.material_override = _mat(Color(0.97, 0.96, 0.93))
	add_child(c)
	_disc(0.032, 0.0455, _mat(Color(0.18, 0.08, 0.03)))
	add_shape_cylinder(0.035, 0.09)


## A dormitory key on its plastic fob (D101..D118), the fob in the middle.
func _fob(room: int) -> void:
	var col: Color = FOB_COLOURS[posmod(room - 101, 4)]
	var fob := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.035, 0.07, 0.008)
	fob.mesh = b
	fob.material_override = _mat(col)
	add_child(fob)
	var tag := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.07)
	tag.mesh = q
	var tm := _mat(col.lightened(0.2))
	tm.albedo_texture = load(BRAND + "keyfob.png")
	tag.material_override = tm
	tag.position = Vector3(0, 0, 0.0045)
	add_child(tag)
	var key := MeshInstance3D.new()
	var kb := BoxMesh.new()
	kb.size = Vector3(0.012, 0.06, 0.004)
	key.mesh = kb
	var brass := _mat(Color(0.82, 0.62, 0.3))
	brass.metallic = 1.0
	brass.roughness = 0.3
	key.material_override = brass
	key.position = Vector3(0, 0.07, 0)
	add_child(key)
	add_shape_box(Vector3(0.04, 0.13, 0.02), Vector3(0, 0.03, 0))


func _disc(r: float, y: float, m: Material) -> void:
	var d := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.002
	cm.radial_segments = 20
	d.mesh = cm
	d.material_override = m
	d.position = Vector3(0, y, 0)
	add_child(d)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m
