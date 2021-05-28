#define _USE_MATH_DEFINES

#include "bgfx/c99/bgfx.h"
#include "common.h"


#define BGFX(_API)  bgfx_##_API

#define LIGHTMAPPER_IMPLEMENTATION
#define LM_DEBUG_INTERPOLATION
#include "lightmapper.h"

#include <cassert>

#include <unorder_map>

#ifndef M_PI // even with _USE_MATH_DEFINES not always available
#define M_PI 3.14159265358979323846
#endif

typedef struct {
	float p[3];
	float t[2];
} vertex_t;

struct FBO
{
	bgfx_view_id_t viewid;
	bgfx_frame_buffer_handle_t fb;
	bgfx_texture_handle_t rbTexture;
	bgfx_texture_handle_t rbDepth;

	void create(bgfx_view_id_t vid, int w, int h, uint64_t rbflags, bool needdpeth)
	{
		viewid = vid;
		bgfx_texture_handle_t rb[2];
		rb[0] = rbTexture = BGFX(create_texture_2d)(w, h, false, 1, BGFX_TEXTURE_FORMAT_RGBA32F, rbflags, NULL);

		if (needdpeth){
			rb[1] = rbDepth = BGFX(create_texture_2d)(w, h, false, 1, BGFX_TEXTURE_FORMAT_D24, rbflags, NULL);
		}
		fb = BGFX(create_frame_buffer_from_handles)(needdepth ? 2 : 1, rb, false);

		BGFX(set_view_frame_buffer)(viewid, fb);
	}
};

typedef struct 
{
	FBO fb_render;
	FBO fb_downsample;
	
	bgfx_program_handle_t weight_ds_prog;
	bgfx_program_handle_t ds_prog;

	bgfx_uniform_handle_t hemispheres;
	bgfx_uniform_handle_t weights;
	bgfx_texture_handle_t weight_texture;

	bgfx_view_id_t storage_viewid;
} downsampleShadingData_t;

typedef struct 
{
	bgfx_view_id_t viewid;
    bgfx_program_handle_t prog;
    bgfx_uniform_handle_t s_lightmap;
    
    bgfx_texture_handle_t lightmap;
    int w, h;

    bgfx_vertex_layout_handle_t layout;
    bgfx_vertex_buffer_handle_t vb;
    bgfx_index_buffer_handle_t ib;
    vertex_t *vertices;
	uint16_t *indices;
	uint32_t vertexCount, indexCount;

	downsampleShadingData_t	shading;
} scene_t;

static int initScene(scene_t *scene);
static void drawScene(scene_t *scene, float *view, float *projection);
static void destroyScene(scene_t *scene);

static bgfx_shader_handle_t loadShader(const char *filename)
{
	FILE* f = fopen(filename, "rb");
	fseek(f, SEEK_END);
	uint32_t size = ftell(f);
	fseek(f, SEEK_SET);
	bgfx_memory_t *m = BGFX(alloc)(size);
	fread(f, size, m->data);
	fclose(f);

	return BGFX(create_shader)(m);
}

typedef std::unorder_map<std::string, bgfx_uniform_handle_t>	uniforms;
static bgfx_program_handle_t loadProgram(const char *vp, const char *fp, uniforms& u)
{
	bgfx_shader_handle_t vs = loadShader(vp);
	if (!BGFX_HANDLE_IS_VALID(vs))
		return BGFX_INVALID_HANDLE;
	bgfx_shader_handle_t fs = loadShader(fp);
	if (!BGFX_HANDLE_IS_VALID(fs))
		return BGFX_INVALID_HANDLE;

	bgfx_program_handle_t prog = BGFX(create_program)(vs, fs, false);

	loadShaderUniform(vs, u);
	loadShaderUniform(fs, u);
	return prog;
}

