#define PLATFORM_BGFX

#include <bgfx/c99/bgfx.h>
#include <bgfx/c99/platform.h>

#include <bgfx/bgfx.h>
#include <string.h>

#include "device.h"
#include "imageutl.h"

#define WINDOW_OWN_CREATE          // 注释，可以去掉glfw 自创建窗口相关依赖

#ifdef  WINDOW_OWN_CREATE
#define  GLFW_EXPOSE_NATIVE_WIN32
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
#endif 

#ifdef  WINDOW_OWN_CREATE

// 内部窗口相关函数组
static GLFWwindow *g_glfw_bgfx_win  = NULL;

void bgfx_text_input(GLFWwindow *win, unsigned int codepoint) {
    device_input_keycode(codepoint);
}

// 键盘输入回掉函数,内部创建的窗口所需要的
void Platform_Bgfx_own_window_rest(GLFWwindow *win,int w,int h) {
    // todo ...
    bgfx_reset(w,h,BGFX_RESET_VSYNC);
}

void Platform_Bgfx_own_window_create(struct device *dev,char *vs,char *fs)
{
    // create window 
    if (!glfwInit()) {
        fprintf(stdout, "[GFLW] failed to init!\n");
        exit(1);
    }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    int width = DEFAULT_WINDOW_WIDTH, height = DEFAULT_WINDOW_HEIGHT;
    
    g_glfw_bgfx_win= glfwCreateWindow( width, height, "NuklearLua", NULL, NULL);
    glfwMakeContextCurrent(g_glfw_bgfx_win);

    // setup text input for edit control 
    glfwSetWindowUserPointer(g_glfw_bgfx_win, dev->nk_ctx );
    glfwSetCharCallback(g_glfw_bgfx_win, bgfx_text_input);
    glfwSetWindowSizeCallback(g_glfw_bgfx_win,Platform_Bgfx_own_window_rest );

    glfwSetWindowTitle(g_glfw_bgfx_win,"ant project' ui engine v0.01");    

    glewExperimental = 1;
    if (glewInit() != GLEW_OK) {
        fprintf(stderr, "Failed to setup GLEW\n");
        exit(1);
    }

    void* hWnd = (void*)(uintptr_t) glfwGetWin32Window ( g_glfw_bgfx_win);
    Platform_Bgfx_set_window(dev, hWnd);
    
    // 自己拥有创建bgfx ( c99 )
    bgfx_init_t init;
    bgfx_init_ctor(&init);
    init.type     = BGFX_RENDERER_TYPE_DIRECT3D11; //BGFX_RENDERER_TYPE_OPENGL; //BGFX_RENDERER_TYPE_DIRECT3D11;    
    init.vendorId = BGFX_PCI_ID_NONE;
    init.resolution.width  = width;
    init.resolution.height = height;
    init.resolution.reset  = BGFX_RESET_VSYNC; 

    bgfx_init(&init);
    bgfx_reset(width, height, BGFX_RESET_VSYNC);
    bgfx_set_debug(BGFX_DEBUG_TEXT);
    bgfx_set_view_clear(0, BGFX_CLEAR_COLOR|BGFX_CLEAR_DEPTH, 0x303030ff, 1.0f, 0);

    if( init.type  == BGFX_RENDERER_TYPE_DIRECT3D11 ) {
        strcpy(vs,"shader/dx-vs_nuklear_texture.bin");
        strcpy(fs,"shader/dx-fs_nuklear_texture.bin");
    }        
}

