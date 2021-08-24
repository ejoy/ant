//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "Textures.h"

namespace Graphics
{
// Utility function to map a XY + Side coordinate to a direction vector
glm::vec3 MapXYSToDirection(uint64_t x, uint64_t y, uint64_t s, uint64_t width, uint64_t height)
{
    float u = ((x + 0.5f) / float(width)) * 2.0f - 1.0f;
    float v = ((y + 0.5f) / float(height)) * 2.0f - 1.0f;
    v *= -1.0f;

    glm::vec3 dir(0.0f);

    // +x, -x, +y, -y, +z, -z
    switch(s) {
    case 0:
        dir = glm::normalize(glm::vec3(1.0f, v, -u));
        break;
    case 1:
        dir = glm::normalize(glm::vec3(-1.0f, v, u));
        break;
    case 2:
        dir = glm::normalize(glm::vec3(u, 1.0f, -v));
        break;
    case 3:
        dir = glm::normalize(glm::vec3(u, -1.0f, v));
        break;
    case 4:
        dir = glm::normalize(glm::vec3(u, v, 1.0f));
        break;
    case 5:
        dir = glm::normalize(glm::vec3(-u, v, -1.0f));
        break;
    }

    return dir;
}

}