static void initDownsampleShading(lm_context *ctx, scene_t *scene)
{
	int widths[2], heights[2];
	lmGetDownsampleFramebufferSize(ctx, widths, heights);

	downsampleShadingData_t *s = &scene->shading;

	uint64_t flags = BGFX_TEXTURE_RT|BGFX_SAMPLER_MIN_POINT|BGFX_SAMPLER_MAG_POINT|BGFX_SAMPLER_U_CLAMP|BGFX_SAMPLER_V_CLAMP;
	s->fb_render.create(widths[0], heights[0], flags, true);
	s->fb_downsample.create(widths[1], heights[1], flags, false);

	{
		unifroms u;
		s->weight_ds_prog = loadProgram("test/bake_example/shaders/vs_downsample.bin", "test/bake_example/shaders/fs_weight_downsample.bin", u);
		auto it = u.find("hemispheres");
		if (it != u.end()){
			s->hemispheres = it->second;
		}

		it = u.find("weights");
		if (it != u.end()){
			s->weights = it->second;
		}		
	}
	{
		uniforms u;
		s->ds_prog = loadProgram("test/bake_example/shaders/vs_downsample.bin", "test/bake_example/shaders/fs_downsample.bin", u);
		auto it = u.find("hemispheres");
		assert(s->hemispheres == it->second);
	}

	downsampleShadingInfo si;
	si.viewids[0] = s->fb_render.viewid;
	si.viewids[1] = s->fb_downsample.viewid;
	si.rbTexture[0]=s->fb_render.rbTexture;
	si.rbTexture[1]=s->fb_downsample.rbTexture;

	si.progWeightDS = s->weight_ds_prog;
	si.progDS 		= s->ds_prog;
	si.hemispheres	= s->hemispheres;
	si.weight		= s->weights;

	lmSetDownsampleShaderingInfo(ctx, &si);
	lmSetStorageViewID(ctx, s->storage_viewid);
}

static int bake(scene_t *scene)
{
	lm_context *ctx = lmCreate(
		64,               // hemisphere resolution (power of two, max=512)
		0.001f, 100.0f,   // zNear, zFar of hemisphere cameras
		1.0f, 1.0f, 1.0f, // background color (white for ambient occlusion)
		2, 0.01f,         // lightmap interpolation threshold (small differences are interpolated rather than sampled)
						  // check debug_interpolation.tga for an overview of sampled (red) vs interpolated (green) pixels.
		0.0f);            // modifier for camera-to-surface distance for hemisphere rendering.
		                  // tweak this to trade-off between interpolated normals quality and other artifacts (see declaration).

	if (!ctx)
	{
		fprintf(stderr, "Error: Could not initialize lightmapper.\n");
		return 0;
	}

	initDownsampleShading(ctx, scene);

	int w = scene->w, h = scene->h;
	float *data = calloc(w * h * 4, sizeof(float));
	lmSetTargetLightmap(ctx, data, w, h, 4);

	lmSetGeometry(ctx, NULL,                                                                 // no transformation in this example
		LM_FLOAT, (unsigned char*)scene->vertices + offsetof(vertex_t, p), sizeof(vertex_t),
		LM_NONE , NULL                                                   , 0               , // no interpolated normals in this example
		LM_FLOAT, (unsigned char*)scene->vertices + offsetof(vertex_t, t), sizeof(vertex_t),
		scene->indexCount, LM_UNSIGNED_SHORT, scene->indices);

	int vp[4];
	float view[16], projection[16];
	double lastUpdateTime = 0.0;
	while (lmBegin(ctx, vp, view, projection))
	{
		// render to lightmapper framebuffer
		BGFX(set_view_rect)(scene->viewid, vp[0], vp[1], vp[2], vp[3]);
		drawScene(scene, view, projection);

		// display progress every second (printf is expensive)
		printf("\r%6.2f%%", lmProgress(ctx) * 100.0f);
		lmEnd(ctx);
	}
	printf("\rFinished baking %d triangles.\n", scene->indexCount / 3);

	lmDestroy(ctx);

	// postprocess texture
	float *temp = calloc(w * h * 4, sizeof(float));
	for (int i = 0; i < 16; i++)
	{
		lmImageDilate(data, temp, w, h, 4);
		lmImageDilate(temp, data, w, h, 4);
	}
	lmImageSmooth(data, temp, w, h, 4);
	lmImageDilate(temp, data, w, h, 4);
	lmImagePower(data, w, h, 4, 1.0f / 2.2f, 0x7); // gamma correct color channels
	free(temp);

	// save result to a file
	if (lmImageSaveTGAf("result.tga", data, w, h, 4, 1.0f))
		printf("Saved result.tga\n");

	// upload result
	glBindTexture(GL_TEXTURE_2D, scene->lightmap);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_FLOAT, data);
	free(data);

	return 1;
}

