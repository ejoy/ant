#include "pch.h"
#include "render.h"
#include "../bgfx/bgfx_interface.h"

#include <core/Core.h>
#include <core/Interface.h>
#include <cassert>

#ifdef RMLUI_MATRIX_ROW_MAJOR
error "need matrix type as column major"
#endif //RMLUI_MATRIX_ROW_MAJOR

#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)

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

class TextureUniform {
public:
    TextureUniform(uint16_t id, uint16_t tex)
        : id(id)
        , tex(tex)
    {}
    void Submit(bgfx_encoder_t* encoder, uint32_t flags = UINT32_MAX) {
        BGFX(encoder_set_texture)(encoder, 0, {id}, {tex}, flags);
    }
private:
    uint16_t id;
    uint16_t tex;
};

class Uniform {
public:
    Uniform(uint16_t id)
        : id(id)
    {}
    void Submit(bgfx_encoder_t* encoder, float v0, float v1 = 0.f, float v2 = 0.f, float v3 = 0.f) {
        glm::vec4 vec = {v0, v1, v2, v3};
        BGFX(encoder_set_uniform)(encoder, {id}, &vec, 1);
    }
    void Submit(bgfx_encoder_t* encoder, glm::vec4 vec[2]) {
        BGFX(encoder_set_uniform)(encoder, {id}, vec, 2);
    }
private:
    uint16_t id;
};

class ColorUniform: public Uniform {
public:
    ColorUniform(uint16_t id, Rml::Color color)
        : Uniform(id)
        , color(color)
    {}
    void Submit(bgfx_encoder_t* encoder) {
        Uniform::Submit(encoder, 
            color.r / 255.f,
            color.g / 255.f,
            color.b / 255.f,
            color.a / 255.f
        );
    }
private:
    Rml::Color color;
};

class Material {
public:
    virtual ~Material() {};
    virtual void     Submit(bgfx_encoder_t* encoder) = 0;
    virtual uint16_t Program(const RenderState& state, const shader& s) = 0;
};

class TextureMaterial: public Material {
public:
    TextureMaterial(shader const& s, uint16_t texid, Rml::SamplerFlag flags)
        : tex_uniform(s.find_uniform("s_tex"), texid)
        , flags(getTextureFlags(flags))
    { }
    void Submit(bgfx_encoder_t* encoder) override {
        tex_uniform.Submit(encoder, flags);
    }
    uint16_t Program(const RenderState& state, const shader& s) override {
        return state.needShaderClipRect
            ? s.image_cr
            : s.image
            ;
    }
private:
    TextureUniform tex_uniform;
    uint32_t flags;
};

class TextMaterial: public Material {
public:
    TextMaterial(const shader& s, struct font_manager* F, uint16_t texid, int8_t edgeValueOffset = 0, float width = 0.f)
        : tex_uniform(s.find_uniform("s_tex"), texid)
        , mask_uniform(s.find_uniform("u_mask"))
        , mask_0(F->font_manager_sdf_mask(F) - F->font_manager_sdf_distance(F, edgeValueOffset))
        , mask_2(width)
    { }
    void Submit(bgfx_encoder_t* encoder) override {
        tex_uniform.Submit(encoder);
        const float distMultiplier = 1.f;
        mask_uniform.Submit(encoder, mask_0, distMultiplier, mask_2);
    }
    uint16_t Program(const RenderState& state, const shader& s) override {
        return state.needShaderClipRect
            ? s.font_cr
            : s.font
            ;
    }
protected:
    TextureUniform tex_uniform;
    Uniform mask_uniform;
    float mask_0;
    float mask_2;
};

class TextStrokeMaterial: public TextMaterial {
public:
    TextStrokeMaterial(const shader& s, struct font_manager* F, uint16_t texid, int8_t edgeValueOffset, Rml::Color color, float width)
        : TextMaterial(s, F, texid, edgeValueOffset, width)
        , color_uniform(s.find_uniform("u_effect_color"), color)
    {}
    void Submit(bgfx_encoder_t* encoder) override {
        TextMaterial::Submit(encoder);
        color_uniform.Submit(encoder);
    }
    uint16_t Program(const RenderState& state, const shader& s) override {
        return state.needShaderClipRect
            ? s.font_outline_cr
            : s.font_outline
            ;
    }
protected:
    ColorUniform color_uniform;
};

