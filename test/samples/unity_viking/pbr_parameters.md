

### fs_mesh_pbr_metal.sc工作流参数
u_params.x  < 1   : metallic flow,            // 金属流
            = 1   : specular flow             // 兼容镜面工作流素材，走镜面分支
        .y  < 1   ：use tex   value           // 使用纹理贴图控制金属度说明(或镜面转换)
		    = 1   ：use float value           // 仅使用一个浮点值描述金属度
		.z  = 0~1 : matellic  .x = 0, .y = 1  // 0-1 的金属度描述
		.w  = 0~1 ：roughness
		           (smoothnes inverse).x = 1

### fs_mesh_pbr_specular.sc工作流参数
u_params.xz                             // reserve 本shader 只是镜面流，不做金属兼容
u_params.y < 1 : 使用 specTex 
           = 1 ：使用 specColor         // 实际上已根据纹理大小判断存在与否，自动使用specColor
		   							    // 在不支持宏选项编译的shader 情况下
u_params.w = 0~1 :roughness   			// 0-1 不同的粗糙度（smoothness 的相反值）

u_specularColor   		  // 当没有specular 时，提供的 specular 颜色控制

### 通用参数
uniform u_diffuseColor    // 附加的漫反射颜色控制，默认为{1,1,1,1}

uniform u_tiling
   		.xy               // MainTex 的 tiling, 描述纹理缩放
   		.zw               // DetalTex 的 tiling，当提供时

uniform u_misc
   		.x                // alpha 
   		.y                // detailNormalScale 细节纹理凹凸程度

uniform vec4 u_FogColor;  // fog color 
uniform vec4 u_FogParams
       .xy                // reserve
       .w = far
	   .z = near 
uniform vec4 u_Emission;  // 自发光颜色，当提供时,是否提供 EmissionMap 是个效率选择问题?

### 贴图参数
4 张最基本贴图
s_basecolor     基本色贴图
s_normal        法线贴图
s_metallic      金属贴图 或 镜面贴图 ，shader 中名称会重新定义
s_texCube       环境贴图

2 张增益贴图，表示细节纹理
s_detailcolor    细节贴图
s_detailnormal   细节法线贴图
