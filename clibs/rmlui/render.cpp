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

bool Renderer::CalcScissorRectPlane(const glm::mat4 &transform, const Rect &rect, glm::vec4 planes[4]){
    /*
rect point:
      p0
    0 --- 1
 p3 |     | p1
    3 --- 2
      p2
    */
    glm::vec4 rectPoints[4] = {
        {rect.x, rect.y, 0.f, 1.f},
        {rect.x+rect.w, rect.y, 0.f, 1.f},
        {rect.x+rect.w, rect.y+rect.h, 0.f, 1.f},
        {rect.x, rect.y+rect.w, 0.f, 1.f},
    };

    // default normal
    planes[0] = glm::vec4(0.f, 1.f, 0.f, 0.f);
    planes[1] = glm::vec4(-1.f,0.f, 0.f, 0.f);
    planes[2] = glm::vec4(0.f,-1.f, 0.f, 0.f);
    planes[3] = glm::vec4(1.f, 1.f, 0.f, 0.f);

    for (int ii=0; ii<4; ++ii){
        rectPoints[ii]  = transform * rectPoints[ii];
        planes[ii]      = transform * planes[ii];
        const float dist= -glm::dot(rectPoints[ii], planes[ii]);
        planes[ii].w    = dist;
    }

    const bool isNormalRect = rectPoints[0].x == rectPoints[1].x;
    return isNormalRect;
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
    bool needDistancePlaneShader = false;
    glm::vec4 planes[4];
    if (mScissorRect.isVaild()){
        if (CalcScissorRectPlane(mTransform, mScissorRect, planes)){
            BGFX(encoder_set_scissor)(mEncoder, mScissorRect.x, mScissorRect.y, mScissorRect.w, mScissorRect.h);
        } else {
            needDistancePlaneShader = true;
        }
    } else {
        BGFX(encoder_set_scissor_cached)(mEncoder, UINT16_MAX);
    }

    auto submit_clip_planes_uniforms = [=](const shader_info &si){
        if (needDistancePlaneShader){
            auto uniformIdx = si.find_uniform("u_clip_planes");
            BGFX(encoder_set_uniform)(mEncoder, {uniformIdx}, planes, 4);
        }
    };

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
            case FontEffectType(FE_Outline|FE_FontTex): st = needDistancePlaneShader ? shader::ST_font_outline_cp : shader::ST_font_outline; break;
            case FontEffectType(FE_Shadow|FE_FontTex): st = needDistancePlaneShader ? shader::ST_font_shadow_cp : shader::ST_font_shadow; break;
            case FontEffectType(FE_None|FE_FontTex): st = needDistancePlaneShader ? shader::ST_font_cp : shader::ST_font; break;
            case FontEffectType::FE_None: st = needDistancePlaneShader ? shader::ST_image_cp : shader::ST_image; break;
            default: st = shader::ST_count;
            }
        } else {
            st = needDistancePlaneShader ? shader::ST_image_cp : shader::ST_image;
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
    submit_clip_planes_uniforms(si);
    BGFX(encoder_submit)(mEncoder,mcontext->viewid, { (uint16_t)si.prog }, 0, BGFX_DISCARD_ALL);
}

void Renderer::Begin(){
    mEncoder = BGFX(encoder_begin)(false);
}

void Renderer::Frame(){
    BGFX(encoder_end)(mEncoder);
    mIndexBuffer.Reset();
}

std::optional<glm::vec2> project(const glm::mat4x4& m, glm::vec2 pt) {
    glm::vec4 points_v4[2] = { { pt.x, pt.y, -10, 1}, { pt.x, pt.y, 10, 1 } };
    points_v4[0] = m * points_v4[0];
    points_v4[1] = m * points_v4[1];
    glm::vec3 points_v3[2] = {
        points_v4[0] / points_v4[0].w,
        points_v4[1] / points_v4[1].w
    };
    glm::vec3 ray = points_v3[1] - points_v3[0];
    if (std::fabs(ray.z) > 1.0f) {
        float t = -points_v3[0].z / ray.z;
        glm::vec3 p = points_v3[0] + ray * t;
        return glm::vec2(p.x, p.y);
    }
    return {};
}

void Renderer::SetScissorRegion(Rml::Rect const& clip) {
    if (clip.IsEmpty()) {
        mScissorRect.x = mScissorRect.y = mScissorRect.w = mScissorRect.h = 0;
    }
    else {
        auto leftTop = project(mTransform, { clip.left(), clip.top() });
        auto bottomRight = project(mTransform, { clip.right(), clip.bottom() });
        if (!leftTop || !bottomRight) {
            SetScissorRegion({});
        }
        else {
            mScissorRect.x = leftTop->x;
            mScissorRect.y = leftTop->y;
            mScissorRect.w = bottomRight->x - leftTop->x;
            mScissorRect.h = bottomRight->y - leftTop->y;
        }
    }
    //BGFX(encoder_set_scissor)(mcontext->viewid, std::max(x, 0), std::max(y, 0), w, h);
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