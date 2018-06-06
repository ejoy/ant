#define PLATFORM_GL 

//#ifdef PLATFORM_GL 

#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include "device.h"
#include "imageutl.h"

static GLFWwindow *g_glfw_gl_win;

// 键盘输入回掉函数,内部创建的窗口所需要的
void gl_text_input(GLFWwindow *win, unsigned int codepoint)
{
    device_input_keycode(codepoint);
}

void Platform_GL_reset_window( struct device *dev,int w,int h)
{
    //todo ...
}

void Platform_Gl_Nk_init( struct device *dev);


void Platform_GL_init( struct device *dev ) {

    int width = 0, height = 0;

    // windows 
    if (!glfwInit()) {
        fprintf(stdout, "[GFLW] failed to init!\n");
        exit(1);
    }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    //glfwMakeContextCurrent(window). You have to do that before calling glewInit()
    g_glfw_gl_win = glfwCreateWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, "Demo", NULL, NULL);
    glfwMakeContextCurrent(g_glfw_gl_win);

    // setup text input for edit control 
    glfwSetWindowUserPointer(g_glfw_gl_win, dev->nk_ctx );
    glfwSetCharCallback(g_glfw_gl_win, gl_text_input);

    glfwSetWindowTitle(g_glfw_gl_win,"ant project' ui engine v0.01");    

    glewExperimental = 1;
    if (glewInit() != GLEW_OK) {
        fprintf(stderr, "Failed to setup GLEW\n");
        exit(1);
    }

    Platform_Gl_Nk_init(dev);

    nk_buffer_init_default(&dev->cmds);
}

