#include <string>
#include <codecvt>
#include <algorithm>

static std::wstring
toutf16(const std::string &s){
    return std::wstring_convert<
        std::codecvt<wchar_t, char, std::mbstate_t>, wchar_t>().from_bytes(s);
}

static std::string
toutf8(const std::wstring &ws){
    return std::wstring_convert<
        std::codecvt<wchar_t, char, std::mbstate_t>, wchar_t>().to_bytes(ws);
}

static std::wstring
bigendian_to_smallendian(const std::string &s){
    if (s.size() % 2){
        return std::wstring();
    }

    std::wstring ws; ws.reserve(s.size()/ 2);
    for (int ii=0; ii < s.size(); ii+=2){
        wchar_t wc = (s[ii] << 8)|s[ii+1];
        ws.push_back(wc);
    }

    return ws;
}

extern "C" {
    void
    cvt_name_info(const char* name, size_t numbytes, char *newname, size_t maxbytes, int needcvt){
        auto cp = [maxbytes](char *d, const char* s, size_t num){
            memcpy(d, s, std::min(sizeof(char) * num, maxbytes));
        };

        if(needcvt){
            auto s = toutf8(bigendian_to_smallendian(name));
            if (!s.empty()){
                cp(newname, &s[0], s.size());
            }
        }else {
            cp(newname, name, numbytes);
        }
    }
}


/*

#define STB_TRUETYPE_IMPLEMENTATION
extern "C"{
    #include <stb/stb_truetype.h>
}

#include <string>
#include <list>
#include <fstream>
#include <iostream>
#include <vector>

#include <codecvt>

static std::wstring
toutf16(const std::string &s){
    return std::wstring_convert<
        std::codecvt<wchar_t, char, std::mbstate_t>, wchar_t>().from_bytes(s);
}

static std::string
toutf8(const std::wstring &ws){
    return std::wstring_convert<
        std::codecvt<wchar_t, char, std::mbstate_t>, wchar_t>().to_bytes(ws);
}

static inline std::string
remap_name_data(const NameTableInfo &nti){
    auto remap_bigendian_str = [](const std::string &s){
        if (s.size() % 2){
            return std::wstring();
        }

        std::wstring ws; ws.reserve(s.size()/ 2);
        for (int ii=0; ii < s.size(); ii+=2){
            wchar_t wc = s[ii] << 8|s[ii+1];
            ws.push_back(wc);
        }

        return ws;
    };
    switch (nti.platformID){
    case STBTT_PLATFORM_ID_UNICODE:{
        return toutf8(remap_bigendian_str(nti.data));
    }
    case STBTT_PLATFORM_ID_MAC:
        return nti.data;
    case STBTT_PLATFORM_ID_MICROSOFT:
        switch (nti.encodingID){
            case STBTT_MS_EID_UNICODE_BMP:
            case STBTT_MS_EID_UNICODE_FULL:
            return toutf8(remap_bigendian_str(nti.data));
            default: return nti.data;
        }
        break;
    case STBTT_PLATFORM_ID_ISO:
    default:
        return std::string();
    }
}

static void
list_tt_name_table(const stbtt_fontinfo *font, NameTableList &nt){
    stbtt_int32 i,count,stringOffset;
    stbtt_uint8 *fc = font->data;
    stbtt_uint32 offset = font->fontstart;
    stbtt_uint32 nm = stbtt__find_table(fc, offset, "name");
    if (!nm) 
        return ;
 
    count = ttUSHORT(fc+nm+2);
    stringOffset = nm + ttUSHORT(fc+nm+4);
    const char* ntp = (const char*)(fc + stringOffset);
    for (i=0; i < count; ++i) {
        stbtt_uint32 loc = nm + 6 + 12 * i;
        NameTableInfo nti;

        nti.platformID   = ttUSHORT(fc+loc+0); 
        nti.encodingID   = ttUSHORT(fc+loc+2);
        nti.languageID   = ttUSHORT(fc+loc+4);
        nti.nameID       = ttUSHORT(fc+loc+6);

        uint16_t namelen = ttUSHORT(fc+loc+8);
        auto p           = ntp+ttUSHORT(fc+loc+10);
        nti.data         = std::string(p, p+namelen);
        nti.data         = remap_name_data(nti);
        nt.push_back(nti);
    }
}

#ifdef FONT_TOOL
static const char* PLATFORM_NAMES[] = {
    "UNICODE",
    "MAC",
    "ISO",
    "MICROSOFT",
};

static uint16_t PLATFORM_NUM = sizeof(PLATFORM_NAMES)/sizeof(PLATFORM_NAMES[0]);

int main(int argc, const char*argv[]){
    if (argc < 2){
        std::cerr << "at least one argument: truetype/open type font with ttf/ott file" << std::endl;
        return 1;
    }
    const char* filename = argv[1];
    std::ifstream iff(filename, std::ios::binary);
    if (!iff){
        std::cerr << "" << std::endl;
        return 2;
    }

    iff.seekg(0, std::ios::end);
    const size_t sizebytes = iff.tellg();
    iff.seekg(0, std::ios::beg);

    std::unique_ptr<char>   ptr(new char[sizebytes]);
    iff.read(ptr.get(), sizebytes);

    auto p = (const uint8_t*)ptr.get();

    auto numfonts = stbtt_GetNumberOfFonts(p);

    std::list<NameTableList> ntll;
    for (auto ii=0; ii<numfonts; ++ii){
        stbtt_fontinfo fi;
        int fontid = stbtt_InitFont(&fi, (const uint8_t*)ptr.get(), 0);
        NameTableList ll;
        list_tt_name_table(&fi, ll);
        ntll.push_back(ll);
    }

    for (auto ll: ntll){
        for (auto nti : ll){
            const char* platname = nti.platformID < PLATFORM_NUM ? PLATFORM_NAMES[nti.platformID] : "unknown_platform";

            std::cout   << "platform: " << platname << "\tencoding: " << nti.encodingID << "\tlanguage: " << nti.languageID << "\tnameID: " << nti.nameID << std::endl 
                        << "data: " << nti.data << std::endl;
        }
    }

    return 0;
}
#endif //FONT_TOOL
*/