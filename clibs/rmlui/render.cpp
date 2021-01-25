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

TransientIndexBuffer32::TransientIndexBuffer32(uint32_t sizeBytes)
: moffset(0), msize(sizeBytes)
, mdyn_indexbuffer(BGFX(create_dynamic_index_buffer)(sizeBytes, BGFX_BUFFER_INDEX32|BGFX_BUFFER_ALLOW_RESIZE))
{}

TransientIndexBuffer32::~TransientIndexBuffer32(){
    if (BGFX_HANDLE_IS_VALID(mdyn_indexbuffer)){
        BGFX(destroy_dynamic_index_buffer)(mdyn_indexbuffer);
    }
}

void 
TransientIndexBuffer32::SetIndex(bgfx_encoder_t* encoder, int *indices, int num){
    const uint32_t numbytes = num * sizeof(uint32_t);

    if (moffset * sizeof(uint32_t) + numbytes > msize){
        assert(false);
    }

    auto mem = BGFX(alloc)(numbytes);
    memcpy(mem->data, indices, numbytes);
    BGFX(update_dynamic_index_buffer)(mdyn_indexbuffer, moffset, mem);
    BGFX(encoder_set_dynamic_index_buffer)(encoder, mdyn_indexbuffer, moffset, num);

    moffset += num;
}

void
TransientIndexBuffer32::Reset(){
    moffset = 0;
}

#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)
Renderer::Renderer(const RmlContext* context)
    : mTransform(1)
    , mcontext(context)
    , mEncoder(nullptr)
    , mScissorRect{0, 0, 0, 0}{
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

void Renderer::RenderGeometry(Rml::Vertex* vertices, int num_vertices,
                            int* indices, int num_indices, 
                            Rml::TextureHandle texture) {

    BGFX(encoder_set_transform)(mEncoder, &mTransform, 1);

    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, num_vertices, (bgfx_vertex_layout_t*)mcontext->layout);

    memcpy(tvb.data, vertices, num_vertices * sizeof(Rml::Vertex));
    BGFX(encoder_set_transient_vertex_buffer)(mEncoder, 0, &tvb, 0, num_vertices);

    mIndexBuffer.SetIndex(mEncoder, indices, num_indices);
    BGFX(encoder_set_state)(mEncoder, RENDER_STATE, 0);

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
            BGFX(encoder_set_texture)(mEncoder, v.stage, {v.uniform_idx}, {v.texid}, UINT16_MAX);
        } else {
            BGFX(encoder_set_uniform)(mEncoder, {v.uniform_idx}, v.value, 1);
        }
    }

    mScissorRect.submitScissorRect(mEncoder, si);
    BGFX(encoder_submit)(mEncoder,mcontext->viewid, { (uint16_t)si.prog }, 0, BGFX_DISCARD_ALL);
}

void Renderer::Begin(){
    mEncoder = BGFX(encoder_begin)(false);
}

void Renderer::Frame(){
    BGFX(encoder_end)(mEncoder);
    mIndexBuffer.Reset();
}

void Renderer::ScissorRect::updateScissorRect(const glm::mat4 &m, const Rml::Rect &clip){
    if (clip.IsEmpty()) {
        scissorRect.x = scissorRect.y = scissorRect.w = scissorRect.h = 0;
    } else {
        scissorRect.x = clip.left();
        scissorRect.y = clip.top();
        scissorRect.w = clip.width();
        scissorRect.h = clip.height();

        updateTransform(m);
    }
}

void Renderer::ScissorRect::updateTransform(const glm::mat4 &m){
    if (!scissorRect.isVaild()){
        needShaderClipRect = false;
        return ;
    }

    needShaderClipRect = glm::mat3(1.f) != glm::mat3(m);

    glm::vec4 corners[] = {
        {scissorRect.x, scissorRect.y, 0, 1},
        {scissorRect.x + scissorRect.w, scissorRect.y, 0, 1},
        {scissorRect.x, scissorRect.y + scissorRect.h, 0, 1},
        {scissorRect.x + scissorRect.w, scissorRect.y + scissorRect.h, 0, 1},
    };

    for (auto &c : corners){
        c = m * c;
        c /= c.w;
    }

    rectVerteices[0].x = corners[0].x;rectVerteices[0].y = corners[0].y;
    rectVerteices[0].z = corners[1].x;rectVerteices[0].w = corners[1].y;

    rectVerteices[1].x = corners[2].x;rectVerteices[1].y = corners[2].y;
    rectVerteices[1].z = corners[3].x;rectVerteices[1].w = corners[3].y;
}

