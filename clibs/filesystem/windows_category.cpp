#include "windows_category.h"
#include "unicode.h"
#include <sstream>
#include <Windows.h>

namespace ant {
    struct errormsg : public std::wstring_view {
        typedef std::wstring_view mybase;
        errormsg(wchar_t* str) : mybase(str) { }
        ~errormsg() { ::LocalFree(reinterpret_cast<HLOCAL>(const_cast<wchar_t*>(mybase::data()))); }
    };

    static std::wstring error_message(int error_code) {
        wchar_t* message = 0;
        unsigned long result = ::FormatMessageW(
            FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_IGNORE_INSERTS,
            NULL,
            error_code,
            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
            reinterpret_cast<LPWSTR>(&message),
            0,
            NULL);

        if ((result == 0) || !message) {
            std::wostringstream os;
            os << L"Unable to get an error message for error code: " << error_code << ".";
            return os.str();
        }
        errormsg str(message);
        while (str.size() && ((str.back() == L'\n') || (str.back() == L'\r'))) {
            str.remove_suffix(1);
        }
        return std::wstring(str);
    }

    class winCategory : public std::error_category {
    public:
        virtual const char* name() const noexcept {
            return "Windows";
        }
        virtual std::string message(int error_code) const noexcept {
            return std::move(w2u(error_message(error_code)));
        }
        virtual std::error_condition default_error_condition(int error_code) const noexcept {
            const std::error_condition cond = std::system_category().default_error_condition(error_code);
            if (cond.category() == std::generic_category()) {
                return cond;
            }
            return std::error_condition(error_code, *this);
        }
    };

    static winCategory g_windows_category;

    const std::error_category& windows_category() noexcept {
        return g_windows_category;
    }
}
