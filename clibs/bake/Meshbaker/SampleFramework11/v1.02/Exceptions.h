//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "PCH.h"
#include "Graphics\\DXErr.h"
#include "Assert_.h"

namespace SampleFramework11
{

// Error string functions
inline std::wstring GetWin32ErrorString(DWORD errorCode)
{
    wchar errorString[MAX_PATH];
    ::FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,
                    0,
                    errorCode,
                    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                    errorString,
                    MAX_PATH,
                    NULL  );

    std::wstring message = L"Win32 Error: ";
    message += errorString;
    return message;
}

inline std::string GetWin32ErrorStringAnsi(DWORD errorCode)
{
    char errorString[MAX_PATH];
    ::FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM,
                     0,
                     errorCode,
                     MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                     errorString,
                     MAX_PATH,
                     NULL  );

    std::string message = "Win32 Error: ";
    message += errorString;
    return message;
}

inline std::wstring GetDXErrorString(HRESULT hr)
{
    const uint32 errStringSize = 1024;
    wchar errorString[errStringSize];
    DXGetErrorDescriptionW(hr, errorString, errStringSize);

    std::wstring message = L"DirectX Error: ";
    message += errorString;
    return message;
}

inline std::string GetDXErrorStringAnsi(HRESULT hr)
{
    std::wstring errorString = GetDXErrorString(hr);

    std::string message;
    for(uint64 i = 0; i < errorString.length(); ++i)
        message.append(1, static_cast<char>(errorString[i]));
    return message;
}

inline std::wstring GetGdiPlusErrorString(Gdiplus::Status status)
{
    std::wstring errorString;

    if (status == Gdiplus::GenericError)
        errorString = L"Generic Error";
    else if (status == Gdiplus::InvalidParameter)
        errorString = L"Invalid Parameter";
    else if (status == Gdiplus::OutOfMemory)
        errorString = L"Out Of Memory";
    else if (status == Gdiplus::ObjectBusy)
        errorString = L"Object Busy";
    else if (status == Gdiplus::InsufficientBuffer)
        errorString = L"Insufficient Buffer";
    else if (status == Gdiplus::NotImplemented)
        errorString = L"Not Implemented";
    else if (status == Gdiplus::Win32Error)
        errorString = L"Win32 Error";
    else if (status == Gdiplus::WrongState)
        errorString = L"Wrong State";
    else if (status == Gdiplus::Aborted)
        errorString = L"Aborted";
    else if (status == Gdiplus::FileNotFound)
        errorString = L"File Not Found";
    else if (status == Gdiplus::ValueOverflow)
        errorString = L"Value Overflow";
    else if (status == Gdiplus::AccessDenied)
        errorString = L"Access Denied";
    else if (status == Gdiplus::UnknownImageFormat)
        errorString = L"Unknown Image Format";
    else if (status == Gdiplus::FontFamilyNotFound)
        errorString = L"Font Family Not Found";
    else if (status == Gdiplus::FontStyleNotFound)
        errorString = L"Font Style Not Found";
    else if (status == Gdiplus::NotTrueTypeFont)
        errorString = L"Not TrueType Font";
    else if (status == Gdiplus::UnsupportedGdiplusVersion)
        errorString = L"Unsupported GDI+ Version";
    else if (status == Gdiplus::GdiplusNotInitialized)
        errorString = L"GDI+ Not Initialized";
    else if (status == Gdiplus::PropertyNotFound)
        errorString = L"Property Not Found";
    else if (status == Gdiplus::PropertyNotSupported)
        errorString = L"Property Not Supported";

    return L"GDI+ Error: " + errorString;
}

inline std::string GetGdiPlusErrorStringAnsi(Gdiplus::Status status)
{
    std::wstring errorString = GetDXErrorString(status);
    std::string message;
    for(uint64 i = 0; i < errorString.length(); ++i)
        message.append(1, static_cast<char>(errorString[i]));
    return message;
}

// Generic exception, used as base class for other types
class Exception
{

public:

    Exception()
    {
    }

    // Specify an actual error message
    Exception(const std::wstring& exceptionMessage) : message(exceptionMessage)
    {
    }

