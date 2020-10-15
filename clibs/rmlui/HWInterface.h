#include <RmlUi/Core/Types.h>
#include <cstdint>


class Renderer;
// Same as BGFX
enum SamplerFlag : uint32_t {
    U_MIRROR        = 0x00000001,
    U_CLAMP         = 0x00000002,
    U_BORDER        = 0x00000003,
    U_SHIFT         = 0,
    U_MASK          = 0x00000003,

    V_MIRROR        = 0x00000004,
    V_CLAMP         = 0x00000008,
    V_BORDER        = 0x0000000c,
    V_SHIFT         = 2,
    V_MASK          = 0x0000000c,

    MIN_POINT       = 0x00000040,
    MIN_ANISOTROPIC = 0x00000080,
    MIN_SHIFT       = 6,
    MIN_MASK        = 0x000000c0,

    MAG_POINT       = 0x00000100,
    MAG_ANISOTROPIC = 0x00000200,
    MAG_SHIFT       = 8,
    MAG_MASK        = 0x00000300,

    MIP_POINT       = 0x00000400,
    MIP_SHIFT       = 10,
    MIP_MASK        = 0x00000400,
};

struct ShaderInfo{
    uint16_t prog;
    uint16_t tex_uniform_idx;
};

struct ShaderContext{
    ShaderInfo font;
    ShaderInfo image;
    uint16_t font_texid;
};

class HWInterface{
public:
    HWInterface(uint16_t viewid, uint16_t layoutid);
    uint16_t CreateTexture(const uint8_t *data, uint32_t numbytes, SamplerFlag flags, int *w, int *h);
    uint16_t CreateTexture2D(int w, int h, SamplerFlag flags, const uint8_t *data, uint32_t numbytes);
    void DestroyTexture(uint16_t texid);

    void Render(Rml::Vertex* vertices, int num_vertices, 
                int* indices, int num_indices, 
                Rml::TextureHandle texture, const Rml::Vector2f& translation);
    ShaderContext& GetShaderContext() { return mShaderContext;}
private:
    uint16_t mViewId;
    uint16_t mVertexLayoutId;
    uint64_t mRenderState;
    ShaderContext mShaderContext;
};