static void error_callback(int error, const char *description)
{
	fprintf(stderr, "Error: %s\n", description);
}



class bakeApp : public entry::AppI
{
public:
	bakeApp(const char* _name, const char* _description, const char* _url)
	: entry::AppI(_name, _description, _url){}

	void init(int32_t _argc, const char* const* _argv, uint32_t _width, uint32_t _height){
		if (!initScene(&scene)){
			printf("init scene failed");
		}

		if (!initShading(&dsShading)){
			printf("init downsample shading failed");
		}
	}

	int  shutdown() override{

	}

	///
	bool update() override {
		uint32_t width, height;
		uint32_t debug, reset;
		entry::MouseState ms;
		if (!entry::processEvents(width, height, debug, reset, &ms)){
			static bool s_bake = false;
			if (!s_bake){
				bake(scene);
				s_bake = true;
			}

			const bx::Vec3 at  = { 0.0f, 0.0f,   0.0f };
			const bx::Vec3 eye = { 0.0f, 0.0f, -35.0f };
			float view[16];
			bx::mtxLookAt(view, eye, at);

			float proj[16];
			bx::mtxProj(proj, 45.0f, float(width)/float(height), 0.1f, 100.0f, bgfx::getCaps()->homogeneousDepth);
			bgfx::setViewTransform(0, view, proj);

			// Set view 0 default viewport.
			bgfx::setViewRect(0, 0, 0, uint16_t(width), uint16_t(height));

			// draw to screen with a blueish sky
			bgfx::setViewClear(0, BGFX_CLEAR_COLOR|BGFX_CLEAR_DEPTH
			, 0x303030ff
			, 1.0f
			, 0)
			drawScene(scene, view, projection);
		}
	}
private:
	scene_t scene;
};

ENTRY_IMPLEMENT_MAIN(
	  bakeApp
	, "bakeApp"
	, "test bakeApp"
	, ""
	);

// int main(int argc, char* argv[])
// {
// 	glfwSetErrorCallback(error_callback);

// 	if (!glfwInit())
// 	{
// 		fprintf(stderr, "Could not initialize GLFW.\n");
// 		return EXIT_FAILURE;
// 	}

// 	glfwWindowHint(GLFW_RED_BITS, 8);
// 	glfwWindowHint(GLFW_GREEN_BITS, 8);
// 	glfwWindowHint(GLFW_BLUE_BITS, 8);
// 	glfwWindowHint(GLFW_ALPHA_BITS, 8);
// 	glfwWindowHint(GLFW_DEPTH_BITS, 32);
// 	glfwWindowHint(GLFW_STENCIL_BITS, GLFW_DONT_CARE);
// 	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
// 	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
// 	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
// 	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
// 	glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
// 	glfwWindowHint(GLFW_SAMPLES, 4);

// 	GLFWwindow *window = glfwCreateWindow(1024, 768, "Lightmapping Example", NULL, NULL);
// 	if (!window)
// 	{
// 		fprintf(stderr, "Could not create window.\n");
// 		glfwTerminate();
// 		return EXIT_FAILURE;
// 	}

// 	glfwMakeContextCurrent(window);
// 	gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);
// 	glfwSwapInterval(1);

