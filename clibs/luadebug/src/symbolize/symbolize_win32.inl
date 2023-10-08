//clang-format off
#include <Windows.h>
//clang-format on
#include <DbgHelp.h>
#include <bee/nonstd/filesystem.h>
#include <bee/nonstd/format.h>
#include <bee/subprocess.h>
#include <symbolize/symbolize.h>

#include <memory>

namespace luadebug {
    struct SymHandler {
        HANDLE hProcess = NULL;
        ~SymHandler() {
            SymCleanup(hProcess);
            hProcess = NULL;
        }
        operator bool() const noexcept {
            return hProcess != NULL;
        }
    };
    inline std::string searchpath(bool SymBuildPath, bool SymUseSymSrv) {
        // Build the sym-path:
        if (SymBuildPath) {
            std::string searchpath;
            searchpath.reserve(4096);
            searchpath.append(".;");
            std::error_code ec;
            auto current_path = std::filesystem::current_path(ec);
            if (!ec) {
                searchpath.append(current_path.string().c_str());
                searchpath += ';';
            }
            const size_t nTempLen = 1024;
            char szTemp[nTempLen];

            // Now add the path for the main-module:
            if (GetModuleFileNameA(NULL, szTemp, nTempLen) > 0) {
                std::filesystem::path path(szTemp);
                searchpath.append(path.parent_path().string());
                searchpath += ';';
            }
            if (GetEnvironmentVariableA("_NT_SYMBOL_PATH", szTemp, nTempLen) > 0) {
                szTemp[nTempLen - 1] = 0;
                searchpath.append(szTemp);
                searchpath += ';';
            }
            if (GetEnvironmentVariableA("_NT_ALTERNATE_SYMBOL_PATH", szTemp, nTempLen) > 0) {
                szTemp[nTempLen - 1] = 0;
                searchpath.append(szTemp);
                searchpath += ';';
            }
            if (GetEnvironmentVariableA("SYSTEMROOT", szTemp, nTempLen) > 0) {
                szTemp[nTempLen - 1] = 0;
                searchpath.append(szTemp);
                searchpath += ';';
                searchpath.append(szTemp);
                searchpath.append("\\system32;");
            }

            if (SymUseSymSrv) {
                if (GetEnvironmentVariableA("SYSTEMDRIVE", szTemp, nTempLen) > 0) {
                    szTemp[nTempLen - 1] = 0;
                    searchpath.append("SRV*");
                    searchpath.append(szTemp);
                    searchpath.append("\\websymbols*https://msdl.microsoft.com/download/symbols;");
                }
                else
                    searchpath.append("SRV*c:\\websymbols*https://msdl.microsoft.com/download/symbols;");
            }
            return searchpath;
        }  // if SymBuildPath
        return {};
    }

    inline HANDLE createSymHandler(bool SymBuildPath, bool SymUseSymSrv) {
        HANDLE proc = GetCurrentProcess();
        auto path   = searchpath(SymBuildPath, SymUseSymSrv);
        if (!SymInitialize(proc, path.c_str(), TRUE)) {
            if (GetLastError() != 87) {
                return nullptr;
            }
        }
        DWORD symOptions = SymGetOptions();  // SymGetOptions
        symOptions |= SYMOPT_LOAD_LINES;
        symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
        symOptions = SymSetOptions(symOptions);
        return proc;
    }

    inline SymHandler& GetSymHandler() {
        static SymHandler handler { createSymHandler(true, true) };
        return handler;
    }

    struct SymbolFileInfo {
        std::string name;
        uint32_t lineno = 0;
    };

    struct Symbol {
        std::string module_name;
        std::string function_name;
        std::optional<SymbolFileInfo> file;
    };

    inline std::optional<Symbol> Addr2Symbol(const void* pObject) {
        static constexpr size_t max_sym_name =
#ifdef MAX_SYM_NAME
            MAX_SYM_NAME;
#else
            2000;
#endif  // DEBUG
        struct MY_SYMBOL_INFO : SYMBOL_INFO {
            char name_buffer[MAX_SYM_NAME];
        };

        auto& handler = GetSymHandler();
        if (!handler) {
            return std::nullopt;
        }
        using PTR_T =
#ifdef _WIN64
            DWORD64;
#else
            DWORD;
#endif
        PTR_T dwAddress        = PTR_T(pObject);
        DWORD64 dwDisplacement = 0;

        MY_SYMBOL_INFO sym = {};
        sym.SizeOfStruct   = sizeof(SYMBOL_INFO);
        sym.MaxNameLen     = max_sym_name;
        if (!SymFromAddr(handler.hProcess, dwAddress, &dwDisplacement, &sym)) {
            return std::nullopt;
        }
        if (sym.Flags & SYMFLAG_PUBLIC_CODE) {
#if defined(_M_AMD64)
            uint8_t OP = *(uint8_t*)dwAddress;
            if (OP == 0xe9) {
                int32_t offset = *(int32_t*)((char*)dwAddress + 1);
                return Addr2Symbol((void*)(dwAddress + 5 + offset));
            }
#else
            // TODO ARM64/ARM64EC
#endif  // _M_AMD64
        }
        Symbol sb;
        {
            char buffer[256];
            if (UnDecorateSymbolName(sym.Name, buffer, 256, UNDNAME_COMPLETE) != 0)
                sb.function_name = buffer;
            else
                sb.function_name = sym.Name;
        }
        IMAGEHLP_MODULE md = {};
        md.SizeOfStruct    = sizeof(IMAGEHLP_MODULE);
        if (SymGetModuleInfo(handler.hProcess, dwAddress, &md)) {
#if defined(_WIN64)
            if (md.LineNumbers) {
#endif
                IMAGEHLP_LINE line     = {};
                line.SizeOfStruct      = sizeof(IMAGEHLP_LINE);
                DWORD lineDisplacement = 0;
                if (SymGetLineFromAddr(handler.hProcess, dwAddress, &lineDisplacement, &line)) {
                    sb.file = { line.FileName, line.LineNumber };
                }
#if defined(_WIN64)
            }
#endif
            sb.module_name = md.ModuleName;
        }

        // Object name output
        return std::move(sb);
    };

    symbol_info symbolize(const void* ptr) {
        if (!ptr) {
            return {};
        }
        auto sym = Addr2Symbol(ptr);
        if (sym) {
            symbol_info info;
            if (sym->file) {
                info.module_name   = sym->module_name;
                info.function_name = sym->function_name;
                info.file_name     = sym->file->name;
                info.line_number   = std::to_string(sym->file->lineno);
            }
            else {
                info.module_name   = sym->module_name;
                info.function_name = sym->function_name;
            }
            return info;
        }
        return {};
    }
}
