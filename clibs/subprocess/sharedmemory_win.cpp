#include "sharedmemory_win.h"
#include <Windows.h>

namespace ant::win::subprocess {
    typedef enum _SECTION_INFORMATION_CLASS
    {
        SectionBasicInformation,
        SectionImageInformation
    } SECTION_INFORMATION_CLASS;
    typedef struct _SECTION_BASIC_INFORMATION {
        PVOID         base;
        ULONG         attributes;
        LARGE_INTEGER size;
    } SECTION_BASIC_INFORMATION;
    typedef DWORD(WINAPI* NTQUERYSECTION) (HANDLE, SECTION_INFORMATION_CLASS, PVOID, ULONG, PULONG);

    static bool get_file_mapping_size(HANDLE handle, size_t& size) {
        if (HMODULE dll = GetModuleHandleW(L"ntdll.dll")) {
            NTQUERYSECTION pNtQuerySection = (NTQUERYSECTION)GetProcAddress(dll, "NtQuerySection");
            if (pNtQuerySection) {
                SECTION_BASIC_INFORMATION SectionInfo;
                DWORD ntstatus = pNtQuerySection(handle, SectionBasicInformation, &SectionInfo, sizeof(SectionInfo), 0);
#if defined(_WIN64)
                size = SectionInfo.size.QuadPart;
#else
                if (SectionInfo.size.HighPart != 0) {
                    return false;
                }
                size = SectionInfo.size.LowPart;
#endif
                return !ntstatus;
            }
        }
        return false;
    }

    filemapping::filemapping(open_only_t, const wchar_t* name)
        : m_handle(open(name))
    { }
    filemapping::filemapping(create_only_t, const wchar_t* name, size_t size)
        : m_handle(create(name, size))
    { }
    filemapping::~filemapping() {
        close();
    }
    bool filemapping::ok() const { 
        return !!m_handle;
    }
    HANDLE filemapping::handle() const {
        return m_handle; 
    }
    void* filemapping::create(const wchar_t* name, size_t size) {
        ULARGE_INTEGER ui;
        ui.QuadPart = static_cast<ULONGLONG>(size);
        return ::CreateFileMappingW(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, ui.HighPart, ui.LowPart, name);
    }
    void* filemapping::open(const wchar_t* name) {
        return ::OpenFileMappingW(SECTION_MAP_WRITE | SECTION_QUERY, FALSE, name);
    }
    void filemapping::close() {
        if (m_handle) {
            ::CloseHandle(m_handle);
            m_handle = 0;
        }
    }

    sharedmemory::sharedmemory(open_only_t, const wchar_t* name)
        : m_mapping(open_only, name)
        , m_data(0)
        , m_size(0)
    {
        if (m_mapping.ok()) {
            mapview();
        }
    }
    sharedmemory::sharedmemory(create_only_t, const wchar_t* name, size_t size)
        : m_mapping(create_only, name, size)
        , m_data(0)
        , m_size(0)
    {
        if (m_mapping.ok()) {
            if (GetLastError() == ERROR_ALREADY_EXISTS) {
                m_mapping.close();
            }
            else {
                mapview();
            }
        }
    }
    sharedmemory::sharedmemory(open_or_create_t, const wchar_t* name, size_t size)
        : m_mapping(create_only, name, size)
        , m_data(0)
        , m_size(0)
    {
        if (m_mapping.ok()) {
            mapview();
        }
    }
    sharedmemory::~sharedmemory() {
        if (m_data) {
            ::UnmapViewOfFile(m_data);
        }
    }
    bool sharedmemory::ok()   const { 
        return !!m_data; 
    }
    void* sharedmemory::handle() const {
        return m_mapping.handle();
    }
    std::byte* sharedmemory::data() { 
        return m_data;
    }
    size_t sharedmemory::size() const { 
        return m_size;
    }
    void sharedmemory::mapview() {
        if (!get_file_mapping_size(m_mapping.handle(), m_size)) {
            return;
        }
        m_data = (std::byte*)::MapViewOfFile(m_mapping.handle(), SECTION_MAP_WRITE | SECTION_QUERY, 0, 0, m_size);
    }
}
