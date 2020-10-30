#include "render.h"
#include "texture.h"

#include <RmlUi/Core.h>
#include <cassert>

extern bgfx_interface_vtbl_t* get_bgfx_interface();
#define BGFX(api) get_bgfx_interface()->api

#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)
Renderer::Renderer(const rml_context* context)
    : mcontext(context){
    const auto &vr = mcontext->viewrect;
    BGFX(set_view_rect)(mcontext->viewid, uint16_t(vr.x), uint16_t(vr.y), uint16_t(vr.w), uint16_t(vr.h));
    BGFX(set_view_mode)(mcontext->viewid, BGFX_VIEW_MODE_SEQUENTIAL);
}

static uint16_t
update_font_properties(const rml_context *context, const TexData *td){
    struct fonteffect_data {
        union maskdata {
            struct {
                float mask, range;
                float effect_mask, effect_range;
            };
            float data[4];
        };
        maskdata md;
        float color[4];
    };
    const uint16_t texid = td->GetTexID();
    auto update_font_data = [texid](auto font, const fonteffect_data &data){
        auto tex_uniform_idx = font->find_uniform("s_tex");
        BGFX(set_texture)(0, { tex_uniform_idx }, {texid}, UINT32_MAX);

        auto mask_uniform_idx = font->find_uniform("u_mask");
        BGFX(set_uniform)({mask_uniform_idx}, data.md.data, 1);

        auto color_uniform_idx = font->find_uniform("u_effect_color");
        if (color_uniform_idx != UINT16_MAX){
            BGFX(set_uniform)({color_uniform_idx}, data.color, 1);
        }
    };

    auto find_font = [context, texid](const TexData *td, fonteffect_data &ef_data){
        const auto tf = td->GetTextFlags();
        ef_data.md.mask = context->shader.font_mask;
        ef_data.md.range = context->shader.font_range;
        auto tocolor = [](const Rml::Colourb &c, float *cc){
            cc[0] = c.red   / 256.f;
            cc[1] = c.green / 256.f;
            cc[2] = c.blue  / 256.f;
            cc[3] = c.alpha / 256.f;
        };
        if (TDF_FontEffect_Outline & tf){
            auto outline = static_cast<const OutlineData*>(td);
            #define MAX_FONT_GLYPH_SIZE 32
            float ratio = float(outline->width) / MAX_FONT_GLYPH_SIZE;
            ef_data.md.effect_mask = context->shader.font_mask + ratio;
            ef_data.md.effect_range = context->shader.font_range;

            tocolor(outline->color, ef_data.color);
            return &(context->shader.font_outline);
        } else if (TDF_FontEffect_Shadow & tf){
            
        } else if (TDF_FontEffect_Glow & tf) {
            
        }

        return &context->shader.font;
    };

    fonteffect_data fedata;
    auto font = find_font(td, fedata);
    update_font_data(font, fedata);

    return uint16_t(font->prog);
}


static bool
is_font_tex(Rml::TextureHandle th) { 
    if (th == 0)
        return false;
    return (TexData::ToTexData(th)->GetTextFlags() & TDF_FontTex) != 0;
}

void Renderer::RenderGeometry(Rml::Vertex* vertices, int num_vertices, 
                            int* indices, int num_indices, 
                            Rml::TextureHandle texture, const Rml::Vector2f& translation) {
    if (mScissorRect.w == 0 && mScissorRect.w == mScissorRect.h){
        BGFX(set_view_scissor)(mcontext->viewid, mScissorRect.x, mScissorRect.y, mScissorRect.w, mScissorRect.h);
    } else {
        BGFX(set_view_scissor)(mcontext->viewid, 0, 0, 0, 0);
    }
    
    Rml::Matrix4f m = mTransform;
    auto t = m.GetColumn(3);
    t[0] += translation.x;
    t[1] += translation.y;
    m.SetColumn(3, t);

    BGFX(set_transform)(m.data(), 1);

    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, num_vertices, (bgfx_vertex_layout_t*)mcontext->layout);

    memcpy(tvb.data, vertices, num_vertices * sizeof(Rml::Vertex));
    BGFX(set_transient_vertex_buffer)(0, &tvb, 0, num_vertices);

    // TODO: remove bgfx_transient_index_buffer_t, use dynamic buffer with uint32_t
    bgfx_transient_index_buffer_t tib;
    BGFX(alloc_transient_index_buffer)(&tib, num_indices);
    uint16_t *data = (uint16_t*)tib.data;
    for (int ii=0; ii<num_indices; ++ii){
        int d = indices[ii];
        if (d > UINT16_MAX){
            assert(false);
            return;
        }

        *data++ = (uint16_t)d;
    }

    BGFX(set_transient_index_buffer)(&tib, 0, num_indices);
    BGFX(set_state)(RENDER_STATE, 0);
  
    if (is_font_tex(texture)) {
        auto prog = update_font_properties(mcontext, TexData::ToTexData(texture));
        BGFX(submit)(mcontext->viewid, {prog}, 0, BGFX_DISCARD_ALL);
    } else {
        const auto &si = mcontext->shader.image;
        const uint16_t id = texture == 0 ? uint16_t(mcontext->default_tex.texid) : TexData::ToTexData(texture)->GetTexID();
        auto texuniformidx = si.find_uniform("s_tex");
        assert(texuniformidx != UINT16_MAX);    
        BGFX(set_texture)(0, {texuniformidx}, {id}, UINT32_MAX);
        BGFX(submit)(mcontext->viewid, { (uint16_t)si.prog }, 0, BGFX_DISCARD_ALL);
    }
}

void Renderer::EnableScissorRegion(bool enable) {
    if (enable){
        mScissorRect.w = mScissorRect.h = 1;
    } else {
        mScissorRect.w = mScissorRect.h = 0;
    }
}

void Renderer::SetScissorRegion(int x, int y, int w, int h) {
    mScissorRect.x = std::max(x, 0);
    mScissorRect.y = std::max(y, 0);
    mScissorRect.w = w;
    mScissorRect.h = h;
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
    auto ifont = static_cast<FontInterface*>(Rml::GetFontEngineInterface());
    if (ifont->IsFontTexResource(source)){
        texture_handle = (Rml::TextureHandle)ifont->GetFontTexHandle(source, texture_dimensions);
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
        texture_handle = Rml::TextureHandle(new TexData(th.idx));
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
        texture_handle = Rml::TextureHandle(new TexData(thidx));
        return true;
    }

    return false;
}

bool Renderer::UpdateTexture(Rml::TextureHandle texhandle, const Rect &rt, uint8_t *buffer){
    const bgfx_texture_handle_t th = {TexData::ToTexData(texhandle)->GetTexID()};

    if (!BGFX_HANDLE_IS_VALID(th))
        return false;

    const uint32_t bytes = (uint32_t)rt.w * rt.h;
    auto mem = BGFX(make_ref)(buffer, bytes);
    BGFX(update_texture_2d)(th, 0, 0, rt.x, rt.y, rt.w, rt.h, mem, rt.w);
    return true;
}

void Renderer::ReleaseTexture(Rml::TextureHandle texhandle) {
    if (!is_font_tex(texhandle)){
        auto td = TexData::ToTexData(texhandle);
        BGFX(destroy_texture)({td->GetTexID()});
        delete td;
    }
}