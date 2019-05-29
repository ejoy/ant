local ecs = ...

ecs.component_alias("scene_index", "int")
ecs.component_alias("node_index", "int")
ecs.component_alias("mesh_index", "int")
ecs.component_alias("camera_index", "int")
ecs.component_alias("accessor_index", "int")
ecs.component_alias("bufferview_index", "int")
ecs.component_alias("buffer_index", "int")
ecs.component_alias("material_index", "int")


ecs.component "gltf"
	.scene 		"scene_index"
	.scenes 	"scene[]"
	.nodes 		"node[]"
	.meshes 	"mesh_gltf[]"	
	.accessors 	"accessor[]"
	.bufferviews"bufferview[]"
	.buffers 	"buffer[]"
	.materials 	"material_gltf[]"

ecs.component "scene"
	.nodes "node_index[]"

ecs.component "node"
	.children 	"node_index[]"	
	["opt"].matrix "matrix"
	["opt"].srt 	"srt"
	["opt"].mesh 	"mesh_index"
	["opt"].camera 	"camera_index"
	
ecs.component "mesh_gltf"
	.primitives "primitive[]"
	.weights "int"
	["opt"].weights "int[]"

ecs.component "attribute"
	.POSITION "accessor_index"
	["opt"].NORMAL "accessor_index"
	["opt"].TANGENT "accessor_index"
	["opt"].BITANGENT "accessor_index"
	["opt"].COLOR "accessor_index"
	["opt"].WEIGHT "accessor_index"
	["opt"].INDICES "accessor_index"
	["opt"].TEXCOORD_0 "accessor_index"
	["opt"].TEXCOORD_1 "accessor_index"
	["opt"].TEXCOORD_2 "accessor_index"
	["opt"].TEXCOORD_3 "accessor_index"
	["opt"].TEXCOORD_4 "accessor_index"
	["opt"].TEXCOORD_5 "accessor_index"
	["opt"].TEXCOORD_6 "accessor_index"
	["opt"].TEXCOORD_7 "accessor_index"

ecs.component "primitive"	
	.attributes "attribute{}"
	["opt"].indices "accessor_index"
	["opt"].material "material_index"
	["opt"].mode 	"int"		-- POINTS, LINES, TRIANGLES
	["opt"].targets "attribute{}"

-- local sp = ecs.component "sparse"
-- 	.count 		"int"
-- 	.indices 	"string"
-- 	.values 	"string"

-- function sp:init()
-- 	assert(false, "not implement")
-- end

ecs.component "accessor"
	.component_type "string"	--5120 : "BYTE", 5121 : "UNSIGNED_BYTE", 5122 : "SHORT", 5123 : "UNSIGNED_SHORT"
								--5125 : "UNSIGNED_INT"(only valid for index buffer), 5126 : "FLOAT"
	.count "int"	-- num attribute references
	.type "string"	-- "SCALAR", "VEC2", "VEC3", "VEC4", "MAT2", "MAT3", "MAT4"
	["opt"].normalize  "boolean"
	["opt"].bufferview "bufferview_index"
	["opt"].byteoffset "int"
	["opt"].max "int"	-- only [1, 2, 3, 4, 9, 16]
	["opt"].min "int"
	--["opt"].sparse "sparse"


ecs.component "bufferview"
	.buffer "buffer_index"
	.byte_length "int"
	["opt"].byte_offset "int"	
	["opt"].byte_stride "int"
	["opt"].target "string"	-- VERTEX : 34962, INDICES : 34963


ecs.component "buffer"
	.byte_length 	"int"
	["opt"].uri 	"string"

ecs.component "material_gltf"

ecs.component "texture"

ecs.component "sampler"

ecs.component "image"


