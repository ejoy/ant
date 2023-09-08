import bpy
import sys

fileName = sys.argv[-1]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()

bpy.ops.import_scene.fbx(filepath=fileName)

#view_layer = bpy.context.view_layer
bpy.ops.object.select_all(action="SELECT")
selection = bpy.context.selected_objects

#for obj in selection:
    #view_layer.objects.active = obj
    #bpy.ops.object.editmode_toggle()
    #bpy.ops.mesh.subdivide(number_cuts=3, smoothness=0.5)
	
bpy.ops.export_scene.gltf(filepath=fileName.replace(".fbx",".glb"))
