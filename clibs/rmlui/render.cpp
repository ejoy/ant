#include "pch.h"
#include "render.h"

#include <RmlUi/Core.h>
#include <RmlUi/FileInterface.h>
#include <cassert>

#ifdef RMLUI_MATRIX_ROW_MAJOR
error "need matrix type as column major"
#endif //RMLUI_MATRIX_ROW_MAJOR

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(api) ibgfx()->api

#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)
Renderer::Renderer(const RmlContext* context)
    : mcontext(context)
    , mEncoder(nullptr){
    UpdateViewRect();
    BGFX(set_view_mode)(mcontext->viewid, BGFX_VIEW_MODE_SEQUENTIAL);
}

static inline SDFFontEffect*
FE(Rml::TextureHandle th){
    return reinterpret_cast<SDFFontEffect*>(th);
}


static bool
is_font_tex(SDFFontEffect *fe) { 
    return fe ? (fe->GetType() & FE_FontTex) != 0 : false;
}

void Renderer::UpdateViewRect(){
    const auto &vr = mcontext->viewrect;
    BGFX(set_view_scissor)(mcontext->viewid, vr.x, vr.y, vr.w, vr.h);
    BGFX(set_view_rect)(mcontext->viewid, uint16_t(vr.x), uint16_t(vr.y), uint16_t(vr.w), uint16_t(vr.h));
}

static uint32_t getTextureFlags(Rml::SamplerFlag flags) {
    switch (flags) {
    default:
    case Rml::SamplerFlag::Unset:
        return UINT32_MAX;
    case Rml::SamplerFlag::Repeat:
        return 0;
    case Rml::SamplerFlag::RepeatX:
        return BGFX_SAMPLER_V_BORDER;
    case Rml::SamplerFlag::RepeatY:
        return BGFX_SAMPLER_U_BORDER;
    case Rml::SamplerFlag::NoRepeat:
        return BGFX_SAMPLER_U_BORDER | BGFX_SAMPLER_V_BORDER;
    }
}

void Renderer::RenderGeometry(Rml::Vertex* vertices, int num_vertices, Rml::Index* indices, int num_indices, Rml::TextureHandle texture, Rml::SamplerFlag flags) {
    BGFX(encoder_set_state)(mEncoder, RENDER_STATE, 0);
    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, num_vertices, (bgfx_vertex_layout_t*)mcontext->layout);

    memcpy(tvb.data, vertices, num_vertices * sizeof(Rml::Vertex));
    BGFX(encoder_set_transient_vertex_buffer)(mEncoder, 0, &tvb, 0, num_vertices);

    bgfx_transient_index_buffer_t tib;
    BGFX(alloc_transient_index_buffer)(&tib, num_indices, true);

    static_assert(sizeof(Rml::Index) == sizeof(uint32_t));
    memcpy(tib.data, indices, num_indices * sizeof(Rml::Index));
    BGFX(encoder_set_transient_index_buffer)(mEncoder, &tib, 0, num_indices);

    auto fe = FE(texture);
    auto get_shader = [&](){
        shader::ShaderType st;
        if (fe){
            switch (fe->GetType()){
            case FontEffectType(FE_Outline|FE_FontTex): st = mScissorRect.needShaderClipRect ? shader::ST_font_outline_cr : shader::ST_font_outline; break;
            case FontEffectType(FE_Shadow|FE_FontTex): st = mScissorRect.needShaderClipRect ? shader::ST_font_shadow_cr : shader::ST_font_shadow; break;
            case FontEffectType(FE_None|FE_FontTex): st = mScissorRect.needShaderClipRect ? shader::ST_font_cr : shader::ST_font; break;
            case FontEffectType::FE_None: st = mScissorRect.needShaderClipRect ? shader::ST_image_cr : shader::ST_image; break;
            default: st = shader::ST_count;
            }
        } else {
            st = mScissorRect.needShaderClipRect ? shader::ST_image_cr : shader::ST_image;
        }

        return mcontext->shader.get_shader(st);
    };

    auto si = get_shader();

    PropertyMap properties;
    if (is_font_tex(fe)) {
        fe->GetProperties(mcontext->font_mgr, si, properties);
    } else {
        Property p;
        p.uniform_idx = si.find_uniform("s_tex");
        p.texid = fe ? fe->GetTexID() : uint16_t(mcontext->default_tex.texid);
        p.stage = 0;
        properties.emplace("s_tex", p);
    }

    for (auto it : properties){
        const auto& v = it.second;
        if(v.uniform_idx == UINT16_MAX)
            continue;

        static const Rml::String tex_property_name = "s_tex";
        if (tex_property_name == it.first){
            BGFX(encoder_set_texture)(mEncoder, 
                v.stage, {v.uniform_idx}, {v.texid}, getTextureFlags(flags));
        } else {
            BGFX(encoder_set_uniform)(mEncoder, {v.uniform_idx}, v.value, 1);
        }
    }

    mScissorRect.submitScissorRect(mEncoder, si);
    const uint8_t discard_flags = ~BGFX_DISCARD_TRANSFORM;
    BGFX(encoder_submit)(mEncoder,mcontext->viewid, { (uint16_t)si.prog }, 0, discard_flags);
    // #ifdef _DEBUG
    // mScissorRect.drawDebugScissorRect(mEncoder, mcontext->viewid, mcontext->shader.debug_draw.prog);
    // #endif //_DEBUG
}

