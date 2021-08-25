#include "BakerInterface.h"

#include "Meshbaker/BakingLab/BakingLab.h"

#include "Meshbaker/BakingLab/AppSettings.h"

static inline uint32_t _FindDirectionalLight(const Scene *scene){
    for (uint32_t idx=0; idx<scene->lights.size(); ++idx){
        auto l = scene->lights[idx];
        if (l.type == LT_Directional){
            return idx;
        }

        assert(false && "not support other light right now");
    }

    return UINT32_MAX;
}

BakerHandle CreateBaker(const Scene* scene){
    auto bl = new BakingLab();
    AppSettings::BakeMode.SetValue(BakeModes::Diffuse);

    auto lidx = _FindDirectionalLight(scene);
    if (lidx != UINT32_MAX){
        AppSettings::BakeDirectSunLight.SetValue(true);
        const auto& l = scene->lights[lidx];
        if (l.size != 0){
            AppSettings::SunSize.SetValue(l.size);
        }
        AppSettings::SunTintColor.SetValue(Float3(l.color.x, l.color.y, l.color.z));
        AppSettings::SunDirection.SetValue(Float3(l.dir.x, l.dir.y, l.dir.z));
    }

    AppSettings::BakeDirectAreaLight.SetValue(false);
    AppSettings::SkyMode.SetValue(SkyModes::Simple);

    bl->Init();
    return bl;
}

void Bake(BakerHandle handle, BakeResult *result){
    auto bl = (BakingLab*)handle;
    bl->Bake();
}

void DestroyBaker(BakerHandle handle){
    auto bl = (BakingLab*)handle;
    bl->ShutDown();

    delete bl;
}