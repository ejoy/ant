#include "texture.h"

//static
const OutlineData* OutlineData::ToOutlineData(Rml::TextureHandle th){
    const auto td = ToTexData(th);
    const auto flags = td->GetTextFlags();
    if (flags & TDF_FontEffect_Outline){
        return static_cast<const OutlineData*>(td);
    }

    return nullptr;
}