class TextShadowMaterial: public TextMaterial {
public:
    TextShadowMaterial(const shader& s, struct font_manager* F, uint16_t texid, int8_t edgeValueOffset, Rml::Color color, Rml::Point offset)
        : TextMaterial(s, F, texid, edgeValueOffset)
        , color_uniform(s.find_uniform("u_effect_color"), color)
        , offset_uniform(s.find_uniform("u_shadow_offset"))
        , offset(offset)
    {}
    void Submit(bgfx_encoder_t* encoder) override {
        TextMaterial::Submit(encoder);
        color_uniform.Submit(encoder);
        offset_uniform.Submit(encoder, offset.x / FONT_MANAGER_TEXSIZE, offset.y / FONT_MANAGER_TEXSIZE);
    }
    uint16_t Program(const RenderState& state, const shader& s) override {
        return state.needShaderClipRect
            ? s.font_shadow_cr
            : s.font_shadow
            ;
    }
protected:
    ColorUniform color_uniform;
    Uniform offset_uniform;
    Rml::Point offset;
};

Renderer::Renderer(const RmlContext* context)
    : mcontext(context)
    , mEncoder(nullptr)
    , default_tex_mat(std::make_unique<TextureMaterial>(
        mcontext->shader,
        uint16_t(mcontext->default_tex.texid),
        Rml::SamplerFlag::Unset
    ))
    , default_font_mat(std::make_unique<TextMaterial>(
        mcontext->shader,
        mcontext->font_mgr,
        mcontext->font_tex.texid
    ))
    , clip_uniform(std::make_unique<Uniform>(
        mcontext->shader.find_uniform("u_clip_rect")
    ))
{
    BGFX(set_view_mode)(mcontext->viewid, BGFX_VIEW_MODE_SEQUENTIAL);
}

Renderer::~Renderer()
{}

void Renderer::RenderGeometry(Rml::Vertex* vertices, size_t num_vertices, Rml::Index* indices, size_t num_indices, Rml::MaterialHandle mat) {
    BGFX(encoder_set_state)(mEncoder, RENDER_STATE, 0);
    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, (uint32_t)num_vertices, (bgfx_vertex_layout_t*)mcontext->layout);

    memcpy(tvb.data, vertices, num_vertices * sizeof(Rml::Vertex));
    BGFX(encoder_set_transient_vertex_buffer)(mEncoder, 0, &tvb, 0, (uint32_t)num_vertices);

    bgfx_transient_index_buffer_t tib;
    BGFX(alloc_transient_index_buffer)(&tib, (uint32_t)num_indices, true);

    static_assert(sizeof(Rml::Index) == sizeof(uint32_t));
    memcpy(tib.data, indices, num_indices * sizeof(Rml::Index));
    BGFX(encoder_set_transient_index_buffer)(mEncoder, &tib, 0, (uint32_t)num_indices);

    submitScissorRect(mEncoder);

    Material* material = mat
        ? reinterpret_cast<Material*>(mat)
        : default_tex_mat.get()
        ;
    material->Submit(mEncoder);

    auto prog = material->Program(state, mcontext->shader);
    const uint8_t discard_flags = ~BGFX_DISCARD_TRANSFORM;
    BGFX(encoder_submit)(mEncoder, mcontext->viewid, { prog }, 0, discard_flags);
}

void Renderer::Begin() {
    mEncoder = BGFX(encoder_begin)(false);
    assert(mEncoder);
}

void Renderer::End() {
    BGFX(encoder_end)(mEncoder);
}

#ifdef _DEBUG
void Renderer::drawDebugScissorRect(bgfx_encoder_t *encoder, uint16_t viewid, uint16_t progid){
    if (!state.needShaderClipRect)
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

    memcpy(tvb.data, &state.rectVerteices, sizeof(glm::vec2)*4);
    BGFX(encoder_set_transient_vertex_buffer)(encoder, 0, &tvb, 0, 4);

    bgfx_transient_index_buffer_t tib;
    BGFX(alloc_transient_index_buffer)(&tib, 6, false);

    const uint16_t indices[] = {0, 1, 2, 1, 3, 2};
    BGFX(encoder_set_transient_index_buffer)(encoder, &tib, 0, 6);

    BGFX(encoder_set_state)(encoder, RENDER_STATE, 0);

    BGFX(encoder_submit)(encoder, viewid, {progid}, 0, BGFX_DISCARD_ALL);
}
#endif //_DEBUG

void Renderer::setShaderScissorRect(bgfx_encoder_t* encoder, const glm::vec4 r[2]){
    state.needShaderClipRect = true;
    state.lastScissorId = UINT16_MAX;
    state.rectVerteices[0] = r[0];
    state.rectVerteices[1] = r[1];
    BGFX(encoder_set_scissor_cached)(encoder, UINT16_MAX);
}

void Renderer::setScissorRect(bgfx_encoder_t* encoder, const glm::u16vec4 *r) {
    state.needShaderClipRect = false;
    if (r == nullptr){
        state.lastScissorId = UINT16_MAX;
        BGFX(encoder_set_scissor_cached)(encoder, UINT16_MAX);
    } else {
        state.lastScissorId = BGFX(encoder_set_scissor)(encoder, r->x, r->y, r->z, r->w);
    }
}