// 	scene_t scene = {0};
// 	if (!initScene(&scene))
// 	{
// 		fprintf(stderr, "Could not initialize scene.\n");
// 		glfwDestroyWindow(window);
// 		glfwTerminate();
// 		return EXIT_FAILURE;
// 	}

// 	printf("Ambient Occlusion Baking Example.\n");
// 	printf("Use your mouse and the W, A, S, D, E, Q keys to navigate.\n");
// 	printf("Press SPACE to start baking one light bounce!\n");
// 	printf("This will take a few seconds and bake a lightmap illuminated by:\n");
// 	printf("1. The mesh itself (initially black)\n");
// 	printf("2. A white sky (1.0f, 1.0f, 1.0f)\n");

// 	while (!glfwWindowShouldClose(window))
// 	{
// 		mainLoop(window, &scene);
// 	}

// 	destroyScene(&scene);
// 	glfwDestroyWindow(window);
// 	glfwTerminate();
// 	return EXIT_SUCCESS;
// }

// helpers ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
static int loadSimpleObjFile(const char *filename, vertex_t **vertices, unsigned int *vertexCount, unsigned short **indices, unsigned int *indexCount);

static int initScene(scene_t *scene)
{
	// load mesh
	if (!loadSimpleObjFile("gazebo.obj", &scene->vertices, &scene->vertexCount, &scene->indices, &scene->indexCount))
	{
		fprintf(stderr, "Error loading obj file\n");
		return 0;
	}

    BGFX(vertex_layout_begin)(&scene->layout, BGFX_RENDERER_TYPE_NOOP);
    BGFX(vertex_layout_add)(&scene->layout, BGFX_ATTRIB_POSITION, 3, BGFX_ATTRIB_TYPE_FLOAT, false, false);
    BGFX(vertex_layout_add)(&scene->layout, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
    BGFX(vertex_layout_end)(&scene->layout);

	bgfx_memory_t *m = BGFX(copy)(scene->vertices, scene->vertexCount * sizeof(vertex_t));
	scene->vb = BGFX(create_vertex_buffer)(m, &scene->layout, BGFX_BUFFER_NONE);

	bgfx_memory_t *mib = BGFX(copy)(scene->indices, sizeof(uint16_t) * scene->indexCount);
	scene->ib = BGFX(create_index_buffer)(mib, BGFX_BUFFER_NONE);

	// create lightmap texture
	scene->w = 654;
	scene->h = 654;

	bgfx_memory_t *tm = BGFX(alloc)(sizeof(uint8_t)*4);
	float *tmdata = (float*)tm->data;
	tmdata[0] = 0; tmdata[1] = 0; tmdata[2] = 0; tmdata[3] = 255;
	scene->lightmap = BGFX(create_texture_2d)(1, 1, false, 1, BGFX_TEXTURE_FORMAT_RGBA, BGFX_SAMPLER_U_CLAMP|BGFX_SAMPLER_V_CLAMP, )
	const char* vs_scene = "test/bake_example/shaders/vs_scene.bin";
	const char* fs_scene = "test/bake_example/shaders/vs_scene.bin";

	if (!loadProgram(vs_scene, fs_scene, scene);)
	{
		fprintf(stderr, "Error loading shader\n");
		return 0;
	}


	scene->fb_render.create();
	return 1;
}

static void drawScene(scene_t *scene, float *view, float *projection)
{
	BGFX(set_view_transform)(scene->viewid, view, projection);
	BGFX(set_state)(BGFX_STATE_DEFAULT);
	BGFX(set_vertex_buffer)(0, scene->vb, 0, scene->vertexCount);
	BGFX(set_index_buffer)(scene->ib, 0, scene->indexCount);
	BGFX(set_texture)(0, scene->s_lightmap, scene->lightmap, UINT32_MAX);

	BGFX(submit)(scene->viewid, scene->prog, 0, BGFX_DISCARD_ALL);
	// glEnable(GL_DEPTH_TEST);

	// glUseProgram(scene->program);
	// glUniform1i(scene->s_lightmap, 0);
	// glUniformMatrix4fv(scene->u_projection, 1, GL_FALSE, projection);
	// glUniformMatrix4fv(scene->u_view, 1, GL_FALSE, view);

	// glBindTexture(GL_TEXTURE_2D, scene->lightmap);

	// glBindVertexArray(scene->vao);
	// glDrawElements(GL_TRIANGLES, scene->indexCount, GL_UNSIGNED_SHORT, 0);
}

static void destroyScene(scene_t *scene)
{
	free(scene->vertices);
	free(scene->indices);
	glDeleteVertexArrays(1, &scene->vao);
	glDeleteBuffers(1, &scene->vbo);
	glDeleteBuffers(1, &scene->ibo);
	glDeleteTextures(1, &scene->lightmap);
	glDeleteProgram(scene->program);
}

static int loadSimpleObjFile(const char *filename, vertex_t **vertices, unsigned int *vertexCount, unsigned short **indices, unsigned int *indexCount)
{
	FILE *file = fopen(filename, "rt");
	if (!file)
		return 0;
	char line[1024];

	// first pass
	unsigned int np = 0, nn = 0, nt = 0, nf = 0;
	while (!feof(file))
	{
		fgets(line, 1024, file);
		if (line[0] == '#') continue;
		if (line[0] == 'v')
		{
			if (line[1] == ' ') { np++; continue; }
			if (line[1] == 'n') { nn++; continue; }
			if (line[1] == 't') { nt++; continue; }
			assert(!"unknown vertex attribute");
		}
		if (line[0] == 'f') { nf++; continue; }
		assert(!"unknown identifier");
	}
	assert(np && np == nn && np == nt && nf); // only supports obj files without separately indexed vertex attributes

	// allocate memory
	*vertexCount = np;
	*vertices = calloc(np, sizeof(vertex_t));
	*indexCount = nf * 3;
	*indices = calloc(nf * 3, sizeof(unsigned short));

	// second pass
	fseek(file, 0, SEEK_SET);
	unsigned int cp = 0, cn = 0, ct = 0, cf = 0;
	while (!feof(file))
	{
		fgets(line, 1024, file);
		if (line[0] == '#') continue;
		if (line[0] == 'v')
		{
			if (line[1] == ' ') { float *p = (*vertices)[cp++].p; char *e1, *e2; p[0] = (float)strtod(line + 2, &e1); p[1] = (float)strtod(e1, &e2); p[2] = (float)strtod(e2, 0); continue; }
			if (line[1] == 'n') { /*float *n = (*vertices)[cn++].n; char *e1, *e2; n[0] = (float)strtod(line + 3, &e1); n[1] = (float)strtod(e1, &e2); n[2] = (float)strtod(e2, 0);*/ continue; } // no normals needed
			if (line[1] == 't') { float *t = (*vertices)[ct++].t; char *e1;      t[0] = (float)strtod(line + 3, &e1); t[1] = (float)strtod(e1, 0);                                continue; }
			assert(!"unknown vertex attribute");
		}
		if (line[0] == 'f')
		{
			unsigned short *tri = (*indices) + cf;
			cf += 3;
			char *e1, *e2, *e3 = line + 1;
			for (int i = 0; i < 3; i++)
			{
				unsigned long pi = strtoul(e3 + 1, &e1, 10);
				assert(e1[0] == '/');
				unsigned long ti = strtoul(e1 + 1, &e2, 10);
				assert(e2[0] == '/');
				unsigned long ni = strtoul(e2 + 1, &e3, 10);
				assert(pi == ti && pi == ni);
				tri[i] = (unsigned short)(pi - 1);
			}
			continue;
		}
		assert(!"unknown identifier");
	}

	fclose(file);
	return 1;
}

static int loadShaderUniform(bgfx_shader_handle_t sh, uniforms &u)
{
	bgfx_uniform_handle_t handles[16];
	uint16_t num = BGFX(get_shader_uniforms)(sh, handles, 16);
	for (int ii=0; ii<num; ++ii){
		bgfx_uniform_info_t info;
		BGFX(get_uniform_info)(handles[ii], &info);

		if (u.find(info.name) == u.end()){
			u[info.name] = handles[ii];
		}
	}
}

static void multiplyMatrices(float *out, float *a, float *b)
{
	for (int y = 0; y < 4; y++)
		for (int x = 0; x < 4; x++)
			out[y * 4 + x] = a[x] * b[y * 4] + a[4 + x] * b[y * 4 + 1] + a[8 + x] * b[y * 4 + 2] + a[12 + x] * b[y * 4 + 3];
}
static void translationMatrix(float *out, float x, float y, float z)
{
	out[ 0] = 1.0f; out[ 1] = 0.0f; out[ 2] = 0.0f; out[ 3] = 0.0f;
	out[ 4] = 0.0f; out[ 5] = 1.0f; out[ 6] = 0.0f; out[ 7] = 0.0f;
	out[ 8] = 0.0f; out[ 9] = 0.0f; out[10] = 1.0f; out[11] = 0.0f;
	out[12] = x;    out[13] = y;    out[14] = z;    out[15] = 1.0f;
}
static void rotationMatrix(float *out, float angle, float x, float y, float z)
{
	angle *= (float)M_PI / 180.0f;
	float c = cosf(angle), s = sinf(angle), c2 = 1.0f - c;
	out[ 0] = x*x*c2 + c;   out[ 1] = y*x*c2 + z*s; out[ 2] = x*z*c2 - y*s; out[ 3] = 0.0f;
	out[ 4] = x*y*c2 - z*s; out[ 5] = y*y*c2 + c;   out[ 6] = y*z*c2 + x*s; out[ 7] = 0.0f;
	out[ 8] = x*z*c2 + y*s; out[ 9] = y*z*c2 - x*s; out[10] = z*z*c2 + c;   out[11] = 0.0f;
	out[12] = 0.0f;         out[13] = 0.0f;         out[14] = 0.0f;         out[15] = 1.0f;
}
static void transformPosition(float *out, float *m, float *p)
{
	float d = 1.0f / (m[3] * p[0] + m[7] * p[1] + m[11] * p[2] + m[15]);
	out[2] =     d * (m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14]);
	out[1] =     d * (m[1] * p[0] + m[5] * p[1] + m[ 9] * p[2] + m[13]);
	out[0] =     d * (m[0] * p[0] + m[4] * p[1] + m[ 8] * p[2] + m[12]);
}
static void transposeMatrix(float *out, float *m)
{
	out[ 0] = m[0]; out[ 1] = m[4]; out[ 2] = m[ 8]; out[ 3] = m[12];
	out[ 4] = m[1]; out[ 5] = m[5]; out[ 6] = m[ 9]; out[ 7] = m[13];
	out[ 8] = m[2]; out[ 9] = m[6]; out[10] = m[10]; out[11] = m[14];
	out[12] = m[3]; out[13] = m[7]; out[14] = m[11]; out[15] = m[15];
}
static void perspectiveMatrix(float *out, float fovy, float aspect, float zNear, float zFar)
{
	float f = 1.0f / tanf(fovy * (float)M_PI / 360.0f);
	float izFN = 1.0f / (zNear - zFar);
	out[ 0] = f / aspect; out[ 1] = 0.0f; out[ 2] = 0.0f;                       out[ 3] = 0.0f;
	out[ 4] = 0.0f;       out[ 5] = f;    out[ 6] = 0.0f;                       out[ 7] = 0.0f;
	out[ 8] = 0.0f;       out[ 9] = 0.0f; out[10] = (zFar + zNear) * izFN;      out[11] = -1.0f;
	out[12] = 0.0f;       out[13] = 0.0f; out[14] = 2.0f * zFar * zNear * izFN; out[15] = 0.0f;
}