void Platform_Bgfx_own_window_input(struct device *dev,struct nk_context *ctx)
{
    glfwPollEvents();
    double x,y;
    glfwGetCursorPos( (GLFWwindow *)g_glfw_bgfx_win, &x, &y);
    GLFWwindow *win = (GLFWwindow *)g_glfw_bgfx_win;

    nk_input_begin(ctx);
    // keyboard
    for (int i = 0; i < keycode_text_len; ++i)
        nk_input_unicode(ctx, keycode_text[i]);
    
    // mouse
    nk_input_motion(ctx, (int)x, (int)y);
    nk_input_button(ctx, NK_BUTTON_LEFT, (int)x, (int)y, glfwGetMouseButton( (GLFWwindow *)win, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS);
    nk_input_button(ctx, NK_BUTTON_MIDDLE, (int)x, (int)y, glfwGetMouseButton( (GLFWwindow *)win, GLFW_MOUSE_BUTTON_MIDDLE) == GLFW_PRESS);
    nk_input_button(ctx, NK_BUTTON_RIGHT, (int)x, (int)y, glfwGetMouseButton( (GLFWwindow *)win, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS);
    
    nk_input_key(ctx, NK_KEY_DEL, glfwGetKey(win, GLFW_KEY_DELETE) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_ENTER, glfwGetKey(win, GLFW_KEY_ENTER) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_TAB, glfwGetKey(win, GLFW_KEY_TAB) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_BACKSPACE, glfwGetKey(win, GLFW_KEY_BACKSPACE) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_LEFT, glfwGetKey(win, GLFW_KEY_LEFT) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_RIGHT, glfwGetKey(win, GLFW_KEY_RIGHT) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_UP, glfwGetKey(win, GLFW_KEY_UP) == GLFW_PRESS);
    nk_input_key(ctx, NK_KEY_DOWN, glfwGetKey(win, GLFW_KEY_DOWN) == GLFW_PRESS);

    if (glfwGetKey(win, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS ||
        glfwGetKey(win, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS) {
        nk_input_key(ctx, NK_KEY_COPY, glfwGetKey(win, GLFW_KEY_C) == GLFW_PRESS);
        nk_input_key(ctx, NK_KEY_PASTE, glfwGetKey(win, GLFW_KEY_P) == GLFW_PRESS);
        nk_input_key(ctx, NK_KEY_CUT, glfwGetKey(win, GLFW_KEY_X) == GLFW_PRESS);
        nk_input_key(ctx, NK_KEY_CUT, glfwGetKey(win, GLFW_KEY_E) == GLFW_PRESS);
        nk_input_key(ctx, NK_KEY_SHIFT, 1);
    } else {
        nk_input_key(ctx, NK_KEY_COPY, 0);
        nk_input_key(ctx, NK_KEY_PASTE, 0);
        nk_input_key(ctx, NK_KEY_CUT, 0);
        nk_input_key(ctx, NK_KEY_SHIFT, 0);
    }
    nk_input_end(ctx);

    keycode_text_len = 0;
}

void Platform_Bgfx_own_window_run(struct device *dev,struct nk_context *ctx)
{
  GLFWwindow* win = (GLFWwindow*)g_glfw_bgfx_win;
  while (!glfwWindowShouldClose( win ) )
  {
        // input 
        Platform_Bgfx_own_window_input(dev,ctx);

        // Platform Draw init 
        int width,height;
        glfwGetWindowSize(win, &width, &height);

		bgfx_touch(0);
        
        // tested inside
        if( nk_begin_titled(ctx, "Status","Status Window", nk_rect(1200-375, 10, 370, 60),
               NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE|NK_WINDOW_SCALABLE) )   {
        }
        nk_end(ctx);

        if( nk_begin_titled(ctx, "Test","Test Window", nk_rect(1200-375, 70, 370, 60),
               NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE|NK_WINDOW_SCALABLE) )   {
        }
        nk_end(ctx);
                
        // draw 
        dev->device_draw(dev, ctx, width, height, NK_ANTI_ALIASING_ON);  

        bgfx_frame(0);
  }
}

#endif 


const bgfx_memory_t *load_file(char *path);


int  Platform_Bgfx_Nk_init( struct device *dev,const char *vs,const char *fs);

void Platform_Bgfx_set_window(struct device *dev,void *win) {

    if(win) {
        dev->win = nk_handle_ptr( win );
    }else {
        dev->win = nk_handle_id(0);
    }
    
	bgfx_platform_data_t bpd;
	bpd.ndt = NULL;
	bpd.nwh = win;
	bpd.context = NULL;
	bpd.backBuffer = NULL;
	bpd.backBufferDS = NULL;
	bpd.session = NULL;

    bgfx_set_platform_data(&bpd);
} 

void Platform_Bgfx_reset_window(struct device *dev,int w,int h)
{
    if(!dev->ownCreate)
        bgfx_reset(w,h,BGFX_RESET_VSYNC);
    //ownCreate window size manage by nuklear itself        
}

void Platform_Bgfx_init( struct device *dev )
{
    dev->view  = 0;

    char vs[256] = "shader/vs_nuklear_texture.bin";
    char fs[256] = "shader/fs_nuklear_texture.bin";

    // 外部没有提供窗口，内部创建
    if( !dev->win.id )  
    {
        dev->ownCreate = true; 
        //printf_s(" bgfx own create window .\n");
        //while(1) {};
#ifdef  WINDOW_OWN_CREATE
        Platform_Bgfx_own_window_create(dev,vs,fs);
#endif
    }
    else {
        dev->ownCreate = false;

        printf_s(" bgfx init begin.\n");
        bgfx_init_t init;
   	    bgfx_init_ctor(&init);
		init.type     = BGFX_RENDERER_TYPE_OPENGL;   //BGFX_RENDERER_TYPE_DIRECT3D11; //
		init.vendorId = BGFX_PCI_ID_NONE;
		//init.resolution.width  = width;
		//init.resolution.height = height;
		init.resolution.reset  = BGFX_RESET_VSYNC; 
    	bgfx_init(&init);

	    //bgfx_reset(width, height, BGFX_RESET_VSYNC);
	    bgfx_set_debug(BGFX_DEBUG_TEXT);
        bgfx_set_view_clear(0, BGFX_CLEAR_COLOR|BGFX_CLEAR_DEPTH, 0x303030ff, 1.0f, 0);

        if( init.type  == BGFX_RENDERER_TYPE_DIRECT3D11 ) {
            strcpy(vs,"shader/dx-vs_nuklear_texture.bin");
            strcpy(fs,"shader/dx-fs_nuklear_texture.bin");
        }        
        printf_s(" bgfx init end.\n");
    } 

    Platform_Bgfx_Nk_init( dev,vs,fs );
    nk_buffer_init_default(&dev->cmds);
}

// result = 0 means success 
int Platform_Bgfx_Nk_init( struct device *dev,const char *vs,const char *fs)
{
    if(!vs || !fs) 
        printf_s("\n\nnuklearlua must have a bgfx vs,fs shader.\n");

    int result = 0;

	bgfx_vertex_decl_begin(&dev->decl, BGFX_RENDERER_TYPE_NOOP);
	bgfx_vertex_decl_add(&dev->decl, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, 0, 0);
	bgfx_vertex_decl_add(&dev->decl, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, 0, 0);
	bgfx_vertex_decl_add(&dev->decl, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, 0);
	bgfx_vertex_decl_end(&dev->decl);
    
    const bgfx_memory_t *vsh = load_file( (char*) vs );
	if(!vsh) {
		printf_s("nuklearlua load shader %s error.\n",vs);
        result |= 1<<0;
	}
	const bgfx_memory_t *fsh = load_file( (char*)fs );
	if(!fsh) {
		printf_s("nuklearlua load shader %s error.\n",fs);
        result |= 1<<1;
    }

	dev->vsh = bgfx_create_shader(vsh);
	dev->fsh = bgfx_create_shader(fsh);
	dev->bgfx_prog = (bgfx_create_program(dev->vsh, dev->fsh, 1));
	if(dev->bgfx_prog.idx == UINT16_MAX) {
		printf_s("nuklearlua create program error.\n\n");
        result |= 1<<2;
    }
	dev->unif = bgfx_create_uniform("s_texColor", BGFX_UNIFORM_TYPE_INT1, 1); 

    printf_s("load bgfx shader (%d,%d) and build program(%d)...\n",dev->vsh,dev->fsh,dev->bgfx_prog);
    printf_s("uniform tex = %d\n",dev->unif.idx);
    
    bgfx_vertex_decl_t *decl = &dev->decl;
       
    nk_convert_config  *config = &dev->cfg;
    NK_MEMSET(config, 0, sizeof(config));

    static const struct nk_draw_vertex_layout_element vertex_layout[] = {
        {NK_VERTEX_POSITION, NK_FORMAT_FLOAT, NK_OFFSETOF(struct nk_ui_vertex, position)},
        {NK_VERTEX_TEXCOORD, NK_FORMAT_FLOAT, NK_OFFSETOF(struct nk_ui_vertex, uv)},
        {NK_VERTEX_COLOR, NK_FORMAT_R8G8B8A8, NK_OFFSETOF(struct nk_ui_vertex, col)},
        {NK_VERTEX_LAYOUT_END}
    };
    
    config->vertex_layout = vertex_layout;
    config->vertex_size = sizeof(struct nk_ui_vertex);
    config->vertex_alignment = NK_ALIGNOF(struct nk_ui_vertex);
    config->null = dev->null;     // 这里是无效的，dev->null 并未初始化
    config->circle_segment_count = 22;
    config->curve_segment_count = 22;
    config->arc_segment_count = 22;
    config->global_alpha = 1.0f;
    config->shape_AA = NK_ANTI_ALIASING_ON;
    config->line_AA = NK_ANTI_ALIASING_ON;
    
    return result ;
}

void Platform_Bgfx_shutdown(struct device *dev)
{
	bgfx_destroy_texture(dev->tex);
	bgfx_destroy_uniform(dev->unif);
    bgfx_destroy_shader(dev->vsh);
    bgfx_destroy_shader(dev->fsh);
	bgfx_destroy_program(dev->bgfx_prog);

    nk_buffer_free(&dev->cmds);    
}


void Platform_Bgfx_input_env(struct device *dev,struct nk_context *ctx) 
{
    // how to do 
}
void Platform_Bgfx_input(struct device *dev,struct nk_context *ctx) 
{
    if( dev->ownCreate) {
#ifdef OWN_WINDOW_CREATE 
       Platform_Bgfx_own_window_input(dev,ctx);
#endif 
    } else {
       Platform_Bgfx_input_env(dev,ctx);
    }
}

void Platform_Bgfx_frame(struct device *dev,struct nk_context *ctx) 
{
    bgfx_frame(0);   
}

// for own mainloop
void Platform_Bgfx_run(struct device *dev,struct nk_context *ctx) {

  if( ! dev->ownCreate  ) {
        // draw window without pump message
        //if(dev->nk_update_cb) { dev->nk_update_cb(); }        
        //dev->device_draw(dev, ctx, width, height, NK_ANTI_ALIASING_ON);  
        Platform_Bgfx_input( dev,ctx );
        // tested inside
        if( nk_begin_titled(ctx, "Status","Status Window", nk_rect(150, 10, 370, 60),
               NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE|NK_WINDOW_SCALABLE) )   {
        }
        nk_end(ctx);

        if( nk_begin_titled(ctx, "Test","Test Window", nk_rect(150, 410, 370, 60),
               NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE|NK_WINDOW_SCALABLE) )   {
        }
        nk_end(ctx);
        
        /* draw */
        dev->device_draw(dev, ctx, dev->width, dev->height, NK_ANTI_ALIASING_ON);  

        return; 
  }

#ifdef WINDOW_OWN_CREATE 
    Platform_Bgfx_own_window_run( dev,ctx);
#endif
}


int get_transient_buf(uint32_t vc, bgfx_vertex_decl_t *dcl, uint32_t ic)
{
	return bgfx_get_avail_transient_vertex_buffer(vc, dcl) >= vc &&
		bgfx_get_avail_transient_index_buffer(ic) >= ic;
}

void Platform_Bgfx_draw(struct device *dev, struct nk_context *ctx, int width, int height,enum nk_anti_aliasing AA)
{
    /* fill convert configuration */
    //dev->cfg.null = dev->null;     //important
    nk_buffer_init_default(&dev->vbuf);
    nk_buffer_init_default(&dev->ibuf);

#ifdef MY_DEBUG
    printf("v allocated =%d; needed =%d\n",dev->vbuf.allocated,dev->vbuf.needed);
    printf("i allocated =%d; needed =%d\n",dev->ibuf.allocated,dev->ibuf.needed);
    printf("begin convert\n");
#endif 

    nk_convert( ctx, &dev->cmds, &dev->vbuf, &dev->ibuf,&dev->cfg); 

	void *vd = dev->vbuf.memory.ptr;
	void *id = dev->ibuf.memory.ptr;
	size_t vds = dev->vbuf.needed; //.allocated;
	size_t ids = dev->ibuf.needed; //.allocated;

#ifdef MY_DEBUG
    printf("v allocated =%d; needed =%d\n",dev->vbuf.allocated,dev->vbuf.needed);
    printf("i allocated =%d; needed =%d\n",dev->ibuf.allocated,dev->ibuf.needed);
#endif 

	uint32_t offset = 0;
	uint32_t vc = vds / dev->decl.stride;

    float ortho[4][4] = {
		{2.0f, 0.0f, 0.0f, 0.0f},
		{0.0f,-2.0f, 0.0f, 0.0f},
		{0.0f, 0.0f,-1.0f, 0.0f},
		{-1.0f,1.0f, 0.0f, 1.0f},
	};
	ortho[0][0] /= width;
	ortho[1][1] /= height;

	static int texId = 0;
	if(vc > 0) 
    {
		uint32_t toti = ids / sizeof(uint16_t);
		bgfx_transient_vertex_buffer_t tvb;
		bgfx_transient_index_buffer_t tib;
		if(get_transient_buf(vc, &dev->decl, toti)) 
        {
			bgfx_alloc_transient_vertex_buffer(&tvb, vc, &dev->decl);
			memcpy(tvb.data, vd, vds);
			bgfx_alloc_transient_index_buffer(&tib, toti);
			memcpy(tib.data, id, ids);

			const nk_draw_command *cmd;         // = nk__draw_begin( ctx, &dev->cmds);
			nk_draw_foreach(cmd,ctx,&dev->cmds) // while(cmd) 
            {
                //printf_s("bgfx: draw cmd: tri = %d,texture= %d\n",cmd->elem_count,cmd->texture.id);

                if(!cmd->elem_count) continue;

                uint64_t state = BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A |
                                 BGFX_STATE_BLEND_FUNC( BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA );

                bgfx_set_view_rect(0, 0, 0, width, height);               
				bgfx_set_view_transform(0, 0, ortho);
				bgfx_set_state(  state,                  // for opengl
                                 //BGFX_STATE_DEFAULT ,  // for d3d11
                                 0);
				bgfx_texture_handle_t tex; 
                tex.idx = 0; 
               
				if(cmd->texture.id)	{	
                    tex.idx =  (uint16_t)(cmd->texture.id);
                    bgfx_set_texture(0, dev->unif, tex, UINT32_MAX);   
                }

               //if( cmd->clip_rect.x  && cmd->clip_rect.y  && cmd->clip_rect.w>0 &&cmd->clip_rect.h>0) 
               struct nk_vec2 clip_size = nk_rect_size( cmd->clip_rect );
               if( clip_size.x<16384 && clip_size.y<16384 )
               {
                  //printf_s("clip rect = (%f,%f,%f,%f)",cmd->clip_rect.x,cmd->clip_rect.y,
                  //                                   cmd->clip_rect.w,cmd->clip_rect.h);
                  float sx =  cmd->clip_rect.x<0? 0: cmd->clip_rect.x;
                  float sy =  cmd->clip_rect.y<0? 0: cmd->clip_rect.y;
                  //sy =  - (cmd->clip_rect.y + cmd->clip_rect.h);
                  bgfx_set_scissor(
                  //bgfx_set_view_scissor( 0,
                                    sx, sy,
                                    (cmd->clip_rect.w), (cmd->clip_rect.h) );
                  //printf_s("x =%.02f,y = %.02f,w=%.02f,h=%.02f\n",cmd->clip_rect.x,cmd->clip_rect.y,
                  //              cmd->clip_rect.w,cmd->clip_rect.h);
               }

				bgfx_set_transient_vertex_buffer(0, &tvb, 0, vc);
				bgfx_set_transient_index_buffer(&tib, offset, cmd->elem_count);
				bgfx_submit(dev->view, dev->bgfx_prog, 0, 0);
				offset += cmd->elem_count;			

                //if( cmd->clip_rect.x >=0 && cmd->clip_rect.y >=0 && cmd->clip_rect.w>=0 &&cmd->clip_rect.h>=0) 
                //   bgfx_set_view_scissor(0,0,0,width,height);
			}
		}
	}    

    nk_clear(ctx);
    nk_buffer_free(&dev->vbuf);
    nk_buffer_free(&dev->ibuf);
 
    //bgfx_frame(0);
}


void Platform_Bgfx_upload_atlas( struct device *dev, const void *image, int width, int height)
{
    bgfx_texture_format_t type = BGFX_TEXTURE_FORMAT_RGBA8;      // BGFX_TEXTURE_FORMAT_A8;
    int c = 4;
    int size = width * height *c;
    const bgfx_memory_t *m = bgfx_alloc(size);
    memcpy(m->data,image,size);
    printf_s("upload bgfx begin...\n");
    dev->tex = bgfx_create_texture_2d(width,height,0,1,type,0,m);
    printf_s("upload bgfx end...\n");
}



struct nk_ui_image  Platform_Bgfx_loadImage(const char* filename)
{
    int w,h,n;
    bgfx_texture_handle_t tex;
    struct nk_ui_image image;

    unsigned char *data = loadImage(filename, &w, &h, &n, 0);

    if (!data) 
        printf_s("can not laod image %s.\n",filename);

    int size = w * h *n;
    const bgfx_memory_t *m = bgfx_alloc(size);
    memcpy(m->data,data,size);
    tex = bgfx_create_texture_2d(w,h,0,1,BGFX_TEXTURE_FORMAT_RGBA8,0,m);

    freeImage(data);

    image.handle = (tex.idx);   //int
    image.w = w;
    image.h = h;
    image.region[0] = image.region[1] = 0;
    image.region[2] = w;
    image.region[3] = h;

    return  image;
}

void Platform_Bgfx_freeImage( int texId)
{
    bgfx_texture_handle_t th;
    th.idx = texId;
    bgfx_destroy_texture(th);
}

const bgfx_memory_t *load_file(char *path)
{
	if(!path)
		return 0;

    FILE *fp = fopen(path,"rb");
    if(!fp)
        return 0;

    fseek(fp,0,SEEK_END);
    size_t len = ftell(fp);
    if(len<=0)  {
        fclose(fp);
        return 0; 
    }
    fseek(fp,0,SEEK_SET);

	char *buf = (char*) malloc(len + 1);
    fread(buf,len,1,fp);
    fclose(fp);

	buf[len] = 0;
	const bgfx_memory_t *m = bgfx_alloc(len + 1);
	if(!m) {
		free(buf);
		return m;
	}
	memcpy(m->data, buf, len + 1);
	free(buf);

	return m;	
}