void Platform_Gl_Nk_init( struct device *dev) {
  // platform gl shader 
   GLint status;
    static const GLchar *vertex_shader =
        NK_SHADER_VERSION
        "uniform mat4 ProjMtx;\n"
        "in vec2 Position;\n"
        "in vec2 TexCoord;\n"
        "in vec4 Color;\n"
        "out vec2 Frag_UV;\n"
        "out vec4 Frag_Color;\n"
        "void main() {\n"
        "   Frag_UV = TexCoord;\n"
        "   Frag_Color = Color;\n"
        "   gl_Position = ProjMtx * vec4(Position.xy, 0, 1);\n"
        "}\n";
    static const GLchar *fragment_shader =
        NK_SHADER_VERSION
        "precision mediump float;\n"
        "uniform sampler2D Texture;\n"
        "in vec2 Frag_UV;\n"
        "in vec4 Frag_Color;\n"
        "out vec4 Out_Color;\n"
        "void main(){\n"
        "   Out_Color = Frag_Color * texture(Texture, Frag_UV.st);\n"
        "}\n";


    dev->gl_prog = glCreateProgram();
    dev->vert_shdr = glCreateShader(GL_VERTEX_SHADER);
    dev->frag_shdr = glCreateShader(GL_FRAGMENT_SHADER);


    glShaderSource(dev->vert_shdr, 1, &vertex_shader, 0);
    glShaderSource(dev->frag_shdr, 1, &fragment_shader, 0);
    glCompileShader(dev->vert_shdr);
    glCompileShader(dev->frag_shdr);
    glGetShaderiv(dev->vert_shdr, GL_COMPILE_STATUS, &status);
    assert(status == GL_TRUE);
    glGetShaderiv(dev->frag_shdr, GL_COMPILE_STATUS, &status);
    assert(status == GL_TRUE);

    glAttachShader(dev->gl_prog , dev->vert_shdr);
    glAttachShader(dev->gl_prog , dev->frag_shdr);
    glLinkProgram(dev->gl_prog );
    glGetProgramiv(dev->gl_prog , GL_LINK_STATUS, &status);
    assert(status == GL_TRUE);

    dev->uniform_tex = glGetUniformLocation(dev->gl_prog , "Texture");
    dev->uniform_proj = glGetUniformLocation(dev->gl_prog , "ProjMtx");
    dev->attrib_pos = glGetAttribLocation(dev->gl_prog , "Position");
    dev->attrib_uv = glGetAttribLocation(dev->gl_prog , "TexCoord");
    dev->attrib_col = glGetAttribLocation(dev->gl_prog , "Color");

    {
        /* buffer setup */
        GLsizei vs = sizeof(struct nk_ui_vertex);
        size_t vp = offsetof(struct nk_ui_vertex, position);
        size_t vt = offsetof(struct nk_ui_vertex, uv);
        size_t vc = offsetof(struct nk_ui_vertex, col);

        glGenBuffers(1, &dev->vbo);
        glGenBuffers(1, &dev->ebo);
        glGenVertexArrays(1, &dev->vao);

        glBindVertexArray(dev->vao);
        glBindBuffer(GL_ARRAY_BUFFER, dev->vbo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, dev->ebo);

        glEnableVertexAttribArray((GLuint)dev->attrib_pos);
        glEnableVertexAttribArray((GLuint)dev->attrib_uv);
        glEnableVertexAttribArray((GLuint)dev->attrib_col);

        glVertexAttribPointer((GLuint)dev->attrib_pos, 2, GL_FLOAT, GL_FALSE, vs, (void*)vp);
        glVertexAttribPointer((GLuint)dev->attrib_uv, 2, GL_FLOAT, GL_FALSE, vs, (void*)vt);
        glVertexAttribPointer((GLuint)dev->attrib_col, 4, GL_UNSIGNED_BYTE, GL_TRUE, vs, (void*)vc);
    }

    glBindTexture(GL_TEXTURE_2D, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindVertexArray(0);    
}


void Platform_GL_input(struct nk_context *ctx,void *_win) {
    glfwPollEvents();
    double x,y;

    GLFWwindow *win = (GLFWwindow *)_win;    
    glfwGetCursorPos( (GLFWwindow *)win, &x, &y);

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

void Platform_GL_frame(struct device *dev,struct nk_context *ctx) 
{
    glfwSwapBuffers(g_glfw_gl_win); 
}

void Platform_GL_run(struct device *dev,struct nk_context *ctx) 
{
  GLFWwindow *win = (GLFWwindow *)g_glfw_gl_win;
  while (!glfwWindowShouldClose(win))
  {
        /* input */
        Platform_GL_input(ctx,(void*) win);
        /* Platform Draw init */
        int width,height;
        glfwGetWindowSize(win, &width, &height);
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT);
        glClearColor(0.5f, 0.5f, 0.5f, 1.0f);

        // tested inside
        if( nk_begin_titled(ctx, "Status","Status Window", nk_rect(1200-375, 10, 370, 60),
                NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE|NK_WINDOW_SCALABLE) )        {
        }
        nk_end(ctx);
        if( nk_begin_titled(ctx, "Test","Test Window", nk_rect(1200-375, 70, 370, 60),
               NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE|NK_WINDOW_SCALABLE) )   {
        }
        nk_end(ctx);
        
        /* ui */
        /*
        if(dev->nk_update_cb) {
            dev->nk_update_cb();
        } 
        */       

        /* draw */
        dev->device_draw(dev, ctx, width, height, NK_ANTI_ALIASING_ON);
        
        glfwSwapBuffers(win);
  }
}

void Platform_GL_shutdown(struct device *dev)
{
    glDetachShader(dev->gl_prog , dev->vert_shdr);
    glDetachShader(dev->gl_prog , dev->frag_shdr);
    glDeleteShader(dev->vert_shdr);
    glDeleteShader(dev->frag_shdr);
    glDeleteProgram(dev->gl_prog );
    glDeleteTextures(1, &dev->font_tex);
    glDeleteBuffers(1, &dev->vbo);
    glDeleteBuffers(1, &dev->ebo);
    nk_buffer_free(&dev->cmds);
}

void Platform_GL_draw(struct device *dev, struct nk_context *ctx, int width, int height,enum nk_anti_aliasing AA)
{
    GLfloat ortho[4][4] = {
        {2.0f, 0.0f, 0.0f, 0.0f},
        {0.0f,-2.0f, 0.0f, 0.0f},
        {0.0f, 0.0f,-1.0f, 0.0f},
        {-1.0f,1.0f, 0.0f, 1.0f},
    };
    ortho[0][0] /= (GLfloat)width;
    ortho[1][1] /= (GLfloat)height;


    /* setup global state */
    glEnable(GL_BLEND);
    //glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glActiveTexture(GL_TEXTURE0);


    /* setup program */
    glUseProgram(dev->gl_prog );
    glUniform1i(dev->uniform_tex, 0);
    glUniformMatrix4fv(dev->uniform_proj, 1, GL_FALSE, &ortho[0][0]);
    {
        /* convert from command queue into draw list and draw to screen */
        const struct nk_draw_command *cmd;
        void *vertices, *elements;
        const nk_draw_index *offset = NULL;

        /* allocate vertex and element buffer */
        glBindVertexArray(dev->vao);
        glBindBuffer(GL_ARRAY_BUFFER, dev->vbo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, dev->ebo);

        glBufferData(GL_ARRAY_BUFFER, MAX_VERTEX_MEMORY, NULL, GL_STREAM_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, MAX_ELEMENT_MEMORY, NULL, GL_STREAM_DRAW);

        /* load draw vertices & elements directly into vertex + element buffer */
        vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
        elements = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY);
        {
            /* fill convert configuration */
            struct nk_convert_config config;
            static const struct nk_draw_vertex_layout_element vertex_layout[] = {
                {NK_VERTEX_POSITION, NK_FORMAT_FLOAT, NK_OFFSETOF(struct nk_ui_vertex, position)},
                {NK_VERTEX_TEXCOORD, NK_FORMAT_FLOAT, NK_OFFSETOF(struct nk_ui_vertex, uv)},
                {NK_VERTEX_COLOR, NK_FORMAT_R8G8B8A8, NK_OFFSETOF(struct nk_ui_vertex, col)},
                {NK_VERTEX_LAYOUT_END}
            };
            NK_MEMSET(&config, 0, sizeof(config));
            config.vertex_layout = vertex_layout;
            config.vertex_size = sizeof(struct nk_ui_vertex);
            config.vertex_alignment = NK_ALIGNOF(struct nk_ui_vertex);
            config.null = dev->null;
            config.circle_segment_count = 22;
            config.curve_segment_count = 22;
            config.arc_segment_count = 22;
            config.global_alpha = 1.0f;
            config.shape_AA = AA;
            config.line_AA = AA;

            /* setup buffers to load vertices and elements */
            {
                struct nk_buffer vbuf, ebuf;
                nk_buffer_init_fixed(&vbuf, vertices, MAX_VERTEX_MEMORY);
                nk_buffer_init_fixed(&ebuf, elements, MAX_ELEMENT_MEMORY);
                nk_convert(ctx, &dev->cmds, &vbuf, &ebuf, &config);
            }
        }
        glUnmapBuffer(GL_ARRAY_BUFFER);
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);

        int dc = 0;
      /* iterate over and execute each draw command */
        nk_draw_foreach(cmd, ctx, &dev->cmds)
        {
             printf_s("draw cmd: tri = %d,texture= %d\n",cmd->elem_count,cmd->texture.id);
            if (!cmd->elem_count) continue;
            if( cmd->texture.id ) {
                glBindTexture(GL_TEXTURE_2D,(GLuint)cmd->texture.id); //dev->font_tex); //使用错误的字体纹理，也会产生透明，字体毕竟是带大量透明通道
            } 
            glScissor(
                (GLint)(cmd->clip_rect.x),
                (GLint)((height - (GLint)(cmd->clip_rect.y + cmd->clip_rect.h))),
                (GLint)(cmd->clip_rect.w),
                (GLint)(cmd->clip_rect.h));
            if( cmd->clip_rect.x || cmd->clip_rect.y || cmd->clip_rect.w ||cmd->clip_rect.h)
                printf_s("clip rect = (%f,%f,%f,%f)",cmd->clip_rect.x,cmd->clip_rect.y,
                                                     cmd->clip_rect.w,cmd->clip_rect.h);
                
            glDrawElements(GL_TRIANGLES, (GLsizei)cmd->elem_count, GL_UNSIGNED_SHORT, offset);
            offset += cmd->elem_count;
            dc ++;
        }
        
        nk_clear(ctx);
        //printf_s("\n=== draw calls = %d ===\n",dc);
    }

    /* default OpenGL state */
    glUseProgram(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    glDisable(GL_BLEND);
    glDisable(GL_SCISSOR_TEST);
}


struct nk_ui_image  Platform_GL_loadImage(const char* filename)
{
   int x,y,n;
    GLuint tex = 0;
    struct nk_ui_image image;

    unsigned char *data = loadImage(filename, &x, &y, &n, 0);

    if (!data) 
        printf_s("can not laod image %s.\n",filename);

    glEnable(GL_TEXTURE_2D);
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)x, (GLsizei)y, 0,
                GL_RGBA, GL_UNSIGNED_BYTE, data);
    

    freeImage(data);

    image.handle = tex;
    image.w = x;
    image.h = y;
    image.region[0] = image.region[1] = 0;
    image.region[2] = x;
    image.region[3] = y;

    return  image;
}

void Platform_GL_freeImage(int texId)
{
    glDeleteTextures(1,(const GLuint*)&texId) ;
}

void Platform_GL_upload_atlas( struct device *dev, const void *image, int width, int height)
{
    glGenTextures(1, &dev->font_tex);
    glBindTexture(GL_TEXTURE_2D, dev->font_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0,
                  GL_RGBA, GL_UNSIGNED_BYTE, image);    
}
//#endif 