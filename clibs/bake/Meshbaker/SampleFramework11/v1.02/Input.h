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

namespace SampleFramework11
{

struct KeyState
{
    bool Pressed;
    bool RisingEdge;
    bool FallingEdge;

    KeyState();
};

class MouseState
{

public:

    MouseState();

    static MouseState GetMouseState(HWND hwnd = NULL);
    static void SetCursorPos(int x, int y, HWND hwnd = NULL);

    int X;
    int Y;
    int DX;
    int DY;

    KeyState LButton;
    KeyState MButton;
    KeyState RButton;

    bool IsOverWindow;

private:

    static MouseState prevState;
};

class KeyboardState
{

public:

    enum Keys
    {
        A = 0x41,
        Add = 0x6b,
        Apps = 0x5d,
        Attn = 0xf6,
        B = 0x42,
        Back = 8,
        BrowserBack = 0xa6,
        BrowserFavorites = 0xab,
        BrowserForward = 0xa7,
        BrowserHome = 0xac,
        BrowserRefresh = 0xa8,
        BrowserSearch = 170,
        BrowserStop = 0xa9,
        C = 0x43,
        CapsLock = 20,
        ChatPadGreen = 0xca,
        ChatPadOrange = 0xcb,
        Crsel = 0xf7,
        D = 0x44,
        D0 = 0x30,
        D1 = 0x31,
        D2 = 50,
        D3 = 0x33,
        D4 = 0x34,
        D5 = 0x35,
        D6 = 0x36,
        D7 = 0x37,
        D8 = 0x38,
        D9 = 0x39,
        Decimal = 110,
        Delete = 0x2e,
        Divide = 0x6f,
        Down = 40,
        E = 0x45,
        End = 0x23,
        Enter = 13,
        EraseEof = 0xf9,
        Escape = 0x1b,
        Execute = 0x2b,
        Exsel = 0xf8,
        F = 70,
        F1 = 0x70,
        F10 = 0x79,
        F11 = 0x7a,
        F12 = 0x7b,
        F13 = 0x7c,
        F14 = 0x7d,
        F15 = 0x7e,
        F16 = 0x7f,
        F17 = 0x80,
        F18 = 0x81,
        F19 = 130,
        F2 = 0x71,
        F20 = 0x83,
        F21 = 0x84,
        F22 = 0x85,
        F23 = 0x86,
        F24 = 0x87,
        F3 = 0x72,
        F4 = 0x73,
        F5 = 0x74,
        F6 = 0x75,
        F7 = 0x76,
        F8 = 0x77,
        F9 = 120,
        G = 0x47,
        H = 0x48,
        Help = 0x2f,
        Home = 0x24,
        I = 0x49,
        ImeConvert = 0x1c,
        ImeNoConvert = 0x1d,
        Insert = 0x2d,
        J = 0x4a,
        K = 0x4b,
        Kana = 0x15,
        Kanji = 0x19,
        L = 0x4c,
        LaunchApplication1 = 0xb6,
        LaunchApplication2 = 0xb7,
        LaunchMail = 180,
        Left = 0x25,
        LeftAlt = 0xa4,
        LeftControl = 0xa2,
        LeftShift = 160,
        LeftWindows = 0x5b,
        M = 0x4d,
        MediaNextTrack = 0xb0,
        MediaPlayPause = 0xb3,
        MediaPreviousTrack = 0xb1,
        MediaStop = 0xb2,
        Multiply = 0x6a,
        N = 0x4e,
        None = 0,
        NumLock = 0x90,
        NumPad0 = 0x60,
        NumPad1 = 0x61,
        NumPad2 = 0x62,
        NumPad3 = 0x63,
        NumPad4 = 100,
        NumPad5 = 0x65,
        NumPad6 = 0x66,
        NumPad7 = 0x67,
        NumPad8 = 0x68,
        NumPad9 = 0x69,
        O = 0x4f,
        Oem8 = 0xdf,
        OemAuto = 0xf3,
        OemBackslash = 0xe2,
        OemClear = 0xfe,
        OemCloseBrackets = 0xdd,
        OemComma = 0xbc,
        OemCopy = 0xf2,
        OemEnlW = 0xf4,
        OemMinus = 0xbd,
        OemOpenBrackets = 0xdb,
        OemPeriod = 190,
        OemPipe = 220,
        OemPlus = 0xbb,
        OemQuestion = 0xbf,
        OemQuotes = 0xde,
        OemSemicolon = 0xba,
        OemTilde = 0xc0,
        P = 80,
        Pa1 = 0xfd,
        PageDown = 0x22,
        PageUp = 0x21,
        Pause = 0x13,
        Play = 250,
        Print = 0x2a,
        PrintScreen = 0x2c,
        ProcessKey = 0xe5,
        Q = 0x51,
        R = 0x52,
        Right = 0x27,
        RightAlt = 0xa5,
        RightControl = 0xa3,
        RightShift = 0xa1,
        RightWindows = 0x5c,
        S = 0x53,
        Scroll = 0x91,
        Select = 0x29,
        SelectMedia = 0xb5,
        Separator = 0x6c,
        Sleep = 0x5f,
        Space = 0x20,
        Subtract = 0x6d,
        T = 0x54,
        Tab = 9,
        U = 0x55,
        Up = 0x26,
        V = 0x56,
        VolumeDown = 0xae,
        VolumeMute = 0xad,
        VolumeUp = 0xaf,
        W = 0x57,
        X = 0x58,
        Y = 0x59,
        Z = 90,
        Zoom = 0xfb
    };

public:

    KeyState GetKeyState(Keys key) const;
    bool IsKeyDown(Keys key) const;
    bool RisingEdge(Keys key) const;

    static KeyboardState GetKeyboardState(HWND hwnd);

private:

    KeyState keyStates[256];

    static KeyboardState prevState;
    static BYTE currState[256];

    static inline bool KeyPressed(BYTE value) { return (value & 0x80) > 0; };
};



}