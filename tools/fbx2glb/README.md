#### import fbx to glb file using Blender 2.93.1
1. copy import_fbx.py to ${BlenderInstallDir}/scripts/addons/io_scene_fbx, and replace import_fbx.py
2. call command
``` sh
xx/blender.exe tools/prefab_editor/Export.GLB.py
```

#### why we need import_fbx.py
right now, blender import fbx from maya exported is poor, any maya material's texture will not import correctly.
we just add maya texture name for checking when importing some fbx