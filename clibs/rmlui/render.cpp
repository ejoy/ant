#include "pch.h"
#include "render.h"

#include <RmlUi/Core.h>
#include <cassert>

#ifdef RMLUI_MATRIX_ROW_MAJOR
error "need matrix type as column major"
#endif //RMLUI_MATRIX_ROW_MAJOR

extern bgfx_interface_vtbl_t* get_bgfx_interface();
#define BGFX(api) get_bgfx_interface()->api

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

#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)
Renderer::Renderer(const RmlContext* context)
    : mTransform(Rml::Matrix4f::Identity())
    , mcontext(context)
    , mEncoder(nullptr){
    const auto &vr = mcontext->viewrect;
    BGFX(set_view_scissor)(mcontext->viewid, 0, 0, 0, 0);
    BGFX(set_view_rect)(mcontext->viewid, uint16_t(vr.x), uint16_t(vr.y), uint16_t(vr.w), uint16_t(vr.h));
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

void Renderer::RenderGeometry(Rml::Vertex* vertices, int num_vertices,
                            int* indices, int num_indices, 
                            Rml::TextureHandle texture, const Rml::Vector2f& translation) {
    const Rml::Matrix4f m = mTransform * Rml::Matrix4f::Translate(translation.x, translation.y, 0.0);
    BGFX(encoder_set_transform)(mEncoder, m.data(), 1);

    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, num_vertices, (bgfx_vertex_layout_t*)mcontext->layout);

    memcpy(tvb.data, vertices, num_vertices * sizeof(Rml::Vertex));
    BGFX(encoder_set_transient_vertex_buffer)(mEncoder, 0, &tvb, 0, num_vertices);

    mIndexBuffer.SetIndex(mEncoder, indices, num_indices);
    BGFX(encoder_set_state)(mEncoder, RENDER_STATE, 0);
  
    auto fe = FE(texture);
    if (is_font_tex(fe)) {
        PropertyMap properties;
        uint16_t prog = UINT16_MAX;
        fe->GetProperties(mcontext->font_mgr, mcontext->shader, properties, prog);

        for (auto it : properties){
            const auto& v = it.second;
            if(v.uniform_idx == UINT16_MAX){
                continue;
            }

            static const Rml::String tex_property_name = "s_tex";
            if (tex_property_name == it.first){
                BGFX(encoder_set_texture)(mEncoder, v.stage, {v.uniform_idx}, {v.texid}, UINT16_MAX);
            } else {
                BGFX(encoder_set_uniform)(mEncoder, {v.uniform_idx}, v.value, 1);
            }
        }
        BGFX(encoder_submit)(mEncoder, mcontext->viewid, {prog}, 0, BGFX_DISCARD_ALL);
    } else {
        const auto &si = mcontext->shader.image;
        const uint16_t id = fe == nullptr ? uint16_t(mcontext->default_tex.texid) : fe->GetTexID();
        auto texuniformidx = si.find_uniform("s_tex");
        assert(texuniformidx != UINT16_MAX);
        BGFX(encoder_set_texture)(mEncoder, 0, {texuniformidx}, {id}, UINT32_MAX);
        BGFX(encoder_submit)(mEncoder,mcontext->viewid, { (uint16_t)si.prog }, 0, BGFX_DISCARD_ALL);
    }
}

void Renderer::Begin(){
    mEncoder = BGFX(encoder_begin)(false);
}


void Renderer::Frame(){
    BGFX(encoder_end)(mEncoder);
    mIndexBuffer.Reset();
}

void Renderer::EnableScissorRegion(bool enable) {
    if (!enable){
        BGFX(set_view_scissor)(mcontext->viewid, 0, 0, 0, 0);
    }
}

void Renderer::SetScissorRegion(int x, int y, int w, int h) {
    BGFX(set_view_scissor)(mcontext->viewid, std::max(x, 0), std::max(y, 0), w, h);
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

bool Renderer::LoadTexture(Rml::TextureHandle& texture_handle, Rml::Vector2i& texture_dimensions, const Rml::String& source){
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
		texture_dimensions.x = (int)info.width;
		texture_dimensions.y = (int)info.height;
        texture_handle = Rml::TextureHandle(new SDFFontEffectDefault(th.idx, true));
        return true;
	}
	return false;
}

bool Renderer::GenerateTexture(Rml::TextureHandle& texture_handle, const Rml::byte* source, const Rml::Vector2i& source_dimensions) {
    //RGBA data
    const uint32_t bufsize = source_dimensions.x * source_dimensions.y * 4;
     const bgfx_memory_t *mem = BGFX(alloc)(bufsize);
	memcpy(mem->data, source, bufsize);
	auto thidx = BGFX(create_texture_2d)(source_dimensions.x, source_dimensions.y, false, 1, BGFX_TEXTURE_FORMAT_RGBA8, DefaultSamplerFlag(), mem).idx;
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