    Exception(const std::string& exceptionMessage)
    {
        wchar buffer[512];
        MultiByteToWideChar(CP_ACP, 0, exceptionMessage.c_str(), -1, buffer, 512);
        message = std::wstring(buffer);
    }

    // Retrieve that error message
    const std::wstring& GetMessage() const throw()
    {
        return message;
    }

    void ShowErrorMessage() const throw ()
    {
        MessageBox(NULL, message.c_str(), L"Error", MB_OK|MB_ICONERROR);
    }

protected:

    std::wstring  message;    // The error message
};

// Exception thrown when a Win32 function fails.
class Win32Exception : public Exception
{

public:

    // Obtains a string for the specified Win32 error code
    Win32Exception(DWORD code, const wchar* msgPrefix = nullptr) : errorCode(code)
    {
        wchar errorString[MAX_PATH];
        ::FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,
                        0,
                        errorCode,
                        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                        errorString,
                        MAX_PATH,
                        NULL  );

        message = L"Win32 Error: ";
        if(msgPrefix)
            message += msgPrefix;
        message += errorString;
    }

    // Retrieve the error code
    DWORD GetErrorCode() const throw ()
    {
        return errorCode;
    }

protected:

  DWORD  errorCode;    // The Win32 error code

};

// Exception thrown when a DirectX Function fails
class DXException : public Exception
{

public:

    // Obtains a string for the specified HRESULT error code
    DXException(HRESULT hresult) : errorCode(hresult)
    {
        message = GetDXErrorString(hresult);
    }

    DXException(HRESULT hresult, LPCWSTR errorMsg) : errorCode(hresult)
    {
        message = L"DirectX Error: ";
        message += errorMsg;
    }

    // Retrieve the error code
    HRESULT GetErrorCode() const throw ()
    {
        return errorCode;
    }

protected:

    HRESULT errorCode;    // The DX error code
};

// Exception thrown when a GDI+ function fails
class GdiPlusException : public Exception
{

public:

    // Obtains a string for the specified error code
    GdiPlusException(Gdiplus::Status status) : errorCode(status)
    {
        message = GetGdiPlusErrorString(status);
    }

    // Retrieve the error code
    Gdiplus::Status GetErrorCode() const throw ()
    {
        return errorCode;
    }

protected:

    Gdiplus::Status  errorCode;    // The GDI+ error code
};

// Error-handling functions

#if UseAsserts_

#define DXCall(x)                                                           \
    do                                                                      \
    {                                                                       \
        HRESULT hr_ = x;                                                    \
        AssertMsg_(SUCCEEDED(hr_), GetDXErrorStringAnsi(hr_).c_str());      \
    }                                                                       \
    while(0)

#define Win32Call(x)                                                            \
    do                                                                          \
    {                                                                           \
        BOOL res_ = x;                                                          \
        AssertMsg_(res_ != 0, GetWin32ErrorStringAnsi(GetLastError()).c_str()); \
    }                                                                           \
    while(0)

#define GdiPlusCall(x)                                                                  \
    do                                                                                  \
    {                                                                                   \
        Gdiplus::Status status_ = x;                                                    \
        AssertMsg_(status_ == Gdiplus::Ok, GetGdiPlusErrorStringAnsi(status_).c_str()); \
    }                                                                                   \
    while(0)

#define TwCall(x)                                                           \
    do                                                                      \
    {                                                                       \
        int res_ = x;                                                       \
        AssertMsg_(res_ != 0, GetTwErrorStringAnsi().c_str());              \
    }                                                                       \
    while(0)


#else

// Throws a DXException on failing HRESULT
inline void DXCall(HRESULT hr)
{
    if(FAILED(hr))
        throw DXException(hr);
}

// Throws a Win32Exception on failing return value
inline void Win32Call(BOOL retVal)
{
    if(retVal == 0)
        throw Win32Exception(GetLastError());
}

// Throws a GdiPlusException on failing Status value
inline void GdiPlusCall(Gdiplus::Status status)
{
    if(status != Gdiplus::Ok)
        throw GdiPlusException(status);
}

// Throws an AntException on failing return value
inline void TwCall(int retVal)
{
    if(retVal == 0)
        throw TwException();
}

#endif

}