//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include <PCH.h>

#include <InterfacePointers.h>
#include <Input.h>
#include <Graphics/Model.h>
#include <Graphics/GraphicsTypes.h>
#include <Graphics/DeviceManager.h>
#include "../v1.02/Window.h"
#include "MeshBaker.h"
#include "Light.h"

using namespace SampleFramework11;

struct Scene;

class Baker
{

protected:
    Window window;
    DeviceManager deviceManager;
    // Model
    Model sceneModel;
    MeshBaker meshBaker;

    MeshBakerStatus meshbakerStatus;

public:
    Baker();

    void Init(const Scene *s);
    static void InitLights(const Scene *s, Lights &lights);
    const Model& GetModel() const {
        return sceneModel;
    }

    Model& GetModel(uint32 mode){ return sceneModel;}
    void MeshbakerInitialize(const Model *model, Lights &&lights);
    void Bake(uint32 bakeMeshIdx);
    float BakeProcess(uint32 bakeMeshIdx);
    void ShutDown();

    const FixedArray<Float4>& GetBakeResult(uint64 basicIdx) const;
};
