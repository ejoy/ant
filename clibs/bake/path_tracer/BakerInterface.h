//use for exprot interface
#pragma once

typedef void* BakerHandle;

#include <cstdint>
#include <vector>
#include <string>
#include "glm/glm.hpp"
#include "glm/gtx/quaternion.hpp"

struct Light {
    glm::vec3 pos;
    glm::vec3 dir;

    glm::vec3 color;
    float intensity;

    float range;
    float inner_cutoff;
    float outter_cutoff;
    float angular_radius;
    enum LightType {
        LT_Directional = 0,
        LT_Point,
        LT_Spot,
        LT_Area,
    };
    LightType type;
};

struct MaterialData{
    std::string diffuse;
    std::string normal;
    std::string roughness;
    std::string metallic;
};

enum BufferType {
    BT_None = 0,
    BT_Byte,
    BT_Uint16,
    BT_Uint32,
    BT_Float,
};

struct BufferData{
    const char* data;
    uint32_t offset;
    uint32_t stride;
    BufferType type;
};

struct Lightmap {
    uint16_t size;
};

struct MeshData {
    glm::mat4 worldmat;
    glm::mat4 normalmat;

    BufferData positions;
    BufferData normals;
    BufferData tangents;
    BufferData bitangents;
    BufferData texcoords0;
    BufferData texcoords1;
    BufferData indices;

    uint32_t vertexCount;
    uint32_t indexCount;
    uint32_t materialidx;

    Lightmap    lightmap;
};

struct Sky{
    enum SkyType{
        SimpleColor = 0,
        CubeMap = 1,
    };
    SkyType     type;
    std::string cubemapTexture;
    glm::vec3   skyColor;
};

struct Scene {
    std::vector<Light>          lights;
    std::vector<MeshData>       models;
    std::vector<MaterialData>   materials;

    Sky sky;
};

struct LightmapResult{
    std::vector<glm::vec4>   data;
    uint16_t size;
};

struct BakeResult {
    std::vector<LightmapResult> lightmaps;
};

extern BakerHandle CreateBaker(const Scene* scene);
extern void Bake(BakerHandle handle, BakeResult *result);
extern void DestroyBaker(BakerHandle handle);