Rect Renderer::ScissorRect::get(){
    return Rect{
        int(rectVerteices[0].x),
        int(rectVerteices[0].y),
        int(rectVerteices[1].z - rectVerteices[0].x),
        int(rectVerteices[1].w - rectVerteices[0].y)};
}

void Renderer::ScissorRect::submitScissorRect(bgfx_encoder_t* encoder, const shader_info &si){
    if (scissorRect.isVaild()){
        if (needShaderClipRect){
            BGFX(encoder_set_scissor_cached)(encoder, UINT16_MAX);
            auto uniformIdx = si.find_uniform("u_clip_rect");
            if (uniformIdx != UINT16_MAX){
                BGFX(encoder_set_uniform)(encoder, {uniformIdx}, rectVerteices, sizeof(rectVerteices)/sizeof(rectVerteices[0]));
            }
        } else {
            auto r = get();
            BGFX(encoder_set_scissor)(encoder, r.x, r.y, r.w, r.h);
        }
    } else {
        BGFX(encoder_set_scissor_cached)(encoder, UINT16_MAX);
    }
}

void Renderer::SetScissorRegion(Rml::Rect const& clip) {
    mScissorRect.updateScissorRect(mTransform, clip);
}

static inline bool
CustomTexture(const Rml::String &key){
    return (!key.empty() && key[0] == '?');
}

static inline SamplerFlag
DefaultSamplerFlag(){
    return SamplerFlag(
        SamplerFlag::U_CLAMP|SamplerFlag::V_CLAMP
        );  // u,v: clamp, min,max: linear
}

bool Renderer::LoadTexture(Rml::TextureHandle& texture_handle, Rml::Size& texture_dimensions, const Rml::String& source){
    auto ifont = static_cast<FontEngine*>(Rml::GetFontEngineInterface());
    if (ifont->IsFontTexResource(source)){
        texture_handle = ifont->GetFontTexHandle(source, texture_dimensions);
        return true;
    }
    Rml::FileInterface* ifile = Rml::GetFileInterface();
	Rml::FileHandle fh = ifile->Open(source);
	if (!fh)
		return false;
	
	ifile->Seek(fh, 0, SEEK_END);
	const size_t bufsize = ifile->Tell(fh);
	ifile->Seek(fh, 0, SEEK_SET);
	
    const bgfx_memory_t *mem = BGFX(alloc)((uint32_t)bufsize);
	ifile->Read(mem->data, bufsize, fh);
	ifile->Close(fh);

	bgfx_texture_info_t info;
	const bgfx_texture_handle_t th = BGFX(create_texture)(mem, DefaultSamplerFlag(), 1, &info);
	if (th.idx != UINT16_MAX){
		texture_dimensions.w = info.width;
		texture_dimensions.h = info.height;
        texture_handle = Rml::TextureHandle(new SDFFontEffectDefault(th.idx, true));
        return true;
	}
	return false;
}

bool Renderer::GenerateTexture(Rml::TextureHandle& texture_handle, const Rml::byte* source, const Rml::Size& source_dimensions) {
    //RGBA data
    const uint32_t bufsize = source_dimensions.w * source_dimensions.h * 4;
     const bgfx_memory_t *mem = BGFX(alloc)(bufsize);
	memcpy(mem->data, source, bufsize);
	auto thidx = BGFX(create_texture_2d)(source_dimensions.w, source_dimensions.h, false, 1, BGFX_TEXTURE_FORMAT_RGBA8, DefaultSamplerFlag(), mem).idx;
    if (thidx != UINT16_MAX){
        texture_handle = Rml::TextureHandle(new SDFFontEffectDefault(thidx, true));
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