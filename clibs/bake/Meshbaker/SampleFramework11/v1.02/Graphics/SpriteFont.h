//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"

#include "..\\InterfacePointers.h"
#include "..\\SF11_Math.h"

namespace SampleFramework11
{

class SpriteFont
{

public:

    enum FontStyle
    {
        Regular = 0,
        Bold = 1 << 0,
        Italic = 1 << 1,
        BoldItalic = Bold | Italic,
        Underline = 1 << 2,
        Strikeout = 1 << 3
    };

    struct CharDesc
    {
        float X;
        float Y;
        float Width;
        float Height;
    };

    static const wchar StartChar = '!';
    static const wchar EndChar = 127;
    static const uint64 NumChars = EndChar - StartChar;
    static const UINT TexWidth = 1024;

    // Lifetime
    SpriteFont();
    ~SpriteFont();

    void Initialize(LPCWSTR fontName, float fontSize, UINT fontStyle, bool antiAliased, ID3D11Device* device);

    Float2 MeasureText(const wchar* text) const;

    // Accessors
    ID3D11ShaderResourceView* SRView() const;
    const CharDesc* CharDescriptors() const;
    const CharDesc& GetCharDescriptor(wchar character) const;
    float Size() const;
    ID3D11Texture2D* Texture() const;
    UINT TextureWidth() const;
    UINT TextureHeight() const;
    float SpaceWidth() const;
    float CharHeight() const;

protected:

    ID3D11Texture2DPtr texture;
    ID3D11ShaderResourceViewPtr srView;
    CharDesc charDescs [NumChars];
    float size;
    UINT texHeight;
    float spaceWidth;
    float charHeight;
};

}