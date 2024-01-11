#pragma once

#include <css/StyleCache.h>

namespace Rml {
    class StyleSheetDefaultValue {
    public:
        static void Initialise();
        static void Shutdown();
        static const Style::TableRef& Get();
    };
}
