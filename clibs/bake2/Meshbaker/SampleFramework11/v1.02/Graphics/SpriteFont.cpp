//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "SpriteFont.h"

#include "..\\Utility.h"

using namespace Gdiplus;
using std::wstring;
using std::vector;

namespace SampleFramework11
{

SpriteFont::SpriteFont()
    :   size(0),
        texHeight(0),
        spaceWidth(0),
        charHeight(0)
{

}

SpriteFont::~SpriteFont()
{

}

void SpriteFont::Initialize(LPCWSTR fontName, float fontSize, UINT fontStyle, bool antiAliased, ID3D11Device* device)
{
    size = fontSize;

    TextRenderingHint hint = antiAliased ? TextRenderingHintAntiAliasGridFit : TextRenderingHintSingleBitPerPixelGridFit;

    // Init GDI+
    ULONG_PTR token = NULL;
    GdiplusStartupInput startupInput (NULL, true, true);
    GdiplusStartupOutput startupOutput;
    GdiPlusCall(GdiplusStartup(&token, &startupInput, &startupOutput));

    try
    {
        // Create the font
        Gdiplus::Font font(fontName, fontSize, fontStyle, UnitPixel, NULL);

        // Check for error during construction
        GdiPlusCall(font.GetLastStatus());

        // Create a temporary Bitmap and Graphics for figuring out the rough size required
        // for drawing all of the characters
        int size = static_cast<int>(fontSize * NumChars * 2) + 1;
        Bitmap sizeBitmap(size, size, PixelFormat32bppARGB);
        GdiPlusCall(sizeBitmap.GetLastStatus());

        Graphics sizeGraphics(&sizeBitmap);
        GdiPlusCall(sizeGraphics.GetLastStatus());
        GdiPlusCall(sizeGraphics.SetTextRenderingHint(hint));

        charHeight = font.GetHeight(&sizeGraphics) * 1.5f;

        wchar allChars[NumChars + 1];
        for(wchar i = 0; i < NumChars; ++i)
            allChars[i] = i + StartChar;
        allChars[NumChars] = 0;

        RectF sizeRect;
        GdiPlusCall(sizeGraphics.MeasureString(allChars, NumChars, &font, PointF(0, 0), &sizeRect));
        int numRows = static_cast<int>(sizeRect.Width / TexWidth) + 1;
        int texHeight = static_cast<int>(numRows * charHeight) + 1;

        // Create a temporary Bitmap and Graphics for drawing the characters one by one
        int tempSize = static_cast<int>(fontSize * 2);
        Bitmap drawBitmap(tempSize, tempSize, PixelFormat32bppARGB);
        GdiPlusCall(drawBitmap.GetLastStatus());

        Graphics drawGraphics(&drawBitmap);
        GdiPlusCall(drawGraphics.GetLastStatus());
        GdiPlusCall(drawGraphics.SetTextRenderingHint(hint));

        // Create a temporary Bitmap + Graphics for creating a full character set
        Bitmap textBitmap (TexWidth, texHeight, PixelFormat32bppARGB);
        GdiPlusCall(textBitmap.GetLastStatus());

        Graphics textGraphics (&textBitmap);
        GdiPlusCall(textGraphics.GetLastStatus());
        GdiPlusCall(textGraphics.Clear(Color(0, 255, 255, 255)));
        GdiPlusCall(textGraphics.SetCompositingMode(CompositingModeSourceCopy));

        // Solid brush for text rendering
        SolidBrush brush (Color(255, 255, 255, 255));
        GdiPlusCall(brush.GetLastStatus());

        // Draw all of the characters, and copy them to the full character set
        wchar charString [2];
        charString[1] = 0;
        int currentX = 0;
        int currentY = 0;
        for(uint64 i = 0; i < NumChars; ++i)
        {
            charString[0] = static_cast<wchar>(i + StartChar);

            // Draw the character
            GdiPlusCall(drawGraphics.Clear(Color(0, 255, 255, 255)));
            GdiPlusCall(drawGraphics.DrawString(charString, 1, &font, PointF(0, 0), &brush));

            // Figure out the amount of blank space before the character
            int minX = 0;
            for(int x = 0; x < tempSize; ++x)
            {
                for(int y = 0; y < tempSize; ++y)
                {
                    Color color;
                    GdiPlusCall(drawBitmap.GetPixel(x, y, &color));
                    if(color.GetAlpha() > 0)
                    {
                        minX = x;
                        x = tempSize;
                        break;
                    }
                }
            }

            // Figure out the amount of blank space after the character
            int maxX = tempSize - 1;
            for(int x = tempSize - 1; x >= 0; --x)
            {
                for(int y = 0; y < tempSize; ++y)
                {
                    Color color;
                    GdiPlusCall(drawBitmap.GetPixel(x, y, &color));
                    if(color.GetAlpha() > 0)
                    {
                        maxX = x;
                        x = -1;
                        break;
                    }
                }
            }

            int charWidth = maxX - minX + 1;

            // Figure out if we need to move to the next row
            if (currentX + charWidth >= TexWidth)
            {
                currentX = 0;
                currentY += static_cast<int>(charHeight) + 1;
            }

            // Fill out the structure describing the character position
            charDescs[i].X = static_cast<float>(currentX);
            charDescs[i].Y = static_cast<float>(currentY);
            charDescs[i].Width = static_cast<float>(charWidth);
            charDescs[i].Height = static_cast<float>(charHeight);

            // Copy the character over
            int height = static_cast<int>(charHeight + 1);
            GdiPlusCall(textGraphics.DrawImage(&drawBitmap, currentX, currentY, minX, 0, charWidth, height, UnitPixel));

            currentX += charWidth + 1;
        }

        // Figure out the width of a space character
        charString[0] = ' ';
        charString[1] = 0;
        GdiPlusCall(drawGraphics.MeasureString(charString, 1, &font, PointF(0, 0), &sizeRect));
        spaceWidth = sizeRect.Width;

        // Lock the bitmap for direct memory access
        BitmapData bmData;
        auto rt = Gdiplus::Rect(0, 0, TexWidth, texHeight);
        GdiPlusCall(textBitmap.LockBits(&rt, ImageLockModeRead, PixelFormat32bppARGB, &bmData));

        // Create a D3D texture, initalized with the bitmap data
        D3D11_TEXTURE2D_DESC texDesc;
        texDesc.Width = TexWidth;
        texDesc.Height = texHeight;
        texDesc.MipLevels = 1;
        texDesc.ArraySize = 1;
        texDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        texDesc.SampleDesc.Count = 1;
        texDesc.SampleDesc.Quality = 0;
        texDesc.Usage = D3D11_USAGE_IMMUTABLE;
        texDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
        texDesc.CPUAccessFlags = 0;
        texDesc.MiscFlags = 0;

        D3D11_SUBRESOURCE_DATA data;
        data.pSysMem = bmData.Scan0;
        data.SysMemPitch = TexWidth * 4;
        data.SysMemSlicePitch = 0;

        DXCall(device->CreateTexture2D(&texDesc, &data, &texture));

        GdiPlusCall(textBitmap.UnlockBits(&bmData));

        // Create the shader resource view
        D3D11_SHADER_RESOURCE_VIEW_DESC srDesc;
        srDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        srDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
        srDesc.Texture2D.MipLevels = 1;
        srDesc.Texture2D.MostDetailedMip = 0;

        DXCall(device->CreateShaderResourceView(texture, &srDesc, &srView));
    }
    catch (GdiPlusException e)
    {
        // Shutdown GDI+
        if (token != NULL)
            GdiplusShutdown(token);
        throw e;
    }

    // Shutdown GDI+
    GdiplusShutdown(token);
}

ID3D11ShaderResourceView* SpriteFont::SRView() const
{
    return srView;
}

const SpriteFont::CharDesc* SpriteFont::CharDescriptors() const
{
    return charDescs;
}

const SpriteFont::CharDesc& SpriteFont::GetCharDescriptor(wchar character) const
{
    _ASSERT(character >= StartChar && character <= EndChar);
    return charDescs[character - StartChar];
}

float SpriteFont::Size() const
{
    return size;
}

UINT SpriteFont::TextureWidth() const
{
    return TexWidth;
}

UINT SpriteFont::TextureHeight() const
{
    return texHeight;
}

float SpriteFont::SpaceWidth() const
{
    return spaceWidth;
}

float SpriteFont::CharHeight() const
{
    return charHeight;
}

ID3D11Texture2D* SpriteFont::Texture() const
{
    return texture;
}

Float2 SpriteFont::MeasureText(const wchar* text) const
{
    Float2 size = Float2(0.0f, 0.0f);
    Float2 curPos = Float2(0.0f, 0.0f);;

    size_t length = wcslen(text);

    for (uint64 i = 0; i < length; ++i)
    {
        wchar character = text[i];
        if(character == ' ')
            curPos.x += SpaceWidth();
        else if(character == '\n')
        {
            curPos.y += CharHeight();
            curPos.x = 0;
        }
        else
        {
            SpriteFont::CharDesc desc = GetCharDescriptor(character);
            curPos.x += desc.Width + 1;
        }

        size.x = std::max(curPos.x, size.x);
        size.y = std::max(curPos.y, size.y);
    }

    return size;
}

}