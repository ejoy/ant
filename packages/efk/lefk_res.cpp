

#include "efk_fileinterface.h"

#include <Effekseer/Effekseer.h>
#include <Effekseer/Effekseer.DefaultEffectLoader.h>

#include <lua.hpp>

#include <cassert>
#include <cstring>

#include <string_view>

struct res_ctx{
    res_ctx() = default;
    ~res_ctx() = default;

    Effekseer::ManagerRef manager;
    struct file_interface *fi;
};

static inline void
normalize_path(std::string &u8_p){
    if (u8_p.back() != '/' || u8_p.back() != '\\')
        u8_p += '/';

    for (auto &c : u8_p){
        if (c == '\\')
            c = '/';
    }
}

static inline std::string_view
parent_path(const std::string &p){
    auto pos = p.rfind('/');
    if (pos != std::string::npos)
        return std::string_view(p.cbegin(), p.cbegin() + (pos-1));
    return std::string_view();
}

static inline std::string
join_path(const std::string_view &p, const char* pp){
    return std::string(p) + pp;
}

static inline std::string
join_path(const std::string_view &p, const char16_t* pp){
    char u8[256];
    Effekseer::ConvertUtf16ToUtf8(u8, 256, pp);
    return join_path(p, u8);
}

using ResourceList = std::vector<std::string>;
class EmptyEffectFactory : public Effekseer::EffectFactory {
public:
    EmptyEffectFactory() = default;
    ~EmptyEffectFactory() = default;

protected:
    void OnLoadingResource(Effekseer::Effect* effect, const void* data, int32_t size, const char16_t* materialPath){}

private:
};

static inline struct res_ctx*
RC(lua_State *L, int index){
    return (struct res_ctx*)luaL_checkudata(L, index, "EFKRES_CTX");
}

static int
lresctx_list(lua_State *L){
    auto ctx = RC(L, 1);

    auto filename = luaL_checkstring(L, 2);
    const float mag = (float)luaL_optnumber(L, 3, 1.f);
    char16_t u16_filename[1024];
    Effekseer::ConvertUtf8ToUtf16(u16_filename, 1024, filename);
    auto eff = Effekseer::Effect::Create(ctx->manager, u16_filename, mag);

    auto parent = parent_path(filename);

    std::vector<std::string>    paths;

    for (int ii=0; ii<eff->GetColorImageCount(); ++ii){
        paths.emplace_back(join_path(parent, eff->GetColorImagePath(ii)));
    }

    for (int ii=0; ii<eff->GetNormalImageCount(); ++ii){
        paths.emplace_back(join_path(parent, eff->GetNormalImagePath(ii)));
    }

    for (int ii=0; ii<eff->GetDistortionImageCount(); ++ii){
        paths.emplace_back(join_path(parent, eff->GetDistortionImagePath(ii)));
    }

    eff = nullptr;

    lua_createtable(L, (int)paths.size(), 0);
    for (int ii=0; ii<paths.size(); ++ii){
        lua_pushstring(L, paths[ii].c_str());
        lua_seti(L, -2, ii+1);
    }
    return 1;
}

static int
lefkres_new(lua_State *L){
    auto ctx = (struct res_ctx*)lua_newuserdatauv(L, sizeof(res_ctx), 0);
    new (ctx)res_ctx();
    if (luaL_newmetatable(L, "EFKRES_CTX")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"list", lresctx_list},
            {nullptr, nullptr},
        };

        luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);

    ctx->manager = Effekseer::Manager::Create(1);
    auto s = ctx->manager->GetSetting();
    s->ClearEffectFactory();
    s->AddEffectFactory(Effekseer::MakeRefPtr<EmptyEffectFactory>());

    struct file_interface *fi = nullptr;
    ctx->manager->SetEffectLoader(Effekseer::MakeRefPtr<Effekseer::DefaultEffectLoader>(
        Effekseer::MakeRefPtr<EfkFileInterface>(fi)));
    return 1;
}

static int
lefkres_shutdown(lua_State *L){
    auto ctx = RC(L, 1);
    ctx->manager.Reset();
    ctx->~res_ctx();
    return 0;
}

extern "C" int
luaopen_efk_resource(lua_State* L) {
    luaL_Reg l[] = {
        { "new",        lefkres_new},
        { "shutdown",   lefkres_shutdown},
        { nullptr,      nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
