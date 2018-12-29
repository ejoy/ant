#include <lua.hpp>
#include <filesystem>
#include "path_helper.h"
#include "unicode.h"
#include "range.h"
#include "binding.h"

namespace fs = std::filesystem;

namespace ant::lua_filesystem {
    namespace path {
        class directory_container {
        public:
            directory_container(fs::path const& o) : p(o) { }
            fs::directory_iterator begin() const { return fs::directory_iterator(p); }
            fs::directory_iterator end()   const { return fs::directory_iterator(); }
        private:
            const fs::path& p;
        };

        static void* newudata(lua_State* L);

        static fs::path& to(lua_State* L, int idx)
        {
            return *(fs::path*)getObject(L, idx, "filesystem");
        }

        static int constructor_(lua_State* L)
        {
            void* storage = newudata(L);
            new (storage)fs::path();
            return 1;
        }

        static int constructor_(lua_State* L, fs::path::string_type&& path)
        {
            void* storage = newudata(L);
            new (storage)fs::path(std::forward<fs::path::string_type>(path));
            return 1;
        }

        static int constructor_(lua_State* L, const fs::path& path)
        {
            void* storage = newudata(L);
            new (storage)fs::path(path);
            return 1;
        }

        static int constructor_(lua_State* L, fs::path&& path)
        {
            void* storage = newudata(L);
            new (storage)fs::path(std::forward<fs::path>(path));
            return 1;
        }

        static int constructor(lua_State* L)
        {
            LUA_TRY;
            if (lua_gettop(L) == 0) {
                return constructor_(L);
            }
            switch (lua_type(L, 1)) {
            case LUA_TSTRING:
                return constructor_(L, lua::to_string(L, 1));
            case LUA_TUSERDATA:
                return constructor_(L, to(L, 1));
            }
            luaL_checktype(L, 1, LUA_TSTRING);
            return 0;
            LUA_TRY_END;
        }

        static int filename(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.filename());
            LUA_TRY_END;
        }

