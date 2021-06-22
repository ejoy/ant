#include <lua.hpp>
#include "filesystem.h"
#include "path_helper.h"
#include "file_helper.h"
#include "unicode.h"
#include "file.h"
#include "binding.h"
#include "error.h"

namespace ant::lua_filesystem {
    namespace path {
        static void* newudata(lua_State* L);

        static fs::path& to(lua_State* L, int idx) {
            return *(fs::path*)getObject(L, idx, "filesystem");
        }

        static int constructor_(lua_State* L) {
            void* storage = newudata(L);
            new (storage) fs::path();
            return 1;
        }

        static int constructor_(lua_State* L, fs::path::string_type&& path) {
            void* storage = newudata(L);
            new (storage) fs::path(std::forward<fs::path::string_type>(path));
            return 1;
        }

        static int constructor_(lua_State* L, const fs::path& path) {
            void* storage = newudata(L);
            new (storage) fs::path(path);
            return 1;
        }

        static int constructor_(lua_State* L, fs::path&& path) {
            void* storage = newudata(L);
            new (storage) fs::path(std::forward<fs::path>(path));
            return 1;
        }

        static int constructor(lua_State* L) {
            LUA_TRY;
            if (lua_gettop(L) == 0) {
                return constructor_(L);
            }
            switch (lua_type(L, 1)) {
            case LUA_TSTRING:
                return constructor_(L, lua::checkstring(L, 1));
            case LUA_TUSERDATA:
                return constructor_(L, to(L, 1));
            default:
                luaL_checktype(L, 1, LUA_TSTRING);
                return 0;
            }
            LUA_TRY_END;
        }

        static int filename(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.filename());
            LUA_TRY_END;
        }

