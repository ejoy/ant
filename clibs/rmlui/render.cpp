#include "render.h"
#include <RmlUi/Core.h>

void Renderer::RenderGeometry(Rml::Vertex* vertices, int num_vertices, 
                            int* indices, int num_indices, 
                            Rml::TextureHandle texture, const Rml::Vector2f& translation) {
    RenderBatch batch;
    batch.vb_start  = (uint32_t)mGeoBuffer.mvertices.size();
    batch.vb_num    = num_vertices;

    batch.ib_start  = (uint32_t)mGeoBuffer.mindices.size();
    batch.ib_num    = num_indices;
    
    batch.tex       = texture;
    batch.offset    = translation;

    mGeoBuffer.mvertices.resize(batch.vb_start + batch.vb_num);
    memcpy(&mGeoBuffer.mvertices[batch.vb_start], vertices, num_vertices * sizeof(Rml::Vertex));

    mGeoBuffer.mindices.resize(batch.ib_start + batch.ib_num);
    memcpy(&mGeoBuffer.mindices[batch.ib_start], indices, sizeof(int));
}

void Renderer::EnableScissorRegion(bool enable) {
    if (enable){
        mScissorRect.w = mScissorRect.h = 1;
    } else {
        mScissorRect.w = mScissorRect.h = 0;
    }
}

void Renderer::SetScissorRegion(int x, int y, int w, int h) {
    mScissorRect.x = x;
    mScissorRect.y = y;
    mScissorRect.w = w;
    mScissorRect.h = h;
}

static inline bool
CustomTexture(const Rml::String &key){
    return (!key.empty() && key[0] == '?');
}

bool Renderer::LoadTexture(Rml::TextureHandle& texture_handle, Rml::Vector2i& texture_dimensions, const Rml::String& source){
    if (CustomTexture(source)){
        auto found = mTexMap.find(source);
        if (found == mTexMap.end())
            return false;
        texture_dimensions = found->second.dim;
        texture_handle = static_cast<Rml::TextureHandle>(found->second.texid);
        return true;
    }
    Rml::FileInterface* ifile = Rml::GetFileInterface();
	Rml::FileHandle fh = ifile->Open(source);
	if (!fh)
		return false;
	
	ifile->Seek(fh, 0, SEEK_END);
	const size_t bufsize = ifile->Tell(fh);
	ifile->Seek(fh, 0, SEEK_SET);
	
    std::vector<uint8_t> buffer(bufsize);
    uint8_t *data = &buffer[0];
	ifile->Read(data, bufsize, fh);
	ifile->Close(fh);

    const uint16_t texid = mHWI.create_texture(data, (uint32_t)bufsize, "ulvl-c+c", true);
    if (texture_handle != uint16_t(-1)){
        mHWI.get_texture_dimension(texid, &texture_dimensions.x, &texture_dimensions.y);

        texture_handle = static_cast<Rml::TextureHandle>(texid);
        return true;
    }
    return false;
}

bool Renderer::GenerateTexture(Rml::TextureHandle& texture_handle, const Rml::byte* source, const Rml::Vector2i& source_dimensions) {
    //RGBA data
    const uint32_t bufsize = source_dimensions.x * source_dimensions.y * 4;
    texture_handle = static_cast<Rml::TextureHandle>(mHWI.create_texture(source, (uint32_t)bufsize, "ulvl-c+c", false));
    return texture_handle != uint16_t(-1);
}

void Renderer::ReleaseTexture(Rml::TextureHandle texture) {
    mHWI.destory_texture(static_cast<uint16_t>(texture));
}

void Renderer::Submit(){
    mGeoBuffer.Reset();
    mRenderBatches.reserve(mRenderBatches.size());
    mRenderBatches.resize(0);
}