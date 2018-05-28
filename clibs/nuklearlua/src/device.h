#ifndef __DEVICE_H__
#define __DEVICE_H__

// define platform device, nk_ui_vertex,nk_ui_image, nk_ui_font all smallest collect for nuklear
// platform device would be opengl, bgfx etc.
// struct device describes all context what gl or bgfx needed

#include <bgfx/c99/bgfx.h>
#include <bgfx/c99/platform.h>

#ifdef PLATFORM_GL
#include <gl/gl.h>
#endif

#define NK_INCLUDE_FONT_BAKING
#define NK_INCLUDE_DEFAULT_FONT

#define NK_IMPLEMENTATION
#define NK_INCLUDE_FIXED_TYPES
#define NK_INCLUDE_STANDARD_IO
#define NK_INCLUDE_STANDARD_VARARGS
#define NK_INCLUDE_DEFAULT_ALLOCATOR
#define NK_PRIVATE

// nuklear global stack 
#define NK_BUTTON_BEHAVIOR_STACK_SIZE   32
#define NK_FONT_STACK_SIZE              32
#define NK_STYLE_ITEM_STACK_SIZE        256
#define NK_FLOAT_STACK_SIZE             256
#define NK_VECTOR_STACK_SIZE            128
#define NK_FLAGS_STACK_SIZE             64
#define NK_COLOR_STACK_SIZE             256

#define NK_INCLUDE_VERTEX_BUFFER_OUTPUT

#include "../nuklear/nuklear.h"

#define NK_ANT_MAX_POINTS           1024
#define NK_ANT_EDIT_BUFFER_LEN      (1024 * 1024)
#define NK_ANT_COMBOBOX_MAX_ITEMS   1024
#define NK_ANT_MAX_FONTS            64
#define NK_ANT_MAX_RATIOS           512

#define MAX_VERTEX_MEMORY           512 * 1024
#define MAX_ELEMENT_MEMORY          128 * 1024


#define DEFAULT_WINDOW_WIDTH        1200
#define DEFAULT_WINDOW_HEIGHT       800


#define NK_SHADER_VERSION "#version 150\n"

typedef void (*device_draw_func) (struct device *dev, struct nk_context *ctx, int width, int height,
                                  enum nk_anti_aliasing AA);

// nk function prototype
typedef int (*Icallback)(void *);
typedef int (*nk_update_func)(void); 


//static nk_update_func nk_update_cb = NULL;   // ui create & run main function 
                                 

struct device {
    nk_handle 	            win;            // device window
    int                     width;          // device window width
    int                     height;         // device window height
    bool                    ownCreate;      // own create window by nuklear 

    struct nk_context *     nk_ctx;         // nuklar context
    struct nk_buffer        cmds;           // draw commands 

    struct nk_draw_null_texture null;

    device_draw_func        device_draw;   // render function for platform
    nk_update_func          nk_update_cb;  // lua main ui function 

    //for opengl
    #ifdef PLATFORM_GL
    GLuint      vbo, vao, ebo;
    GLuint      gl_prog;
    GLuint      vert_shdr;
    GLuint      frag_shdr;
    GLint       attrib_pos;
    GLint       attrib_uv;
    GLint       attrib_col;
    GLint       uniform_tex;
    GLint       uniform_proj;
    GLuint      font_tex;                    //font text for gl
    #endif 

    //for bgfx
    #ifdef PLATFORM_BGFX 
    int                         view;
   	bgfx_shader_handle_t		vsh;
	bgfx_shader_handle_t		fsh;
	bgfx_program_handle_t		bgfx_prog;
	
	bgfx_vertex_decl_t			decl;
	bgfx_uniform_handle_t		unif;
	bgfx_texture_handle_t		tex;    // font texture for bgfx 

    struct nk_buffer            vbuf;
    struct nk_buffer            ibuf;
    struct nk_convert_config    cfg;

   	struct nk_draw_vertex_layout_element	layout[4];
    #endif 
    // todo... 

	struct nk_font_atlas  	     atlas;
	struct nk_font**             fonts;
	int 						 num_fonts;
	char *						 edit_buf;
	char **						 combobox_items;
	float *						 layout_ratios;
	int 						 num_layout_ratios;  
};


struct nk_ui_vertex {
    float   position[2];
    float   uv[2];
    nk_byte col[4];
};

struct nk_ui_image {
    int   handle;
    short w,h;
    short region[4];
};

struct nk_ui_font {
    char   path[256];
    int    size;
    struct nk_font_config  cfg;
};

extern struct nk_context context;

extern void device_input_keycode(unsigned int codepoint);
extern unsigned int keycode_text[];
extern int          keycode_text_len;


#ifdef PLATFORM_GL 
extern void Platform_GL_reset_window( struct device *dev,int w,int h);
extern void Platform_GL_init( struct device *dev );
extern void Platform_GL_run( struct device *dev,struct nk_context *ctx);
extern void Platform_GL_input(struct nk_context *ctx,void *win);
extern void Platform_GL_draw( struct device *dev, struct nk_context *ctx, 
							  int width, int height,enum nk_anti_aliasing AA);							 
extern void Platform_GL_frame(struct device *dev,struct nk_context *ctx);                              
extern void Platform_GL_shutdown(struct device *dev);

extern void Platform_GL_upload_atlas( struct device *dev, const void *image, int width, int height);

extern struct nk_ui_image Platform_GL_loadImage(const char *filename);
extern void Platform_GL_freeImage(int texId);
extern void device_input_keycode(unsigned int codepoint);
#endif

#ifdef PLATFORM_BGFX

extern void Platform_Bgfx_set_window(struct device *dev,void *win);
extern void Platform_Bgfx_reset_window(struct device *dev,int w,int h);

extern void Platform_Bgfx_init( struct device *dev );
extern void Platform_Bgfx_run( struct device *dev,struct nk_context *ctx);
extern void Platform_Bgfx_input( struct nk_context *ctx,void *win);
extern void Platform_Bgfx_draw( struct device *dev,struct nk_context *ctx,
                                int width,int height,enum nk_anti_aliasing AA);
extern void Platform_Bgfx_frame(struct device *dev,struct nk_context *ctx);
extern void Platform_Bgfx_shutdown( struct device *dev);

extern void Platform_Bgfx_upload_atlas( struct device *dev, const void *image, int width, int height);

extern struct nk_ui_image  Platform_Bgfx_loadImage(const char* filename);
extern void Platform_Bgfx_freeImage( int texId); 

#endif



#endif 