void Renderer::Begin(){
    mEncoder = BGFX(encoder_begin)(false);
}

void Renderer::Frame(){
    BGFX(encoder_end)(mEncoder);
}

#ifdef _DEBUG
void Renderer::ScissorRect::drawDebugScissorRect(bgfx_encoder_t *encoder, uint16_t viewid, uint16_t progid){
    if (!needShaderClipRect)
        return;

    glm::mat4 m(1.f);
    BGFX(encoder_set_transform)(encoder, &m, 1);

    static bgfx_vertex_layout_t debugLayout;
    static bool isinit = false;
    if (!isinit){
        isinit = true;
        BGFX(vertex_layout_begin)(&debugLayout, BGFX_RENDERER_TYPE_COUNT);
        BGFX(vertex_layout_add)(&debugLayout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
        BGFX(vertex_layout_end)(&debugLayout);
    }
    
    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, 4, &debugLayout);

    memcpy(tvb.data, &rectVerteices, sizeof(glm::vec2)*4);
    BGFX(encoder_set_transient_vertex_buffer)(encoder, 0, &tvb, 0, 4);

    bgfx_transient_index_buffer_t tib;
    BGFX(alloc_transient_index_buffer)(&tib, 6, false);

    const uint16_t indices[] = {0, 1, 2, 1, 3, 2};
    BGFX(encoder_set_transient_index_buffer)(encoder, &tib, 0, 6);

    BGFX(encoder_set_state)(encoder, RENDER_STATE, 0);

    BGFX(encoder_submit)(encoder, viewid, {progid}, 0, BGFX_DISCARD_ALL);
}
#endif //_DEBUG

void Renderer::ScissorRect::submitScissorRect(bgfx_encoder_t* encoder, const shader_info &si){
    if (needShaderClipRect) {
        auto uniformIdx = si.find_uniform("u_clip_rect");
        if (uniformIdx != UINT16_MAX) {
            BGFX(encoder_set_uniform)(encoder, { uniformIdx }, rectVerteices, sizeof(rectVerteices) / sizeof(rectVerteices[0]));
        }
    }
}

void Renderer::SetTransform(const glm::mat4x4& transform) {
    BGFX(encoder_set_transform)(mEncoder, &transform, 1);
}

void Renderer::SetClipRect() {
    mScissorRect.needShaderClipRect = false;
    BGFX(encoder_set_scissor_cached)(mEncoder, UINT16_MAX);
}

void Renderer::SetClipRect(const glm::u16vec4& r) {
    mScissorRect.needShaderClipRect = false;
    BGFX(encoder_set_scissor)(mEncoder, r.x, r.y, r.z, r.w);
}

void Renderer::SetClipRect(glm::vec4 r[2]) {
    mScissorRect.needShaderClipRect = true;
    mScissorRect.rectVerteices[0] = r[0];
    mScissorRect.rectVerteices[1] = r[1];
    BGFX(encoder_set_scissor_cached)(mEncoder, UINT16_MAX);
}

static inline bool
CustomTexture(const Rml::String &key){
    return (!key.empty() && key[0] == '?');
}

bool Renderer::LoadTexture(Rml::TextureHandle& handle, Rml::Size& dimensions, const Rml::String& path){
    auto ifont = static_cast<FontEngine*>(Rml::GetFontEngineInterface());
    if (ifont->IsFontTexResource(path)){
        handle = ifont->GetFontTexHandle(path, dimensions);
        return true;
    }
    Rml::FileInterface* ifile = Rml::GetFileInterface();
	Rml::FileHandle fh = ifile->Open(path);
	if (!fh)
		return false;
	
	ifile->Seek(fh, 0, SEEK_END);
	const size_t bufsize = ifile->Tell(fh);
	ifile->Seek(fh, 0, SEEK_SET);
	
    const bgfx_memory_t *mem = BGFX(alloc)((uint32_t)bufsize);
	ifile->Read(mem->data, bufsize, fh);
	ifile->Close(fh);

	bgfx_texture_info_t info;
	const bgfx_texture_handle_t th = BGFX(create_texture)(mem, 0, 1, &info);
	if (th.idx != UINT16_MAX){
		dimensions.w = info.width;
		dimensions.h = info.height;
        handle = Rml::TextureHandle(new SDFFontEffectDefault(th.idx, true));
        return true;
	}
	return false;
}

bool Renderer::UpdateTexture(Rml::TextureHandle texhandle, const Rect &rt, uint8_t *buffer){
    const bgfx_texture_handle_t th = {FE(texhandle)->GetTexID()};

    if (!BGFX_HANDLE_IS_VALID(th))
        return false;

    const uint32_t bytes = (uint32_t)rt.w * rt.h;
    auto mem = BGFX(make_ref)(buffer, bytes);
    BGFX(update_texture_2d)(th, 0, 0, rt.x, rt.y, rt.w, rt.h, mem, rt.w);
    return true;
}

void Renderer::ReleaseTexture(Rml::TextureHandle texhandle) {
    auto fe = FE(texhandle);
    if (!is_font_tex(fe)){
        BGFX(destroy_texture)({fe->GetTexID()});
        delete fe;
    }
}
