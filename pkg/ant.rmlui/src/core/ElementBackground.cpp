#include <core/ElementBackground.h>

namespace Rml {
    void ElementBackground::Render() {
        if (background && *background) {
            background->Render();
        }
        if (image && *image) {
            image->Render();
        }
    }
    
    void ElementBackground::Update(Element* element) {
        if (!background) {
            background.reset(new Geometry);
        }
        else {
            background->Release();
        }
        if (!image) {
            image.reset(new Geometry);
        }
        else {
            image->Release();
        }
        Box edge;
        GenerateBorderGeometry(element, *background, edge);
        if (!GenerateImageGeometry(element, *image, edge)) {
            image.reset();
        }
    }
}
