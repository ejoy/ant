#include <lua.hpp>
#include <shobjidl.h>
#include <wrl/client.h>
#include <string>
#include <string_view>
#include <memory>

using Microsoft::WRL::ComPtr;

static std::wstring u2w(const std::string_view& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), NULL, 0);
    if (wlen <= 0)  {
        return L"";
    }
    std::unique_ptr<wchar_t[]> result(new wchar_t[wlen]);
    ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), result.get(), wlen);
    return std::wstring(result.release(), wlen);
}

static std::string w2u(const std::wstring_view& wstr) {
    if (wstr.empty())  {
        return "";
    }
    int len = ::WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), NULL, 0, 0, 0);
    if (len <= 0) {
        return "";
    }
    std::unique_ptr<char[]> result(new char[len]);
    ::WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), result.get(), len, 0, 0);
    return std::string(result.release(), len);
}

static std::wstring towstring(lua_State* L, int idx) {
    size_t len = 0;
    const char* str = luaL_checklstring(L, idx, &len);
    return u2w(std::string_view(str, len));
}

static void pushwstring(lua_State* L, const std::wstring_view& wstr) {
    auto str = w2u(wstr);
    lua_pushlstring(L, str.data(), str.size());
}

static void dlgSetTitle(lua_State* L, ComPtr<IFileDialog>& dialog, int idx) {
    if (LUA_TSTRING == lua_getfield(L, idx, "Title")) {
        dialog->SetTitle(towstring(L, -1).c_str());
    }
    lua_pop(L, 1);
}

static void dlgSetFileTypes(lua_State* L, ComPtr<IFileDialog>& dialog, int idx) {
    if (LUA_TTABLE != lua_getfield(L, idx, "FileTypes")) {
        lua_pop(L, 1);
        return;
    }
    bool single = lua_geti(L, -1, 1) != LUA_TTABLE; lua_pop(L, 1);
    if (single) {
        std::wstring szName;
        std::wstring szSspec;

        lua_geti(L, -1, 1);
        szName = towstring(L, -1);
        lua_pop(L, 1);

        lua_geti(L, -1, 2);
        szSspec = towstring(L, -1);
        lua_pop(L, 1);

        COMDLG_FILTERSPEC spec = { szName.c_str(), szSspec.c_str() };
        dialog->SetFileTypes(1, &spec);
    }
    else {
        lua_Integer n = luaL_len(L, -1);
        std::unique_ptr<std::wstring[]>      store(new std::wstring[n*2]);
        std::unique_ptr<COMDLG_FILTERSPEC[]> spec(new COMDLG_FILTERSPEC[n]);
        for (lua_Integer i = 1; i <= n; ++i) {
            lua_geti(L, -1, i);
            luaL_checktype(L, -1, LUA_TTABLE);

            lua_geti(L, -1, 1);
            store[2*i-2] = towstring(L, -1);
            spec[i-1].pszName = store[2*i-2].c_str();
            lua_pop(L, 1);

            lua_geti(L, -1, 2);
            store[2*i-1] = towstring(L, -1);
            spec[i-1].pszSpec = store[2*i-1].c_str();
            lua_pop(L, 1);

            lua_pop(L, 1);
        }
        dialog->SetFileTypes(n, spec.get());
    }
    lua_pop(L, 1);
}

static HWND dlgGetOwnerWindow(lua_State* L, int idx) {
    HWND res = NULL;
    if (LUA_TLIGHTUSERDATA == lua_getfield(L, idx, "Owner")) {
        res = (HWND)lua_touserdata(L, -1);
    }
    lua_pop(L, 1);
    return res;
}

static void dlgPushPathFromItem(lua_State* L, const ComPtr<IShellItem>& item) {
    wchar_t* name = nullptr;
    item->GetDisplayName(SIGDN_FILESYSPATH, &name);
    if (name)
        pushwstring(L, name);
    else
        lua_pushstring(L, "");
    ::CoTaskMemFree(name);
}

static int lcreate(lua_State* L, bool open_or_save) {
    luaL_checktype(L, 1, LUA_TTABLE);
    ComPtr<IFileDialog> dialog;
    if (HRESULT hr = ::CoCreateInstance(open_or_save? CLSID_FileOpenDialog: CLSID_FileSaveDialog, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog)); FAILED(hr)) {
        return luaL_error(L, "CoCreateInstance failed: %p", hr);
    }
    dlgSetTitle(L, dialog, 1);
    dlgSetFileTypes(L, dialog, 1);
    if (HRESULT hr = dialog->Show(dlgGetOwnerWindow(L, 1)); FAILED(hr)) {
        lua_pushboolean(L, 0);
        (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) 
            ? lua_pushstring(L, "Cancelled")
            : lua_pushfstring(L, "IFileDialog::Show failed: %p", hr);
        return 2;
    }
    if (!open_or_save) {
        ComPtr<IShellItem> item;
        if (HRESULT hr = dialog->GetResult(&item); FAILED(hr)) {
            lua_pushboolean(L, 0);
            lua_pushfstring(L, "IFileDialog::GetResult failed: %p", hr);
            return 2;
        }
        lua_pushboolean(L, 1);
        dlgPushPathFromItem(L, item);
        return 2;
    }

    ComPtr<IFileOpenDialog> opendialog;
    dialog.As<IFileOpenDialog>(&opendialog);
    ComPtr<IShellItemArray> items;
    if (HRESULT hr = opendialog->GetResults(&items); FAILED(hr)) {
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "IFileOpenDialog::GetResults failed: %p", hr);
        return 2;
    }
    DWORD count = 0;
    if (HRESULT hr = items->GetCount(&count); FAILED(hr)) {
        lua_pushboolean(L, 0);
        lua_pushfstring(L, "IShellItemArray::GetCount failed: %p", hr);
        return 2;
    }
    lua_pushboolean(L, 1);
    lua_newtable(L);
    for (DWORD i = 0; i < count; i++) {
        ComPtr<IShellItem> item;
        if (HRESULT hr = items->GetItemAt(i, &item); FAILED(hr)) {
            lua_pushboolean(L, 0);
            lua_pushfstring(L, "IShellItem::GetItemAt failed: %p", hr);
            return 2;
        }
        dlgPushPathFromItem(L, item);
        lua_seti(L, -2, i + 1);
    }
    return 2;
}

static int lopen(lua_State* L) {
    return lcreate(L, true);
}

static int lsave(lua_State* L) {
    return lcreate(L, false);
}


extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_filedialog(lua_State* L) {
    if (HRESULT hr = ::CoInitialize(NULL); FAILED(hr)) {
        luaL_error(L, "CoInitialize failed: %p", hr);
    }

    static luaL_Reg lib[] = {
        { "open", lopen },
        { "save", lsave },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    return 1;
}