        static int parent_path(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.parent_path());
            LUA_TRY_END;
        }

        static int stem(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.stem());
            LUA_TRY_END;
        }

        static int extension(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.extension());
            LUA_TRY_END;
        }

        static int is_absolute(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            lua_pushboolean(L, self.is_absolute());
            return 1;
            LUA_TRY_END;
        }

        static int is_relative(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            lua_pushboolean(L, self.is_relative());
            return 1;
            LUA_TRY_END;
        }

        static int remove_filename(lua_State* L)
        {
            LUA_TRY;
            fs::path& self = path::to(L, 1);
            self.remove_filename();
            return 1;
            LUA_TRY_END;
        }

        static int replace_extension(lua_State* L)
        {
            LUA_TRY;
            fs::path& self = path::to(L, 1);
            switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                self.replace_extension(lua::to_string(L, 2));
                lua_settop(L, 1);
                return 1;
            case LUA_TUSERDATA:
                self.replace_extension(to(L, 2));
                lua_settop(L, 1);
                return 1;
            }
            luaL_checktype(L, 2, LUA_TSTRING);
            return 0;
            LUA_TRY_END;
        }

        static int list_directory(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);  
            lua::make_range(L, directory_container(self));
            lua_pushnil(L);
            lua_pushnil(L);
            return 3;
            LUA_TRY_END;
        }

        static int permissions(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            lua_pushinteger(L, lua_Integer(fs::status(self).permissions()));
            return 1;
            LUA_TRY_END;
        }

        static int add_permissions(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            fs::perms perms = fs::perms::mask & fs::perms(luaL_checkinteger(L, 2));
            fs::permissions(self, perms, fs::perm_options::add);
            return 0;
            LUA_TRY_END;
        }

        static int remove_permissions(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            fs::perms perms = fs::perms::mask & fs::perms(luaL_checkinteger(L, 2));
            fs::permissions(self, perms, fs::perm_options::remove);
            return 0;
            LUA_TRY_END;
        }

        static int mt_div(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                return constructor_(L, self / lua::to_string(L, 2));
            case LUA_TUSERDATA:
                return constructor_(L, self / to(L, 2));
            }
            luaL_checktype(L, 2, LUA_TSTRING);
            return 0;
            LUA_TRY_END;
        }

        static int mt_eq(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            const fs::path& rht = path::to(L, 2);
            lua_pushboolean(L, path_helper::equal(self, rht));
            return 1;
            LUA_TRY_END;
        }

        static int destructor(lua_State* L)
        {
            LUA_TRY;
            fs::path& self = path::to(L, 1);
            self.~path();
            return 0;
            LUA_TRY_END;
        }

        static int mt_tostring(lua_State* L)
        {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            auto res = self.generic_u8string();
            lua_pushlstring(L, res.data(), res.size());
            return 1;
            LUA_TRY_END;
        }

        static void* newudata(lua_State* L) {
            void* storage = lua_newuserdata(L, sizeof(fs::path));
            if (newObject(L, "filesystem")) {
                static luaL_Reg mt[] = {
                    { "string", path::mt_tostring },
                    { "filename", path::filename },
                    { "parent_path", path::parent_path },
                    { "stem", path::stem },
                    { "extension", path::extension },
                    { "is_absolute", path::is_absolute },
                    { "is_relative", path::is_relative },
                    { "remove_filename", path::remove_filename },
                    { "replace_extension", path::replace_extension },
                    { "list_directory", path::list_directory },
                    { "permissions", path::permissions },
                    { "add_permissions", path::add_permissions },
                    { "remove_permissions", path::remove_permissions },
                    { "__div", path::mt_div },
                    { "__eq", path::mt_eq },
                    { "__gc", path::destructor },
                    { "__tostring", path::mt_tostring },
                    { "__debugger_tostring", path::mt_tostring },
                    { NULL, NULL }
                };
                luaL_setfuncs(L, mt, 0);
                lua_pushvalue(L, -1);
                lua_setfield(L, -2, "__index");
            }
            lua_setmetatable(L, -2);
            return storage;
        }
    }

    static int exists(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::exists(p));
        return 1; 
        LUA_TRY_END;
    }

    static int is_directory(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::is_directory(p));
        return 1;
        LUA_TRY_END;
    }

    static int is_regular_file(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::is_regular_file(p));
        return 1;
        LUA_TRY_END;
    }

    static int create_directory(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::create_directory(p));
        return 1;
        LUA_TRY_END;
    }

    static int create_directories(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::create_directories(p));
        return 1;
        LUA_TRY_END;
    }

    static int rename(lua_State* L)
    {
        LUA_TRY;
        const fs::path& from = path::to(L, 1);
        const fs::path& to = path::to(L, 2);
        fs::rename(from, to);
        return 0;
        LUA_TRY_END;
    }

    static int remove(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::remove(p));
        return 1;
        LUA_TRY_END;
    }

    static int remove_all(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushinteger(L, fs::remove_all(p));
        return 1;
        LUA_TRY_END;
    }

    static int current_path(lua_State* L)
    {
        LUA_TRY;
        if (lua_gettop(L) == 0) {
            return path::constructor_(L, fs::current_path());
        }
        const fs::path& p = path::to(L, 1);
        fs::current_path(p);
        return 0;
        LUA_TRY_END;
    }

    static int copy_file(lua_State* L)
    {
        LUA_TRY;
        const fs::path& from = path::to(L, 1);
        const fs::path& to = path::to(L, 2);
        bool overwritten = !!lua_toboolean(L, 3);
        fs::copy_file(from, to, overwritten ? fs::copy_options::overwrite_existing : fs::copy_options::none);
        return 0;
        LUA_TRY_END;
    }

    static int absolute(lua_State* L)
    {
#if defined(_WIN32)
#define FS_ABSOLUTE(path) fs::absolute(path)
#else
#define FS_ABSOLUTE(path) fs::absolute(path).lexically_normal()
#endif
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        if (lua_gettop(L) == 1) {
            return path::constructor_(L, FS_ABSOLUTE(p));
        }
        const fs::path& base = path::to(L, 2);
        return path::constructor_(L, FS_ABSOLUTE(base / p));
        LUA_TRY_END;
    }

    static int relative(lua_State* L)
    {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        const fs::path& base = path::to(L, 2);
        return path::constructor_(L, fs::relative(p, base));
        LUA_TRY_END;
    }

    static int last_write_time(lua_State* L)
    {
        // TODO: need file_clock http://wg21.link/p0355r7
        using namespace std::chrono;
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        if (lua_gettop(L) == 1) {
            fs::file_time_type time = fs::last_write_time(p);
            auto system_time = system_clock::now() + duration_cast<seconds>(time - fs::file_time_type::clock::now());
            lua_pushinteger(L, duration_cast<seconds>(system_time.time_since_epoch()).count());
            return 1;
        }
        auto system_duration = system_clock::time_point() + seconds(luaL_checkinteger(L, 2)) - system_clock::now();
        fs::last_write_time(p, fs::file_time_type::clock::now() + duration_cast<fs::file_time_type::duration>(system_duration));
        return 0;
        LUA_TRY_END;
    }

    static int exe_path(lua_State* L)
    {
        LUA_TRY;
        return path::constructor_(L, std::move(path_helper::exe_path().value()));
        LUA_TRY_END;
    }

    static int dll_path(lua_State* L)
    {
        LUA_TRY;
        return path::constructor_(L, std::move(path_helper::dll_path().value()));
        LUA_TRY_END;
    }
    
    int luaopen(lua_State* L) {
        static luaL_Reg lib[] = {
            { "path", path::constructor },
            { "exists", exists },
            { "is_directory", is_directory },
            { "is_regular_file", is_regular_file },
            { "create_directory", create_directory },
            { "create_directories", create_directories },
            { "rename", rename },
            { "remove", remove },
            { "remove_all", remove_all },
            { "current_path", current_path },
            { "copy_file", copy_file },
            { "absolute", absolute },
            { "relative", relative },
            { "last_write_time", last_write_time },
            { "exe_path", exe_path },
            { "dll_path", dll_path },
            { NULL, NULL }
        };
        luaL_newlib(L, lib);
        return 1;
    }
}

namespace ant::lua {
    template <>
    int convert_to_lua(lua_State* L, const fs::directory_entry& v) {
        lua_filesystem::path::constructor_(L, v.path());
        return 1;
    }
}

ANT_LUA_API
int luaopen_filesystem_cpp(lua_State* L) {
    return ant::lua_filesystem::luaopen(L);
}
