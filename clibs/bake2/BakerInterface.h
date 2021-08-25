//use for exprot interface
#pragma once

typedef void* BakerHandle;

#include <cstdint>
#include <vector>
#include <string>
#include "glm/glm.hpp"

enum LightType {
    LT_Directional,
    LT_PointLight,
    LT_AreaLight,
};

struct Light {
    glm::vec3 dir;
    glm::vec3 color;
    glm::vec3 pos;
    float size;
    uint8_t type;
};

struct MaterialData{
    std::string diffuseTex;
    std::string normalTex;
    std::string metallicRoughnessTex;
};

struct ModelData {
    struct MeshData {
        struct BufferData{
            const uint8_t* data;
            uint32_t stride;
            uint8_t type;
        };
        BufferData positions;
        BufferData normals;
        BufferData tangents;
        BufferData bitangents;
        BufferData indices;

        uint32_t materialidx;
    };

    std::vector<MeshData>       meshes;
    std::vector<MaterialData>   materials;
};

struct Scene {
    std::vector<Light>  lights;
    std::vector<ModelData>  models;
};

struct BakeResult {
    struct Lightmap{
        std::vector<uint8_t> data;
        uint16_t size;
        uint16_t texelsize;
    };

    Lightmap lm;
};

extern BakerHandle CreateBaker(const Scene* scene);
extern void Bake(BakerHandle handle, BakeResult *result);
extern void DestoryBaker(BakerHandle handle);