        static int parent_path(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.parent_path());
            LUA_TRY_END;
        }

        static int stem(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.stem());
            LUA_TRY_END;
        }

        static int extension(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            return constructor_(L, self.extension());
            LUA_TRY_END;
        }

        static int is_absolute(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            lua_pushboolean(L, self.is_absolute());
            return 1;
            LUA_TRY_END;
        }

        static int is_relative(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            lua_pushboolean(L, self.is_relative());
            return 1;
            LUA_TRY_END;
        }

        static int remove_filename(lua_State* L) {
            LUA_TRY;
            fs::path& self = path::to(L, 1);
            self.remove_filename();
            return 1;
            LUA_TRY_END;
        }

        static int replace_extension(lua_State* L) {
            LUA_TRY;
            fs::path& self = path::to(L, 1);
            switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                self.replace_extension(lua::checkstring(L, 2));
                lua_settop(L, 1);
                return 1;
            case LUA_TUSERDATA:
                self.replace_extension(to(L, 2));
                lua_settop(L, 1);
                return 1;
            default:
                luaL_checktype(L, 2, LUA_TSTRING);
                return 0;
            }
            LUA_TRY_END;
        }

        static int equal_extension(lua_State* L, const fs::path& self, const fs::path::string_type& ext) {
            auto const& selfext = self.extension();
            if (selfext.empty()) {
                lua_pushboolean(L, ext.empty());
                return 1;
            }
            if (ext[0] != '.') {
                lua_pushboolean(L, path_helper::equal(selfext, fs::path::string_type{ '.' } + ext));
                return 1;
            }
            lua_pushboolean(L, path_helper::equal(selfext, ext));
            return 1;
        }

        static int equal_extension(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                return equal_extension(L, self, lua::checkstring(L, 2));
            case LUA_TUSERDATA:
                return equal_extension(L, self, to(L, 2));
            default:
                luaL_checktype(L, 2, LUA_TSTRING);
                return 0;
            }
            LUA_TRY_END;
        }

        template <typename T>
        struct pairs_directory {
            static pairs_directory& get(lua_State* L, int idx) {
                return *static_cast<pairs_directory*>(lua_touserdata(L, idx));
            }
            static int next(lua_State* L) {
                LUA_TRY;
                pairs_directory& self = get(L, lua_upvalueindex(1));
                if (self.cur == self.end) {
                    lua_pushnil(L);
                    return 1;
                }
                const int nreslut = path::constructor_(L, self.cur->path());
                ++self.cur;
                return nreslut;
                LUA_TRY_END;
            }
            static int close(lua_State* L) {
                pairs_directory& self = get(L, 1);
                self.cur = self.end;
                return 0;
            }
            static int gc(lua_State* L) {
                get(L, 1).~pairs_directory();
                return 0;
            }
            static int constructor(lua_State* L, const fs::path& path) {
                void* storage = lua_newuserdatauv(L, sizeof(pairs_directory), 0);
                new (storage) pairs_directory(path);
                if (newObject(L, "pairs_directory")) {
                    static luaL_Reg mt[] = {
                        {"__gc", pairs_directory::gc},
                        {"__close", pairs_directory::close},
                        {NULL, NULL},
                    };
                    luaL_setfuncs(L, mt, 0);
                }
                lua_setmetatable(L, -2);
                lua_pushvalue(L, -1);
                lua_pushcclosure(L, pairs_directory::next, 1);
                return 2;
            }
            pairs_directory(const fs::path& path)
                : cur(T(path))
                , end(T()) {}
            T cur;
            T end;
        };

        static int list_directory(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            const char* flags = luaL_optstring(L, 2, "");
            luaL_argcheck(L, (flags[0] == '\0' || (flags[0] == 'r' && flags[1] == '\0')), 2, "invalid flags");
            if (flags[0] == 'r') {
                pairs_directory<fs::recursive_directory_iterator>::constructor(L, self);
            }
            else {
                pairs_directory<fs::directory_iterator>::constructor(L, self);
            }
            lua_pushnil(L);
            lua_pushnil(L);
            lua_rotate(L, -4, -1);
            return 4;
            LUA_TRY_END;
        }

        static int permissions(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            lua_pushinteger(L, lua_Integer(fs::status(self).permissions()));
            return 1;
            LUA_TRY_END;
        }

        static int add_permissions(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            const fs::perms perms = fs::perms::mask & fs::perms(luaL_checkinteger(L, 2));
            fs::permissions(self, perms, fs::perm_options::add);
            return 0;
            LUA_TRY_END;
        }

        static int remove_permissions(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            const fs::perms perms = fs::perms::mask & fs::perms(luaL_checkinteger(L, 2));
            fs::permissions(self, perms, fs::perm_options::remove);
            return 0;
            LUA_TRY_END;
        }

        static int mt_div(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                return constructor_(L, self / lua::checkstring(L, 2));
            case LUA_TUSERDATA:
                return constructor_(L, self / to(L, 2));
            default:
                luaL_checktype(L, 2, LUA_TSTRING);
                return 0;
            }
            LUA_TRY_END;
        }

        static int mt_concat(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                return constructor_(L, self.native() + lua::checkstring(L, 2));
            case LUA_TUSERDATA:
                return constructor_(L, self.native() + to(L, 2).native());
            default:
                luaL_checktype(L, 2, LUA_TSTRING);
                return 0;
            }
            LUA_TRY_END;
        }

        static int mt_eq(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            const fs::path& rht = path::to(L, 2);
            lua_pushboolean(L, path_helper::equal(self, rht));
            return 1;
            LUA_TRY_END;
        }

        static int destructor(lua_State* L) {
            LUA_TRY;
            fs::path& self = path::to(L, 1);
            self.~path();
            return 0;
            LUA_TRY_END;
        }

        static int mt_tostring(lua_State* L) {
            LUA_TRY;
            const fs::path& self = path::to(L, 1);
            auto            res = self.generic_u8string();
#if defined(__cpp_lib_char8_t)
            lua_pushlstring(L, reinterpret_cast<const char*>(res.data()), res.size());
#else
            lua_pushlstring(L, res.data(), res.size());
#endif
            return 1;
            LUA_TRY_END;
        }

        static void* newudata(lua_State* L) {
            void* storage = lua_newuserdatauv(L, sizeof(fs::path), 0);
            if (newObject(L, "filesystem")) {
                static luaL_Reg mt[] = {
                    {"string", path::mt_tostring},
                    {"filename", path::filename},
                    {"parent_path", path::parent_path},
                    {"stem", path::stem},
                    {"extension", path::extension},
                    {"is_absolute", path::is_absolute},
                    {"is_relative", path::is_relative},
                    {"remove_filename", path::remove_filename},
                    {"replace_extension", path::replace_extension},
                    {"equal_extension", path::equal_extension},
                    {"list_directory", path::list_directory},
                    {"permissions", path::permissions},
                    {"add_permissions", path::add_permissions},
                    {"remove_permissions", path::remove_permissions},
                    {"__div", path::mt_div},
                    {"__concat", path::mt_concat},
                    {"__eq", path::mt_eq},
                    {"__gc", path::destructor},
                    {"__tostring", path::mt_tostring},
                    {"__debugger_tostring", path::mt_tostring},
                    {NULL, NULL},
                };
                luaL_setfuncs(L, mt, 0);
                lua_pushvalue(L, -1);
                lua_setfield(L, -2, "__index");
            }
            lua_setmetatable(L, -2);
            return storage;
        }
    }

    static int exists(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::exists(p));
        return 1;
        LUA_TRY_END;
    }

    static int is_directory(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::is_directory(p));
        return 1;
        LUA_TRY_END;
    }

    static int is_regular_file(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::is_regular_file(p));
        return 1;
        LUA_TRY_END;
    }

    static int create_directory(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::create_directory(p));
        return 1;
        LUA_TRY_END;
    }

    static int create_directories(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::create_directories(p));
        return 1;
        LUA_TRY_END;
    }

    static int rename(lua_State* L) {
        LUA_TRY;
        const fs::path& from = path::to(L, 1);
        const fs::path& to = path::to(L, 2);
        fs::rename(from, to);
        return 0;
        LUA_TRY_END;
    }

    static int remove(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushboolean(L, fs::remove(p));
        return 1;
        LUA_TRY_END;
    }

    static int remove_all(lua_State* L) {
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        lua_pushinteger(L, fs::remove_all(p));
        return 1;
        LUA_TRY_END;
    }

    static int current_path(lua_State* L) {
        LUA_TRY;
        if (lua_gettop(L) == 0) {
            return path::constructor_(L, fs::current_path());
        }
        const fs::path& p = path::to(L, 1);
        fs::current_path(p);
        return 0;
        LUA_TRY_END;
    }

    static int copy(lua_State* L) {
        LUA_TRY;
        const fs::path& from = path::to(L, 1);
        const fs::path& to = path::to(L, 2);
        auto options = fs::copy_options::recursive;
        if (lua_toboolean(L, 3)) {
            options |= fs::copy_options::overwrite_existing;
        }
        fs::copy(from, to, options);
        return 0;
        LUA_TRY_END;
    }

    static int copy_file(lua_State* L) {
        LUA_TRY;
        const fs::path& from = path::to(L, 1);
        const fs::path& to = path::to(L, 2);
        auto options = fs::copy_options::none;
        if (lua_toboolean(L, 3)) {
            options |= fs::copy_options::overwrite_existing;
            if (fs::exists(from)) {
                fs::remove(to);
            }
        }
        fs::copy_file(from, to, options);
        return 0;
        LUA_TRY_END;
    }

    static int absolute(lua_State* L) {
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

#if defined(__linux__)
#define FS_NATIVE(p) (p)
#else
    static fs::path FS_NATIVE(const fs::path& p) {
        auto s = p.native();
        std::transform(s.begin(), s.end(), s.begin(),
#if defined(_WIN32)
            ::towlower
#else
            ::tolower
#endif
        );
        return fs::path(s);
    }
#endif

    static int relative(lua_State* L) {
        LUA_TRY;
        return path::constructor_(L, fs::relative(FS_NATIVE(path::to(L, 1)),
            lua_gettop(L) == 1
            ? FS_NATIVE(fs::current_path())
            : FS_NATIVE(path::to(L, 2))
        ));
        LUA_TRY_END;
    }
//#if !defined(__cpp_lib_chrono) || __cpp_lib_chrono < 201907
    template <class DestClock, class SourceClock, class Duration>
    static auto xclock_cast(const std::chrono::time_point<SourceClock, Duration>& t) {
        return DestClock::now() + (t - SourceClock::now());
    }
//#endif
    static int last_write_time(lua_State* L) {
        // TODO: need file_clock http://wg21.link/p0355r7
        using namespace std::chrono;
        LUA_TRY;
        const fs::path& p = path::to(L, 1);
        if (lua_gettop(L) == 1) {
            auto system_time = xclock_cast<system_clock>(fs::last_write_time(p));
            lua_pushinteger(L, duration_cast<seconds>(system_time.time_since_epoch()).count());
            return 1;
        }
        auto file_time = xclock_cast<fs::file_time_type::clock>(system_clock::time_point() + seconds(luaL_checkinteger(L, 2)));
        fs::last_write_time(p, file_time);
        return 0;
        LUA_TRY_END;
    }

    static int exe_path(lua_State* L) {
        LUA_TRY;
        return path::constructor_(L, path_helper::exe_path());
        LUA_TRY_END;
    }

    static int dll_path(lua_State* L) {
        LUA_TRY;
        return path::constructor_(L, path_helper::dll_path());
        LUA_TRY_END;
    }

    static int filelock(lua_State* L) {
        LUA_TRY;
        const fs::path& self = path::to(L, 1);
        file::handle    fd = file::lock(self.string<file::handle::string_type::value_type>());
        if (!fd) {
            lua_pushnil(L);
            lua_pushstring(L, make_syserror().what());
            return 2;
        }
        FILE* f = file::open_write(fd);
        if (!f) {
            lua_pushnil(L);
            lua_pushstring(L, make_crterror().what());
            return 2;
        }
        lua::newfile(L, f);
        return 1;
        LUA_TRY_END;
    }

    static int luaopen(lua_State* L) {
        static luaL_Reg lib[] = {
            {"path", path::constructor},
            {"exists", exists},
            {"is_directory", is_directory},
            {"is_regular_file", is_regular_file},
            {"create_directory", create_directory},
            {"create_directories", create_directories},
            {"rename", rename},
            {"remove", remove},
            {"remove_all", remove_all},
            {"current_path", current_path},
            {"copy", copy},
            {"copy_file", copy_file},
            {"absolute", absolute},
            {"relative", relative},
            {"last_write_time", last_write_time},
            {"exe_path", exe_path},
            {"dll_path", dll_path},
            {"filelock", filelock},
            {NULL, NULL},
        };
        lua_newtable(L);
        luaL_setfuncs(L, lib, 0);
        return 1;
    }
}

ANT_LUA_API
int luaopen_filesystem_cpp(lua_State* L) {
    return ant::lua_filesystem::luaopen(L);
}