void Renderer::submitScissorRect(bgfx_encoder_t* encoder){
    if (state.needShaderClipRect) {
        clip_uniform->Submit(encoder, state.rectVerteices);
    } else {
        BGFX(encoder_set_scissor_cached)(encoder, state.lastScissorId);
    }
}

void Renderer::SetTransform(const glm::mat4x4& transform) {
    BGFX(encoder_set_transform)(mEncoder, &transform, 1);
}

void Renderer::SetClipRect() {
    setScissorRect(mEncoder, nullptr);
}

void Renderer::SetClipRect(const glm::u16vec4& r) {
    setScissorRect(mEncoder, &r);
}

void Renderer::SetClipRect(glm::vec4 r[2]) {
    setShaderScissorRect(mEncoder, r);
}

bool Renderer::LoadTexture(Rml::TextureHandle& handle, Rml::Size& dimensions, const std::string& path){
    Rml::FileInterface* ifile = Rml::GetFileInterface();
	Rml::FileHandle fh = ifile->Open(path);
	if (!fh)
		return false;
	
	const size_t bufsize = ifile->Length(fh);
	
    const bgfx_memory_t *mem = BGFX(alloc)((uint32_t)bufsize);
	ifile->Read(mem->data, bufsize, fh);
	ifile->Close(fh);

	bgfx_texture_info_t info;
    const uint64_t flags = BGFX_TEXTURE_SRGB;
	const bgfx_texture_handle_t th = BGFX(create_texture)(mem, flags, 1, &info);
	if (th.idx != UINT16_MAX){
		dimensions.w = info.width;
		dimensions.h = info.height;
        handle = th.idx;
        return true;
	}
	return false;
}

bool Renderer::UpdateTexture(Rml::TextureHandle texture, uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t *buffer){
    bgfx_texture_handle_t th = { uint16_t(texture) };
    if (!BGFX_HANDLE_IS_VALID(th))
        return false;
    const uint32_t bytes = (uint32_t)w * h;
    auto mem = BGFX(make_ref)(buffer, bytes);
    BGFX(update_texture_2d)(th, 0, 0, x, y, w, h, mem, w);
    return true;
}

void Renderer::ReleaseTexture(Rml::TextureHandle texture) {
    bgfx_texture_handle_t th = { uint16_t(texture) };
    if (!BGFX_HANDLE_IS_VALID(th)) {
        BGFX(destroy_texture)(th);
    }
}

Rml::MaterialHandle Renderer::CreateTextureMaterial(Rml::TextureHandle texture, Rml::SamplerFlag flags) {
    bgfx_texture_handle_t th = { uint16_t(texture) };
    if (!BGFX_HANDLE_IS_VALID(th)) {
        th = { uint16_t(mcontext->default_tex.texid) };
    }
    auto material = std::make_unique<TextureMaterial>(mcontext->shader, th.idx, flags);
    return reinterpret_cast<Rml::MaterialHandle>(material.release());
}

struct TextEffectVisitor {
    const RmlContext* context;
    Rml::MaterialHandle operator() (Rml::TextStroke const& t) {
        font_manager* F = context->font_mgr;
        int8_t edgevalueOffset = int8_t(F->font_manager_sdf_mask(F) * 0.85f);
        auto material = std::make_unique<TextStrokeMaterial>(
            context->shader,
            F,
            context->font_tex.texid,
            edgevalueOffset,
            t.color,
            t.width
        );
        return reinterpret_cast<Rml::MaterialHandle>(material.release());
    }
    Rml::MaterialHandle operator() (Rml::TextShadow const& t) {
        font_manager* F = context->font_mgr;
        int8_t edgevalueOffset = int8_t(F->font_manager_sdf_mask(F) * 0.85f);
        auto material = std::make_unique<TextShadowMaterial>(
            context->shader,
            F,
            context->font_tex.texid,
            edgevalueOffset,
            t.color,
            Rml::Point(t.offset_h, t.offset_v)
        );
        return reinterpret_cast<Rml::MaterialHandle>(material.release());
    }
};

Rml::MaterialHandle Renderer::CreateFontMaterial(const Rml::TextEffects& effects) {
    if (effects.empty()) {
        return reinterpret_cast<Rml::MaterialHandle>(default_font_mat.get());
    }
    if (effects.size() != 1){
        assert(false && "not support more than one font effect in single text");
        return reinterpret_cast<Rml::MaterialHandle>(default_font_mat.get());
    }
    return std::visit(TextEffectVisitor{mcontext}, effects[0]);
}

void Renderer::DestroyMaterial(Rml::MaterialHandle mat) {
    Material* material = reinterpret_cast<Material*>(mat);
    if (default_font_mat.get() != material) {
        delete material;
    }
}
