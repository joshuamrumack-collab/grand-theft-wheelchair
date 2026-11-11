
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
ROOT = os.path.expanduser(r"E:\Godot\GrandTheftWheelchair\assets\models")

def g(x, y, z):
    # Godot (x right, y up, z back) -> Blender (x right, y forward, z up)
    return Vector((x, -z, y))

def clear():
    _M.clear()
    try:
        _TM.clear()
    except NameError:
        pass
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)

_M = {}
def mat(name, color, rough=0.6, metal=0.0, emit=None, strength=3.0, alpha=1.0):
    key = (name, tuple(color), rough, metal, emit, strength, alpha)
    if key in _M:
        return _M[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    if isinstance(color, str):
        color = hexc(color)
    b.inputs["Base Color"].default_value = (*color[:3], 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit is not None:
        ec = hexc(emit) if isinstance(emit, str) else emit
        b.inputs["Emission Color"].default_value = (*ec[:3], 1)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = (*color[:3], alpha)
    _M[key] = m
    return m

def hexc(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]

def _finish(o, m, bevel=0.0, smooth=True, subsurf=0, segs=3):
    if m is not None:
        o.data.materials.append(m)
    if bevel > 0:
        md = o.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "ANGLE"
    if subsurf > 0:
        md = o.modifiers.new("Sub", "SUBSURF")
        md.levels = subsurf
        md.render_levels = subsurf
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
        try:
            o.data.set_sharp_from_angle(angle=math.radians(40))
        except Exception:
            pass
    return o

def _mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o

def box(name, size, pos, m, bevel=0.0, rot=(0, 0, 0), subsurf=0, smooth=True):
    # size and pos in Godot axes
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    o = _mesh_obj(name, bm)
    o.location = g(*pos)
    o.rotation_euler = (rot[0], -rot[2], rot[1])
    return _finish(o, m, bevel, smooth if (bevel > 0 or subsurf) else False, subsurf)

def _axis_rot(axis):
    # cylinder default along Blender Z (= Godot Y)
    if axis == "X":
        return (0, math.pi / 2, 0)
    if axis == "Z":  # Godot Z = Blender Y
        return (math.pi / 2, 0, 0)
    return (0, 0, 0)

def cyl(name, r, h, pos, m, axis="Y", verts=24, bevel=0.0, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r, radius2=(r if r2 is None else r2), depth=h)
    o = _mesh_obj(name, bm)
    o.location = g(*pos)
    o.rotation_euler = _axis_rot(axis)
    _finish(o, m, bevel, True)
    return o

def tube(name, a, b, r, m, verts=12):
    A, B = g(*a), g(*b)
    d = B - A
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=d.length)
    o = _mesh_obj(name, bm)
    o.location = (A + B) / 2
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    _finish(o, m, 0, True)
    return o

def sph(name, r, pos, m, scl=(1, 1, 1), segs=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    o = _mesh_obj(name, bm)
    o.location = g(*pos)
    o.scale = (scl[0], scl[2], scl[1])
    _finish(o, m, 0, True)
    return o

def ico(name, r, pos, m, scl=(1, 1, 1), sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    o = _mesh_obj(name, bm)
    o.location = g(*pos)
    o.scale = (scl[0], scl[2], scl[1])
    _finish(o, m, 0, False)
    return o

def torus(name, major, minor, pos, m, axis="X", maj_seg=32, min_seg=10):
    bm = bmesh.new()
    verts = []
    for i in range(maj_seg):
        a = 2 * math.pi * i / maj_seg
        ring = []
        for j in range(min_seg):
            b = 2 * math.pi * j / min_seg
            x = (major + minor * math.cos(b)) * math.cos(a)
            y = (major + minor * math.cos(b)) * math.sin(a)
            z = minor * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        verts.append(ring)
    uvl = bm.loops.layers.uv.verify()
    for i in range(maj_seg):
        for j in range(min_seg):
            a = verts[i][j]; b = verts[(i + 1) % maj_seg][j]
            c = verts[(i + 1) % maj_seg][(j + 1) % min_seg]; d = verts[i][(j + 1) % min_seg]
            f = bm.faces.new((a, b, c, d))
            # u runs around the ring (x8 repeats), v across the tube: good for tyre tread
            for l, (ii, jj) in zip(f.loops, [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]):
                l[uvl].uv = (ii / maj_seg * 8.0, jj / min_seg)
    o = _mesh_obj(name, bm)
    o.location = g(*pos)
    o.rotation_euler = _axis_rot(axis)
    _finish(o, m, 0, True)
    return o

def join(objs, name):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o

def set_origin(o, world_pos):
    # move origin to world_pos without moving geometry
    mw = o.matrix_world.copy()
    local = mw.inverted() @ world_pos
    o.data.transform(Matrix.Translation(-local))
    o.matrix_world = mw @ Matrix.Translation(local)

def empty(name, pos):
    e = bpy.data.objects.new(name, None)
    e.location = g(*pos)
    bpy.context.scene.collection.objects.link(e)
    return e

def parent_all(root, objs):
    for o in objs:
        if o is not None and o != root:
            mw = o.matrix_world.copy()
            o.parent = root
            o.matrix_world = mw

def export(fname):
    path = os.path.join(ROOT, fname + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
        export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False)
    return path

TEX = os.path.join(os.path.dirname(ROOT), "textures")
_TM = {}
def tmat(name, tex, color="ffffff", rough=0.8, metal=0.0, alpha=False, emit=None, strength=1.0):
    """Material with a painted texture from assets/textures (optionally tinted by color)."""
    key = (name, tex, color, rough, metal, alpha)
    if key in _TM and _TM[key].name in bpy.data.materials:
        return _TM[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    c = hexc(color)
    if tex:
        it = nt.nodes.new("ShaderNodeTexImage")
        it.image = bpy.data.images.load(os.path.join(TEX, tex + ".png"), check_existing=True)
        if color.lower() != "ffffff":
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            nt.links.new(it.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*c, 1)
            nt.links.new(mix.outputs[2], b.inputs["Base Color"])
        else:
            nt.links.new(it.outputs["Color"], b.inputs["Base Color"])
        if alpha:
            nt.links.new(it.outputs["Alpha"], b.inputs["Alpha"])
            try:
                m.surface_render_method = "DITHERED"
            except Exception:
                pass
    else:
        b.inputs["Base Color"].default_value = (*c, 1)
    if emit is not None:
        ec = hexc(emit)
        b.inputs["Emission Color"].default_value = (*ec, 1)
        b.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*c, 1)
    _TM[key] = m
    return m

def uvbox(o, size=1.0):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    if o.modifiers:
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=size)
    bpy.ops.object.mode_set(mode="OBJECT")
    return o

def panel(name, w, h, pos, m, uv=(0, 0, 1, 1), facing="-Z"):
    """Flat textured quad. facing: -Z, +Z, -X, +X (front direction in Godot axes) or UP."""
    bm = bmesh.new()
    hw, hh = w / 2, h / 2
    if facing == "-Z":
        cs = [(-hw, -hh, 0), (hw, -hh, 0), (hw, hh, 0), (-hw, hh, 0)]
        vs = [bm.verts.new(g(pos[0] + c[0], pos[1] + c[1], pos[2])) for c in cs]
    elif facing == "+Z":
        cs = [(hw, -hh), (-hw, -hh), (-hw, hh), (hw, hh)]
        vs = [bm.verts.new(g(pos[0] + c[0], pos[1] + c[1], pos[2])) for c in cs]
    elif facing == "-X":
        cs = [(hw, -hh), (-hw, -hh), (-hw, hh), (hw, hh)]
        vs = [bm.verts.new(g(pos[0], pos[1] + c[1], pos[2] + c[0])) for c in cs]
    elif facing == "+X":
        cs = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
        vs = [bm.verts.new(g(pos[0], pos[1] + c[1], pos[2] + c[0])) for c in cs]
    else:
        cs = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
        vs = [bm.verts.new(g(pos[0] + c[0], pos[1], pos[2] - c[1])) for c in cs]
    f = bm.faces.new(vs)
    uvl = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = uv
    for l, (u, v) in zip(f.loops, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
        l[uvl].uv = (u, v)
    o = _mesh_obj(name, bm)
    o.data.materials.append(m)
    return o
