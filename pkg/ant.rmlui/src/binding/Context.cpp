#include <binding/Context.h>
#include <binding/ContextImpl.h>
#include <binding/RenderImpl.h>
#include <binding/ScriptImpl.h>
#include <css/StyleSheetSpecification.h>
#include <core/Texture.h>

namespace Rml {

struct ContextImpl {
    Rml::RenderImpl m_render;
    Rml::ScriptImpl m_script;
    ContextImpl(lua_State* L, int idx)
        : m_render(L, idx)
        , m_script(L)
    {}
};

static ContextImpl* g_context = nullptr;

bool Initialise(lua_State* L, int idx) {
    if (g_context) {
        return false;
    }
    g_context = new ContextImpl(L, idx);
    StyleSheetSpecification::Initialise();
    return true;
}

void Shutdown() {
    StyleSheetSpecification::Shutdown();
    Texture::Shutdown();
    if (g_context) {
        delete g_context;
        g_context = nullptr;
    }
}

Render* GetRender() {
    return &g_context->m_render;
}

Script* GetScript() {
    return &g_context->m_script;
}

}
