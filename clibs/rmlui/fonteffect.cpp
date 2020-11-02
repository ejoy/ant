#include "fonteffect.h"

Rml::FontEffectInstancer* FontEffectInstancerManager::Create(const Rml::String &name, const rml_context *c){
    auto it = mInstancers.find(name);
    if (it == mInstancers.end()){
        Rml::FontEffectInstancer *inst = nullptr;
        if (name == "outline"){
            inst = new SDFFontEffectOulineInstancer(c);
        }

        if (inst){
            mInstancers[name] = inst;
            return inst;
        }
    }
    return nullptr;
}