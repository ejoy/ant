#include "glm/glm.hpp"
#include "glm/gtx/quaternion.hpp"
#include "glm/gtx/euler_angles.hpp"

int main(int argc, char **argv){
    glm::mat4 m(
        1.f, 0.f, 0.f, 0.f,
        0.f, 1.f, 0.f, 0.f,
        0.f, 0.f,-1.f, 0.f,
        0.f, 0.f, 0.f, 1.f
    );

    glm::quat q(glm::radians(glm::vec3(45.f, 0.f, 0.f)));

    glm::mat4 mm(q);
    
    auto mmm = m * mm;
    glm::quat qq(mmm);
    
    return 0;
}