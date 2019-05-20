#pragma once

#include <Windows.h>
#include <assert.h>
#include <bee/nonstd/dynarray.h>
#include <deque>
#include <list>
#include <map>
#include <string>
#include <system_error>
#include <vector>

namespace bee::registry {
    template <class C>
    struct reg_traits {
    public:
        typedef C                    char_type;
        typedef size_t               size_type;
        typedef ptrdiff_t            difference_type;
        typedef HKEY                 hkey_type;
        typedef std::basic_string<C> string_type;
        typedef FILETIME             time_type;
        typedef LONG                 result_type;

    public:
        static result_type close(hkey_type hkey);
        static hkey_type   dup_key(hkey_type hkey, REGSAM samDesired = KEY_ALL_ACCESS, result_type* result = NULL);
        static result_type open_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, REGSAM samDesired = KEY_ALL_ACCESS);
        static result_type create_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, REGSAM samDesired = KEY_ALL_ACCESS);
        static result_type create_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, bool& bCreated, REGSAM samDesired = KEY_ALL_ACCESS);
        static result_type delete_key(hkey_type hkey, char_type const* sub_key_name);
        static result_type query_value(hkey_type hkey, char_type const* valueName, uint32_t& valueType, void* data, size_type* cbData);
        static result_type set_value(hkey_type hkey, char_type const* valueName, uint32_t valueType, void const* data, size_type cbData);
        static result_type delete_value(hkey_type hkey, char_type const* valueName);
        static result_type delete_tree(hkey_type hkey, char_type const* sub_key_name);
        static result_type
        query_info(hkey_type hkey, char_type* key_class, size_type* cch_key_class, uint32_t* c_sub_keys, size_type* cch_sub_key_max, size_type* cch_key_class_max, uint32_t* c_values, size_type* cch_valueName_max, size_type* cb_value_data_max, size_type* cb_security_descriptor_max, time_type* time_last_write);
        static result_type enum_key(hkey_type hkey, uint32_t index, char_type* key_name, size_type* cch_key_name, time_type* time_last_write = NULL);
        static result_type enum_key(hkey_type hkey, uint32_t index, char_type* key_name, size_type* cch_key_name, char_type* key_class, size_type* cch_key_class, time_type* time_last_write);
        static result_type enum_value(hkey_type hkey, uint32_t index, char_type* valueName, size_type* cch_valueName, uint32_t* valueType, void* data, size_type* cbData);
        static result_type enum_value(hkey_type hkey, uint32_t index, char_type* valueName, size_type* cch_valueName);
        static size_type   expand_environment_strings(char_type const* src,
                                                      char_type*       dest,
                                                      size_type        cch_dest);
    };

    template <>
    struct reg_traits<char> {
    public:
        typedef char        char_type;
        typedef size_t      size_type;
        typedef ptrdiff_t   difference_type;
        typedef HKEY        hkey_type;
        typedef std::string string_type;
        typedef FILETIME    time_type;
        typedef LONG        result_type;

    public:
        static result_type close(hkey_type hkey) { return ::RegCloseKey(hkey); }

        static hkey_type dup_key(hkey_type hkey, REGSAM samDesired, result_type* result = NULL) {
            hkey_type   hkeyDup;
            result_type res = ::RegOpenKeyExA(hkey, "", 0, samDesired, &hkeyDup);

            if (ERROR_SUCCESS != res) {
                hkeyDup = NULL;
            }

            if (NULL != result) {
                *result = res;
            }

            return hkeyDup;
        }

        static result_type open_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, REGSAM samDesired = KEY_ALL_ACCESS) {
            return ::RegOpenKeyExA(hkey, sub_key_name, 0, samDesired, hkey_result);
        }

        static result_type create_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, REGSAM samDesired = KEY_ALL_ACCESS) {
            return ::RegCreateKeyExA(hkey, sub_key_name, 0, NULL, 0, samDesired, NULL, hkey_result, NULL);
        }

        static result_type create_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, bool& bCreated, REGSAM samDesired = KEY_ALL_ACCESS) {
            DWORD       disposition;
            result_type res =
                ::RegCreateKeyExA(hkey, sub_key_name, 0, NULL, 0, samDesired, NULL, hkey_result, &disposition);
            bCreated = (ERROR_SUCCESS == res) && (REG_CREATED_NEW_KEY == disposition);
            return res;
        }

        static result_type delete_key(hkey_type hkey, char_type const* sub_key_name) {
            return ::RegDeleteKeyA(hkey, sub_key_name);
        }

        static result_type query_value(hkey_type hkey, char_type const* valueName, uint32_t& valueType, void* data, size_type* cbData) {
            return ::RegQueryValueExA(
                hkey, valueName, NULL, reinterpret_cast<LPDWORD>(&valueType), static_cast<LPBYTE>(data), reinterpret_cast<LPDWORD>(cbData));
        }

        static result_type set_value(hkey_type hkey, char_type const* valueName, uint32_t valueType, void const* data, size_type cbData) {
            return ::RegSetValueExA(hkey, valueName, 0, valueType, static_cast<BYTE const*>(data), static_cast<DWORD>(cbData));
        }

        static result_type delete_value(hkey_type hkey, char_type const* valueName) {
            return ::RegDeleteValueA(hkey, valueName);
        }

        static result_type delete_tree(hkey_type        hkey,
                                       char_type const* sub_key_name) {
            result_type res =
                execute_dynamic_("advapi32.dll", "RegDeleteTreeA", hkey, sub_key_name);

            if (ERROR_PROC_NOT_FOUND == res) {
                res = execute_dynamic_("shlwapi.dll", "SHDeleteKeyA", hkey, sub_key_name);
            }

            return res;
        }

        static result_type
        query_info(hkey_type hkey, char_type* key_class, size_type* cch_key_class, uint32_t* c_sub_keys, size_type* cch_sub_key_max, size_type* cch_key_class_max, uint32_t* c_values, size_type* cch_valueName_max, size_type* cb_value_data_max, size_type* cb_security_descriptor_max, time_type* time_last_write) {
            return ::RegQueryInfoKeyA(
                hkey, key_class, reinterpret_cast<LPDWORD>(cch_key_class), NULL, reinterpret_cast<LPDWORD>(c_sub_keys), reinterpret_cast<LPDWORD>(cch_sub_key_max), reinterpret_cast<LPDWORD>(cch_key_class_max), reinterpret_cast<LPDWORD>(c_values), reinterpret_cast<LPDWORD>(cch_valueName_max), reinterpret_cast<LPDWORD>(cb_value_data_max), reinterpret_cast<LPDWORD>(cb_security_descriptor_max), time_last_write);
        }

        static result_type enum_key(hkey_type hkey, uint32_t index, char_type* key_name, size_type* cch_key_name, time_type* time_last_write = NULL) {
            return ::RegEnumKeyExA(hkey, index, key_name, reinterpret_cast<LPDWORD>(cch_key_name), NULL, NULL, NULL, time_last_write);
        }

        static result_type enum_key(hkey_type hkey, uint32_t index, char_type* key_name, size_type* cch_key_name, char_type* key_class, size_type* cch_key_class, time_type* time_last_write) {
            return ::RegEnumKeyExA(
                hkey, index, key_name, reinterpret_cast<LPDWORD>(cch_key_name), NULL, key_class, reinterpret_cast<LPDWORD>(cch_key_class), time_last_write);
        }

        static result_type enum_value(hkey_type hkey, uint32_t index, char_type* valueName, size_type* cch_valueName, uint32_t* valueType, void* data, size_type* cbData) {
            return ::RegEnumValueA(
                hkey, index, valueName, reinterpret_cast<LPDWORD>(cch_valueName), NULL, reinterpret_cast<LPDWORD>(valueType), reinterpret_cast<LPBYTE>(data), reinterpret_cast<LPDWORD>(cbData));
        }

        static result_type enum_value(hkey_type hkey, uint32_t index, char_type* valueName, size_type* cch_valueName) {
            return ::RegEnumValueA(hkey, index, valueName, reinterpret_cast<LPDWORD>(cch_valueName), NULL, NULL, NULL, NULL);
        }

        static size_type expand_environment_strings(char_type const* src,
                                                    char_type*       dest,
                                                    size_type        cch_dest) {
            assert(nullptr != src);
            assert(nullptr != dest || 0 == cch_dest);
            return ::ExpandEnvironmentStringsA(src, dest, (DWORD)cch_dest);
        }

    private:
        static result_type execute_dynamic_(const char* module, const char* function, hkey_type a1, char_type const* a2) {
            result_type r = ERROR_SUCCESS;
            HINSTANCE   hinst = ::LoadLibraryA(module);

            if (NULL == hinst) {
                r = static_cast<result_type>(::GetLastError());
            }
            else {
                union {
                    FARPROC fp;
                    DWORD(__stdcall* pfn)
                    (HKEY, LPCSTR);
                } u;
                u.fp = ::GetProcAddress(hinst, function);

                if (NULL == u.fp) {
                    r = static_cast<result_type>(::GetLastError());
                }

                else {
                    r = static_cast<result_type>((*u.pfn)(a1, a2));
                }

                ::FreeLibrary(hinst);
            }

            return r;
        }
    };

    template <>
    struct reg_traits<wchar_t> {
    public:
        typedef wchar_t      char_type;
        typedef size_t       size_type;
        typedef ptrdiff_t    difference_type;
        typedef HKEY         hkey_type;
        typedef std::wstring string_type;
        typedef FILETIME     time_type;
        typedef LONG         result_type;

    public:
        static result_type close(hkey_type hkey) { return ::RegCloseKey(hkey); }

        static hkey_type dup_key(hkey_type hkey, REGSAM samDesired, result_type* result = NULL) {
            hkey_type   hkeyDup;
            result_type res = ::RegOpenKeyExW(hkey, L"", 0, samDesired, &hkeyDup);

            if (ERROR_SUCCESS != res) {
                hkeyDup = NULL;
            }

            if (NULL != result) {
                *result = res;
            }

            return hkeyDup;
        }

        static result_type open_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, REGSAM samDesired = KEY_ALL_ACCESS) {
            return ::RegOpenKeyExW(hkey, sub_key_name, 0, samDesired, hkey_result);
        }

        static result_type create_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, REGSAM samDesired = KEY_ALL_ACCESS) {
            return ::RegCreateKeyExW(hkey, sub_key_name, 0, NULL, 0, samDesired, NULL, hkey_result, NULL);
        }

        static result_type create_key(hkey_type hkey, char_type const* sub_key_name, hkey_type* hkey_result, bool& bCreated, REGSAM samDesired = KEY_ALL_ACCESS) {
            DWORD       disposition;
            result_type res =
                ::RegCreateKeyExW(hkey, sub_key_name, 0, NULL, 0, samDesired, NULL, hkey_result, &disposition);
            bCreated = (ERROR_SUCCESS == res) && (REG_CREATED_NEW_KEY == disposition);
            return res;
        }

        static result_type delete_key(hkey_type hkey, char_type const* sub_key_name) {
            return ::RegDeleteKeyW(hkey, sub_key_name);
        }

        static result_type query_value(hkey_type hkey, char_type const* valueName, uint32_t& valueType, void* data, size_type* cbData) {
            return ::RegQueryValueExW(
                hkey, valueName, NULL, reinterpret_cast<LPDWORD>(&valueType), static_cast<LPBYTE>(data), reinterpret_cast<LPDWORD>(cbData));
        }

        static result_type set_value(hkey_type hkey, char_type const* valueName, uint32_t valueType, void const* data, size_type cbData) {
            return ::RegSetValueExW(hkey, valueName, 0, valueType, static_cast<BYTE const*>(data), static_cast<DWORD>(cbData));
        }

        static result_type delete_value(hkey_type hkey, char_type const* valueName) {
            return ::RegDeleteValueW(hkey, valueName);
        }

        static result_type delete_tree(hkey_type        hkey,
                                       char_type const* sub_key_name) {
            result_type res =
                execute_dynamic_(L"advapi32.dll", "RegDeleteTreeW", hkey, sub_key_name);

            if (ERROR_PROC_NOT_FOUND == res) {
                res =
                    execute_dynamic_(L"shlwapi.dll", "SHDeleteKeyW", hkey, sub_key_name);
            }

            return res;
        }

        static result_type
        query_info(hkey_type hkey, char_type* key_class, size_type* cch_key_class, uint32_t* c_sub_keys, size_type* cch_sub_key_max, size_type* cch_key_class_max, uint32_t* c_values, size_type* cch_valueName_max, size_type* cb_value_data_max, size_type* cb_security_descriptor_max, time_type* time_last_write) {
            return ::RegQueryInfoKeyW(
                hkey, key_class, reinterpret_cast<LPDWORD>(cch_key_class), NULL, reinterpret_cast<LPDWORD>(c_sub_keys), reinterpret_cast<LPDWORD>(cch_sub_key_max), reinterpret_cast<LPDWORD>(cch_key_class_max), reinterpret_cast<LPDWORD>(c_values), reinterpret_cast<LPDWORD>(cch_valueName_max), reinterpret_cast<LPDWORD>(cb_value_data_max), reinterpret_cast<LPDWORD>(cb_security_descriptor_max), time_last_write);
        }

        static result_type enum_key(hkey_type hkey, uint32_t index, char_type* key_name, size_type* cch_key_name, time_type* time_last_write = NULL) {
            return ::RegEnumKeyExW(hkey, index, key_name, reinterpret_cast<LPDWORD>(cch_key_name), NULL, NULL, NULL, time_last_write);
        }

        static result_type enum_key(hkey_type hkey, uint32_t index, char_type* key_name, size_type* cch_key_name, char_type* key_class, size_type* cch_key_class, time_type* time_last_write) {
            return ::RegEnumKeyExW(
                hkey, index, key_name, reinterpret_cast<LPDWORD>(cch_key_name), NULL, key_class, reinterpret_cast<LPDWORD>(cch_key_class), time_last_write);
        }

        static result_type enum_value(hkey_type hkey, uint32_t index, char_type* valueName, size_type* cch_valueName, uint32_t* valueType, void* data, size_type* cbData) {
            return ::RegEnumValueW(
                hkey, index, valueName, reinterpret_cast<LPDWORD>(cch_valueName), NULL, reinterpret_cast<LPDWORD>(valueType), reinterpret_cast<LPBYTE>(data), reinterpret_cast<LPDWORD>(cbData));
        }

        static result_type enum_value(hkey_type hkey, uint32_t index, char_type* valueName, size_type* cch_valueName) {
            return ::RegEnumValueW(hkey, index, valueName, reinterpret_cast<LPDWORD>(cch_valueName), NULL, NULL, NULL, NULL);
        }

        static size_type expand_environment_strings(char_type const* src,
                                                    char_type*       dest,
                                                    size_type        cch_dest) {
            assert(nullptr != src);
            assert(nullptr != dest || 0 == cch_dest);
            return ::ExpandEnvironmentStringsW(src, dest, (DWORD)cch_dest);
        }

    private:
        static result_type execute_dynamic_(const wchar_t*   module,
                                            const char*      function,
                                            hkey_type        a1,
                                            char_type const* a2) {
            result_type r = ERROR_SUCCESS;
            HINSTANCE   hinst = ::LoadLibraryW(module);

            if (NULL == hinst) {
                r = static_cast<result_type>(::GetLastError());
            }
            else {
                union {
                    FARPROC fp;
                    DWORD(__stdcall* pfn)
                    (HKEY, LPCWSTR);
                } u;
                u.fp = ::GetProcAddress(hinst, function);

                if (NULL == u.fp) {
                    r = static_cast<result_type>(::GetLastError());
                }

                else {
                    r = static_cast<result_type>((*u.pfn)(a1, a2));
                }

                ::FreeLibrary(hinst);
            }

            return r;
        }
    };

    class registry_exception : public std::system_error {
    public:
        registry_exception(const char* reason, int error_code)
            : std::system_error(error_code, std::system_category(), reason) {}
    };

    class access_denied_exception : public registry_exception {
    public:
        access_denied_exception(const char* reason, int error_code)
            : registry_exception(reason, error_code) {}
    };

    inline void check_and_throw_exception(const char* reason, int error_code) {
        if (ERROR_SUCCESS != error_code) {
            if (ERROR_ACCESS_DENIED == error_code) {
                throw access_denied_exception(reason, error_code);
            }
            else {
                throw registry_exception(reason, error_code);
            }
        }
    }

    enum class open_option {
        none,
        fail_if_not_exists = none,
        create_if_not_exists,
    };

    enum class open_access {
        none = 0,
        read = KEY_READ,
        write = KEY_READ | KEY_WRITE,
        w32key = KEY_WOW64_32KEY,
        w64key = KEY_WOW64_64KEY,
    };

    template <class char_type, class T>
    struct is_stringable {
        static const bool value = false;
    };

    template <class char_type>
    struct is_stringable<char_type, std::vector<char_type>> {
        static const bool value = true;
    };
    template <class char_type>
    struct is_stringable<char_type, std::list<char_type>> {
        static const bool value = true;
    };
    template <class char_type>
    struct is_stringable<char_type, std::deque<char_type>> {
        static const bool value = true;
    };

    template <class Target, class Source>
    inline Target reg_dispatch(const Source& s) {
        return std::move(Target(std::begin(s), std::end(s)));
    }

    template <typename C, typename T, class K>
    class basic_value {
    public:
        typedef C                                 char_type;
        typedef T                                 traits_type;
        typedef K                                 key_type;
        typedef basic_value<C, T, K>              class_type;
        typedef typename traits_type::size_type   size_type;
        typedef typename traits_type::string_type string_type;
        typedef typename traits_type::hkey_type   hkey_type;
        typedef std::dynarray<uint8_t>            blob_type;
        typedef typename traits_type::result_type result_type;

        basic_value(key_type& key, const string_type& name);
        ~basic_value();

        basic_value(class_type& rhs);
        class_type& operator=(class_type& rhs);

        basic_value(class_type&& rhs);
        class_type& operator=(class_type&& rhs);

    public:
        uint32_t    type() const;
        string_type name() const;
        bool        has() const;

        string_type get_string() const;
        uint32_t    get_uint32_t() const;
        uint64_t    get_uint64_t() const;
        blob_type   get_binary() const;

        template <typename Result>
        Result
        get(typename std::enable_if<
                is_stringable<char_type, typename std::decay<Result>::type>::value,
                int>::type* = 0) const {
            return std::move(reg_dispatch<Result>(get_string()));
        }

        template <typename Result>
        operator Result() const { return get<Result>(); }

    public:
        bool del();
        bool set_uint32_t(uint32_t value);
        bool set_uint64_t(uint64_t value);
        bool set(const char* value);
        bool set(const wchar_t* value);
        bool set(const std::string& value);
        bool set(const std::wstring& value);
        bool set(const char* value, size_type length);
        bool set(const wchar_t* value, size_type length);
        bool set(void const* value, size_type length);
        bool set(uint32_t type, void const* value, size_type length);

        template <typename Source>
        bool set(Source value,
                 typename std::enable_if<std::is_unsigned<Source>::value &&
                                             (sizeof(Source) == sizeof(uint32_t)),
                                         int>::type* = 0) {
            return set_uint32_t(value);
        }

        template <typename Source>
        bool set(Source value,
                 typename std::enable_if<std::is_unsigned<Source>::value &&
                                             (sizeof(Source) == sizeof(uint64_t)),
                                         int>::type* = 0) {
            return set_uint64_t(value);
        }

        template <typename Source>
        bool
        set(Source value,
            typename std::enable_if<
                is_stringable<char_type, typename std::decay<Source>::type>::value,
                int>::type* = 0) {
            return set(reg_dispatch<string_type>(value));
        }

        template <typename Source>
        class_type& operator=(Source s) {
            set(s);
            return *this;
        }

    protected:
        key_type&        m_key;
        string_type      m_name;
        mutable uint32_t m_type;
        mutable bool     m_bTypeRetrieved;
    };

    template <typename C, typename T, typename K>
    inline basic_value<C, T, K>::basic_value(key_type& key, const string_type& name)
        : m_key(key), m_name(name), m_type(REG_NONE), m_bTypeRetrieved(false) {}

    template <typename C, typename T, typename K>
    inline basic_value<C, T, K>::basic_value(class_type&& rhs)
        : m_key(rhs.m_key), m_name(rhs.m_name), m_type(rhs.m_type),
          m_bTypeRetrieved(rhs.m_bTypeRetrieved) {}

    template <typename C, typename T, typename K>
    inline basic_value<C, T, K>::~basic_value() {}

    template <typename C, typename T, typename K>
    inline typename basic_value<C, T, K>::class_type& basic_value<C, T, K>::
    operator=(class_type&& rhs) {
        m_key = rhs.m_key;
        m_name = rhs.m_name;
        m_type = rhs.m_type;
        m_bTypeRetrieved = rhs.m_bTypeRetrieved;
        return *this;
    }

    template <typename C, typename T, typename K>
    inline uint32_t basic_value<C, T, K>::type() const {
        if (!m_bTypeRetrieved) {
            size_type data_size = 0;
            if (0 == traits_type::query_value(m_key.handle(open_access::read),
                                              m_name.c_str(),
                                              m_type,
                                              NULL,
                                              &data_size)) {
                m_bTypeRetrieved = true;
            }
        }

        return m_type;
    }

    template <typename C, typename T, typename K>
    inline typename basic_value<C, T, K>::string_type
    basic_value<C, T, K>::name() const {
        return m_name;
    }

    template <typename C, typename T, typename K>
    inline typename basic_value<C, T, K>::string_type
    basic_value<C, T, K>::get_string() const {
        string_type ret;
        size_type   data_size = 0;
        uint32_t    dw;
        result_type res = traits_type::query_value(
            m_key.handle(open_access::read), m_name.c_str(), dw, NULL, &data_size);
        check_and_throw_exception("could not determine the data size", res);

        if (data_size > 0) {
            std::dynarray<char_type> buffer(1 + data_size / sizeof(char_type));

            data_size = buffer.size() * sizeof(char_type);
            res =
                traits_type::query_value(m_key.handle(open_access::read),
                                         m_name.c_str(),
                                         dw,
                                         buffer.data(),
                                         &data_size);
            check_and_throw_exception("could not elicit string value", res);

            if (data_size > 0) {
                assert(0 != data_size);
                data_size -= sizeof(char_type);
                buffer[data_size / sizeof(char_type)] = 0;
                ret.assign(buffer.data(), data_size / sizeof(char_type));

                if (ret.length() > 0 && REG_EXPAND_SZ == type()) {
                    size_type size =
                        traits_type::expand_environment_strings(ret.c_str(), NULL, 0);

                    if (0 != size) {
                        std::dynarray<char_type> buffer2(1 + size);

                        if (0 == traits_type::expand_environment_strings(ret.c_str(),
                                                                         &buffer2[0],
                                                                         size)) {
                            check_and_throw_exception("could not expand environment strings",
                                                      ::GetLastError());
                        }
                        else {
                            ret.assign(buffer2.data(), size);
                        }
                    }
                }
            }
        }

        return ret;
    }

    template <typename C, typename T, typename K>
    inline uint32_t basic_value<C, T, K>::get_uint32_t() const {
        uint32_t    dwValue;
        size_type   cbData = sizeof(dwValue);
        uint32_t    value_type;
        result_type res =
            traits_type::query_value(m_key.handle(open_access::read), m_name.c_str(), value_type, &dwValue, &cbData);
        check_and_throw_exception("could not query value", res);
        return dwValue;
    }

    template <typename C, typename T, typename K>
    inline uint64_t basic_value<C, T, K>::get_uint64_t() const {
        uint64_t    dwValue;
        size_type   cbData = sizeof(dwValue);
        uint32_t    value_type;
        result_type res =
            traits_type::query_value(m_key.handle(open_access::read), m_name.c_str(), value_type, &dwValue, &cbData);
        check_and_throw_exception("could not query value", res);
        return dwValue;
    }

    template <typename C, typename T, typename K>
    inline typename basic_value<C, T, K>::blob_type
    basic_value<C, T, K>::get_binary() const {
        size_type   data_size = 0;
        uint32_t    dw;
        result_type res = traits_type::query_value(
            m_key.handle(open_access::read), m_name.c_str(), dw, NULL, &data_size);
        check_and_throw_exception("could not elicit binary value", res);

        assert(dw == REG_BINARY);

        if (data_size > 0) {
            blob_type buffer(data_size);
            data_size = buffer.size();
            res =
                traits_type::query_value(m_key.handle(open_access::read),
                                         m_name.c_str(),
                                         dw,
                                         buffer.data(),
                                         &data_size);
            check_and_throw_exception("could not elicit binary value", res);
            return buffer;
        }

        return blob_type(0);
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::has() const {
        uint32_t    valueType;
        uint8_t     data[1];
        size_type   cbData = sizeof(data);
        result_type res =
            traits_type::query_value(m_key.handle(open_access::read), m_name.c_str(), valueType, &data[0], &cbData);

        switch (res) {
        case ERROR_SUCCESS:
        case ERROR_MORE_DATA:
            return true;
        default:
            return false;
        }
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set_uint32_t(uint32_t value) {
        return set(REG_DWORD, &value, sizeof(value));
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set_uint64_t(uint64_t value) {
#ifndef REG_QWORD
        const DWORD REG_QWORD = 11;
#endif
        return set(REG_QWORD, &value, sizeof(value));
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(const char* value) {
        return set(value, std::string::traits_type::length(value));
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(const wchar_t* value) {
        return set(value, std::wstring::traits_type::length(value));
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(const std::string& value) {
        return set(value.c_str(), value.size());
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(const std::wstring& value) {
        return set(value.c_str(), value.size());
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(const char* value, size_type length) {
        return set(REG_SZ, value, length * sizeof(char));
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(const wchar_t* value, size_type length) {
        return set(REG_SZ, value, length * sizeof(wchar_t));
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(void const* value, size_type length) {
        return set(REG_BINARY, value, length);
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::set(uint32_t type, void const* value, size_type length) {
        result_type res = traits_type::set_value(m_key.handle(open_access::write),
                                                 m_name.c_str(),
                                                 type,
                                                 value,
                                                 length);
        check_and_throw_exception("could not create value", res);
        return ERROR_SUCCESS == res;
    }

    template <typename C, typename T, typename K>
    inline bool basic_value<C, T, K>::del() {
        result_type res = traits_type::delete_value(m_key.handle(open_access::write),
                                                    m_name.c_str());

        switch (res) {
        case ERROR_SUCCESS:
            return true;
        default:
            check_and_throw_exception("could not delete value", res);
        case ERROR_FILE_NOT_FOUND:
            return false;
        }
    }

    template <typename C, typename T = reg_traits<C>>
    class basic_key {
    public:
        typedef C                                                  char_type;
        typedef T                                                  traits_type;
        typedef basic_key<C, T>                                    class_type;
        typedef basic_value<C, T, class_type>                      value_type;
        typedef typename traits_type::size_type                    size_type;
        typedef typename traits_type::string_type                  string_type;
        typedef typename traits_type::hkey_type                    hkey_type;
        typedef typename traits_type::result_type                  result_type;
        typedef std::map<string_type, std::unique_ptr<value_type>> value_map_type;

        basic_key(hkey_type keybase, open_access accessfix = open_access::none)
            : m_keybase(keybase), m_keypath(), m_keyname(), m_key(NULL),
              m_access(open_access::read), m_accessfix(accessfix), m_valuemap() {}

        basic_key(hkey_type keybase, const string_type& keypath, const string_type& keyname, open_access accessfix = open_access::none)
            : m_keybase(keybase), m_keypath(keypath), m_keyname(keyname), m_key(NULL),
              m_access(open_access::read), m_accessfix(accessfix), m_valuemap() {}

        basic_key(class_type const& rhs)
            : m_keybase(rhs.m_keybase), m_keypath(rhs.m_keypath),
              m_keyname(rhs.m_keyname), m_key(rhs.m_key), m_access(rhs.m_access),
              m_accessfix(rhs.m_accessfix), m_valuemap() {}

        ~basic_key() throw() {
            if (m_key != NULL) {
                traits_type::close(m_key);
            }
        }

        class_type& operator=(class_type const& rhs) {
            class_type _this(rhs);
            swap(_this);
            return *this;
        }

        void swap(class_type& rhs) throw() {
            std::swap(m_keybase, rhs.m_keybase);
            std::swap(m_keypath, rhs.m_keypath);
            std::swap(m_keyname, rhs.m_keyname);
            std::swap(m_key, rhs.m_key);
            std::swap(m_access, rhs.m_access);
            std::swap(m_accessfix, rhs.m_accessfix);
            std::swap(m_valuemap, rhs.m_valuemap);
        }

        class_type key(const string_type& key_name) const {
            static const char_type s_separator[] = {'\\', '\0'};
            if (!m_keypath.empty()) {
                return class_type(m_keybase, m_keypath + s_separator + m_keyname, key_name, m_accessfix);
            }
            else if (!m_keyname.empty()) {
                return class_type(m_keybase, m_keyname, key_name, m_accessfix);
            }
            else {
                return class_type(m_keybase, string_type(), key_name, m_accessfix);
            }
        }

        class_type key(uint32_t value_idx, char_type* data, size_type* size) {
            check_and_throw_exception("could not query key", traits_type::enum_key(handle(open_access::read), value_idx, data, size));
            return key(string_type(data, *size));
        }

        value_type& value(const string_type& value_name) {
            auto it = m_valuemap.find(value_name);
            if (it == m_valuemap.end()) {
                m_valuemap.insert(std::make_pair(
                    value_name,
                    std::unique_ptr<value_type>(new value_type(*this, value_name))));
            }
            return *(m_valuemap[value_name].get());
        }

        value_type& value(uint32_t value_idx, char_type* data, size_type* size) {
            check_and_throw_exception("could not query value", traits_type::enum_value(handle(open_access::read), value_idx, data, size));
            return value(string_type(data, *size));
        }

        value_type&
        operator[](const string_type& value_name) {
            return value(value_name);
        }

        hkey_type handle(open_access access) {
            open_key_(access);
            return m_key;
        }

        bool del(const string_type& subkey_name, bool delete_tree) {
            result_type res = delete_tree
                                  ? traits_type::delete_tree(handle(open_access::write),
                                                             subkey_name.c_str())
                                  : traits_type::delete_key(handle(open_access::write),
                                                            subkey_name.c_str());
            switch (res) {
            case ERROR_SUCCESS:
                return true;
            default:
                check_and_throw_exception("could not delete sub-key", res);
            case ERROR_FILE_NOT_FOUND:
                return false;
            }
        }

        bool del() {
            hkey_type key = open_key_(m_keybase, m_keypath, (REGSAM)open_access::write | (REGSAM)m_accessfix, open_option::fail_if_not_exists);
            if (key == NULL) {
                return false;
            }
            result_type res = traits_type::delete_tree(key, m_keyname.c_str());
            bool        suc = false;
            switch (res) {
            case ERROR_SUCCESS:
                suc = true;
                break;
            default:
            case ERROR_FILE_NOT_FOUND:
                suc = false;
                break;
            }
            traits_type::close(key);
            return suc;
        }

        void enum_keys(uint32_t* nums, size_type* maxname) {
            auto res = traits_type::query_info(handle(open_access::read), 0, 0, nums, maxname, 0, 0, 0, 0, 0, 0);
            check_and_throw_exception("could not query info", res);
        }

        void enum_values(uint32_t* nums, size_type* maxname) {
            auto res = traits_type::query_info(handle(open_access::read), 0, 0, 0, 0, 0, nums, maxname, 0, 0, 0);
            check_and_throw_exception("could not query info", res);
        }

    protected:
        bool open_key_(open_access access) {
            hkey_type key = NULL;
            if (access == open_access::write) {
                open_option option = open_option::create_if_not_exists;
                if (m_key) {
                    if (m_access == open_access::write) {
                        key = m_key;
                    }
                    else {
                        close_key_();
                        key = open_key_(m_keybase, key_name_(), (REGSAM)access | (REGSAM)m_accessfix, option);
                    }
                }
                else {
                    key = open_key_(m_keybase, key_name_(), (REGSAM)access | (REGSAM)m_accessfix, option);
                }
            }
            else {
                assert(access == open_access::read);
                open_option option = open_option::fail_if_not_exists;
                if (m_key) {
                    key = m_key;
                }
                else {
                    key = open_key_(m_keybase, key_name_(), (REGSAM)access | (REGSAM)m_accessfix, option);
                }
            }

            if (!key)
                return false;
            m_key = key;
            m_access = access;
            return true;
        }

        string_type key_name_() {
            static const char_type s_separator[] = {'\\', '\0'};
            return m_keypath.empty() ? m_keyname : m_keypath + s_separator + m_keyname;
        }

        void close_key_() {
            traits_type::close(m_key);
            m_key = NULL;
            m_access = open_access::read;
        }

        static hkey_type open_key_(hkey_type key_parent, const string_type& key_name, REGSAM access_mask, open_option option) {
            if (option == open_option::fail_if_not_exists) {
                hkey_type   hkey;
                result_type res = traits_type::open_key(key_parent, key_name.c_str(), &hkey, access_mask);
                check_and_throw_exception("could not open key", res);
                return hkey;
            }
            else {
                assert(option == open_option::create_if_not_exists);
                static const char_type s_empty_string[] = {'\0'};
                hkey_type              hbasekey;
                hkey_type              hkey;
                result_type            res = traits_type::open_key(key_parent, s_empty_string, &hbasekey, KEY_CREATE_SUB_KEY);
                check_and_throw_exception("could not open key", res);
                res = traits_type::create_key(hbasekey, key_name.c_str(), &hkey, access_mask);
                check_and_throw_exception("could not create sub-key", res);
                return hkey;
            }
        }

        static hkey_type dup_key_(hkey_type hkey, open_access access_mask) {
            if (NULL == hkey)
                return NULL;
            result_type res;
            hkey_type   hkey_dup = traits_type::dup_key(hkey, access_mask, &res);
            check_and_throw_exception("could not duplicate key", res);
            return hkey_dup;
        }

    protected:
        hkey_type      m_keybase;
        string_type    m_keypath;
        string_type    m_keyname;
        hkey_type      m_key;
        open_access    m_access;
        open_access    m_accessfix;
        value_map_type m_valuemap;
    };

    template <typename C, typename T>
    inline basic_key<C, T>
    operator/(const basic_key<C, T>&                       lhs,
              const typename basic_key<C, T>::string_type& rhs) {
        return lhs.key(rhs);
    }

    typedef basic_key<char>    key_a;
    typedef basic_key<wchar_t> key_w;

    class predefined_key {
    public:
        typedef HKEY hkey_type;
        predefined_key(hkey_type hkey) : m_hkey(hkey) {}
        hkey_type handle() const { return m_hkey; }

    private:
        hkey_type m_hkey;
    };

    template <typename C>
    inline basic_key<C> operator/(const predefined_key&       lhs,
                                  const std::basic_string<C>& rhs) {
        return basic_key<C>(lhs.handle(), rhs);
    }

    template <typename C>
    inline basic_key<C> operator/(const predefined_key& lhs, const C* rhs) {
        return basic_key<C>(lhs.handle(), basic_key<C>::string_type(), rhs, open_access::none);
    }

    inline predefined_key current_user() {
        return predefined_key(HKEY_CURRENT_USER);
    }

    inline predefined_key local_machine() {
        return predefined_key(HKEY_LOCAL_MACHINE);
    }
}
