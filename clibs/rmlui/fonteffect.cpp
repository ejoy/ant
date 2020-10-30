#include "fonteffect.h"

Rml::FontEffectInstancer* FontEffectInstancerManager::Create(const Rml::String &name){
    auto it = mInstancers.find(name);
    if (it == mInstancers.end()){
        Rml::FontEffectInstancer *inst = nullptr;
        if (name == "outline"){
            inst = new SDFFontEffectOulineInstancer();
        }

        if (inst){
            mInstancers[name] = inst;
            return inst;
        }
    }
    return nullptr;
}