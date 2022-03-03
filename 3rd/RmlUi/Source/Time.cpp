#include "../Include/RmlUi/Time.h"

namespace Rml::Time {
    double elapsedTime = 0.;
    void Update(double delta) {
        elapsedTime += delta;
    }
    double Now() {
        return elapsedTime / 1000;
    }
}
