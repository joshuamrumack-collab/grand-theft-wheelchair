## Static batching for the browser / Potato build.
## WebGL pays a lot for every separate mesh it draws, and the city is thousands of small pieces
## (walls, windows, curbs, lamps, benches...). This merges every static MeshInstance3D under a node
## into one mesh per material per chunk, so the whole city becomes a few hundred draws instead of ~4000.
## Moving or breakable things (physics bodies, areas, birds, particles) are left alone.
extends RefCounted

const CHUNK := 64.0

## skip: Dictionary of nodes (keys) whose whole subtree must stay as it is.
## keep: materials that change at runtime (night lights, rainbow): merged, but never folded into a shared one.
static func merge(root: Node3D, skip: Dictionary = {}, keep: Dictionary = {}) -> int:
	var groups := {}        # key -> {mat, cell, flags, arrays...}
	var ctx := {"keep": keep, "canon": {}, "map": {}}
	_collect(root, root, skip, groups, ctx)
	var made := 0
	for key in groups:
		var g: Dictionary = groups[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.v
		arr[Mesh.ARRAY_NORMAL] = g.nrm
		if g.flags & 1:
			arr[Mesh.ARRAY_TEX_UV] = g.uv
		if g.flags & 2:
			arr[Mesh.ARRAY_COLOR] = g.col
		if g.flags & 4:
			arr[Mesh.ARRAY_TEX_UV2] = g.uv2
		arr[Mesh.ARRAY_INDEX] = g.idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(0, g.mat)
		var mi := MeshInstance3D.new()
		mi.name = "Batch%d" % made
		mi.mesh = am
		mi.cast_shadow = g.shadow
		mi.layers = g.layers
		root.add_child(mi)
		mi.global_transform = Transform3D.IDENTITY
		made += 1
		for src in g.src:
			(src as MeshInstance3D).mesh = null      # keep the node (it may have children) but stop drawing it
	return made

static func _collect(n: Node, root: Node3D, skip: Dictionary, groups: Dictionary, ctx: Dictionary) -> void:
	if skip.has(n):
		return
	if n != root and (n is RigidBody3D or n is CharacterBody3D or n is AnimatableBody3D or n is Area3D or n is GPUParticles3D or n is CPUParticles3D or n is MultiMeshInstance3D):
		return
	if n is MeshInstance3D:
		_add(n, groups, ctx)
	for c in n.get_children():
		_collect(c, root, skip, groups, ctx)

static func _add(mi: MeshInstance3D, groups: Dictionary, ctx: Dictionary) -> void:
	var mesh := mi.mesh
	if mesh == null or not mi.is_visible_in_tree() or mi.skin != null:
		return
	if mi.material_overlay != null or mi.visibility_range_end > 0.0:
		return
	var xf := mi.global_transform
	var nb := xf.basis.inverse().transposed()
	var cell := Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
	var per_surface: Array = []
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return
		var mat: Material = mi.material_override
		if mat == null:
			mat = mi.get_surface_override_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		if mat == null:
			return
		if mat is BaseMaterial3D and (mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS or mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or mat.normal_enabled):
			return            # blended / billboard pieces need their own sorting
		per_surface.append(mat)
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var flags := 0
		if a[Mesh.ARRAY_TEX_UV] != null:
			flags |= 1
		if a[Mesh.ARRAY_COLOR] != null:
			flags |= 2
		if a[Mesh.ARRAY_TEX_UV2] != null:
			flags |= 4
		var mat: Material = per_surface[s]
		# fold colour + atlas offset into the vertices so lots of materials collapse into a few shared ones
		var tint := Color.WHITE
		var uvo := Vector2.ZERO
		var uvs := Vector2.ONE
		var folded := false
		var cm := _canon(mat, ctx) if flags & 2 == 0 else null
		if cm != null:
			var sm: StandardMaterial3D = mat
			tint = sm.albedo_color
			uvo = Vector2(sm.uv1_offset.x, sm.uv1_offset.y)
			uvs = Vector2(sm.uv1_scale.x, sm.uv1_scale.y)
			mat = cm
			flags |= 2
			folded = true
		var key := "%d|%d|%d|%d|%d|%d" % [mat.get_instance_id(), cell.x, cell.y, flags, mi.cast_shadow, mi.layers]
		if not groups.has(key):
			groups[key] = {"mat": mat, "flags": flags, "shadow": mi.cast_shadow, "layers": mi.layers, "n": 0, "src": [],
				"v": PackedVector3Array(), "nrm": PackedVector3Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(),
				"col": PackedColorArray(), "idx": PackedInt32Array()}
		var g: Dictionary = groups[key]
		var base: int = g.v.size()
		var nrm = a[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			g.v.append(xf * verts[i])
		if nrm != null and (nrm as PackedVector3Array).size() == verts.size():
			for i in verts.size():
				g.nrm.append((nb * nrm[i]).normalized())
		else:
			for i in verts.size():
				g.nrm.append(Vector3.UP)
		if flags & 1:
			if folded and (uvo != Vector2.ZERO or uvs != Vector2.ONE):
				for t in (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
					g.uv.append(t * uvs + uvo)
			else:
				g.uv.append_array(a[Mesh.ARRAY_TEX_UV])
		if folded:
			for i in verts.size():
				g.col.append(tint)
		elif flags & 2:
			g.col.append_array(a[Mesh.ARRAY_COLOR])
		if flags & 4:
			g.uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		var idx = a[Mesh.ARRAY_INDEX]
		var flip := xf.basis.determinant() < 0.0
		if idx != null and (idx as PackedInt32Array).size() > 0:
			var ia: PackedInt32Array = idx
			for i in range(0, ia.size(), 3):
				if flip:
					g.idx.append(base + ia[i]); g.idx.append(base + ia[i + 2]); g.idx.append(base + ia[i + 1])
				else:
					g.idx.append(base + ia[i]); g.idx.append(base + ia[i + 1]); g.idx.append(base + ia[i + 2])
		else:
			for i in range(0, verts.size(), 3):
				if flip:
					g.idx.append(base + i); g.idx.append(base + i + 2); g.idx.append(base + i + 1)
				else:
					g.idx.append(base + i); g.idx.append(base + i + 1); g.idx.append(base + i + 2)
		g.n += 1
		if g.src.is_empty() or g.src[-1] != mi:
			g.src.append(mi)


## shared stand-in for a StandardMaterial3D that differs from others only by colour / uv offset
static func _canon(mat: Material, ctx: Dictionary) -> Material:
	if ctx.map.has(mat):
		return ctx.map[mat]
	var out: Material = null
	if mat is StandardMaterial3D and not ctx.keep.has(mat):
		var m: StandardMaterial3D = mat
		if not m.vertex_color_use_as_albedo and not m.uv1_triplanar and not m.detail_enabled and m.uv1_offset.z == 0.0:
			var sig := "%s|%d|%.2f|%d|%d|%.2f|%.2f|%s|%s|%.2f|%s|%d|%d|%d|%s" % [
				m.albedo_texture.get_instance_id() if m.albedo_texture else 0, m.transparency, m.alpha_scissor_threshold,
				m.cull_mode, m.shading_mode, m.roughness, m.metallic, m.emission_enabled, m.emission.to_html(),
				m.emission_energy_multiplier, m.emission_texture.get_instance_id() if m.emission_texture else 0,
				m.texture_filter, m.depth_draw_mode, int(m.no_depth_test), m.roughness_texture.get_instance_id() if m.roughness_texture else 0]
			if not ctx.canon.has(sig):
				var c: StandardMaterial3D = m.duplicate()
				c.albedo_color = Color.WHITE
				c.uv1_offset = Vector3.ZERO
				c.uv1_scale = Vector3.ONE
				c.vertex_color_use_as_albedo = true
				c.vertex_color_is_srgb = true
				ctx.canon[sig] = c
			out = ctx.canon[sig]
	ctx.map[mat] = out
	return out
