#include <cstdio>
#include <thread>
#include <chrono>

#include <X11/keysymdef.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>

#include <bee/thread/simplethread.h>
#include <bee/nonstd/unreachable.h>
#include "imgui.h"
#include "../../window.h"
#include "../../../../clibs/imgui/backend/imgui_impl_x11.h"

const int CONFIG_EVENT_MAX_WAIT_TIME = 5; // ms
const int XC_INPUT_BUFF_LEN = 16;

struct ThreadContext
{
    WindowContext *win_ctx;
    lua_State *L;
};

struct Modifier
{
    enum Enum
    {
        ModifierNone = 0,
        LeftAlt = 0x01,
        RightAlt = 0x02,
        LeftCtrl = 0x04,
        RightCtrl = 0x08,
        LeftShift = 0x10,
        RightShift = 0x20,
        LeftSuper = 0x40,
        RightSuper = 0x80,
    };
};

struct Rect
{
    int x;
    int y;
    int w;
    int h;
};

struct ConfigEventState
{
    bool received;
    int64_t received_time;
    int x;
    int y;
    int w;
    int h;
};

static WindowContext s_win_ctx;
static ThreadContext s_thread_ctx;
static bee::thread_handle s_thread_h;
static ConfigEventState s_config_event = {};
static Atom s_wm_deleted_window;

static int64_t now_ms()
{
    struct timeval now;
    gettimeofday(&now, 0);
    int64_t t = now.tv_sec * INT64_C(1000) + now.tv_usec / 1000;
    return t;
}

static ant::window::mouse_button to_ant_mouse_button(unsigned int button)
{
    switch (button)
    {
        {
        case Button1:
            return ant::window::mouse_button::left;
            break;
        case Button2:
            return ant::window::mouse_button::middle;
            break;
        case Button3:
            return ant::window::mouse_button::right;
            break;
        default:
            return ant::window::mouse_button::right; // TODO: maybe we should add other button type in mouse_button enum
        }
    }
}

static ImGuiKey ToImGuiKey(const KeySym &keysym)
{
    switch (keysym)
    {
    case XK_Tab:
        return ImGuiKey_Tab;
    case XK_Left:
        return ImGuiKey_LeftArrow;
    case XK_Right:
        return ImGuiKey_RightArrow;
    case XK_Up:
        return ImGuiKey_UpArrow;
    case XK_Down:
        return ImGuiKey_DownArrow;
    case XK_Prior:
        return ImGuiKey_PageUp;
    case XK_Next:
        return ImGuiKey_PageDown;
    case XK_Home:
        return ImGuiKey_Home;
    case XK_End:
        return ImGuiKey_End;
    case XK_Insert:
        return ImGuiKey_Insert;
    case XK_Delete:
        return ImGuiKey_Delete;
    case XK_BackSpace:
        return ImGuiKey_Backspace;
    case XK_space:
        return ImGuiKey_Space;
    case XK_Return:
        return ImGuiKey_Enter;
    case XK_Escape:
        return ImGuiKey_Escape;
    case XK_apostrophe:
        return ImGuiKey_Apostrophe;
    case XK_comma:
        return ImGuiKey_Comma;
    case XK_minus:
        return ImGuiKey_Minus;
    case XK_period:
        return ImGuiKey_Period;
    case XK_slash:
        return ImGuiKey_Slash;
    case XK_semicolon:
        return ImGuiKey_Semicolon;
    case XK_equal:
        return ImGuiKey_Equal;
    case XK_bracketleft:
        return ImGuiKey_LeftBracket;
    case XK_backslash:
        return ImGuiKey_Backslash;
    case XK_bracketright:
        return ImGuiKey_RightBracket;
    case XK_grave:
        return ImGuiKey_GraveAccent;
    case XK_Caps_Lock:
        return ImGuiKey_CapsLock;
    case XK_Scroll_Lock:
        return ImGuiKey_ScrollLock;
    case XK_Num_Lock:
        return ImGuiKey_NumLock;
    case XK_Pause:
        return ImGuiKey_Pause;
    case XK_KP_0:
        return ImGuiKey_Keypad0;
    case XK_KP_1:
        return ImGuiKey_Keypad1;
    case XK_KP_2:
        return ImGuiKey_Keypad2;
    case XK_KP_3:
        return ImGuiKey_Keypad3;
    case XK_KP_4:
        return ImGuiKey_Keypad4;
    case XK_KP_5:
        return ImGuiKey_Keypad5;
    case XK_KP_6:
        return ImGuiKey_Keypad6;
    case XK_KP_7:
        return ImGuiKey_Keypad7;
    case XK_KP_8:
        return ImGuiKey_Keypad8;
    case XK_KP_9:
        return ImGuiKey_Keypad9;
    case XK_KP_Decimal:
        return ImGuiKey_KeypadDecimal;
    case XK_KP_Divide:
        return ImGuiKey_KeypadDivide;
    case XK_KP_Multiply:
        return ImGuiKey_KeypadMultiply;
    case XK_KP_Subtract:
        return ImGuiKey_KeypadSubtract;
    case XK_KP_Add:
        return ImGuiKey_KeypadAdd;
    case XK_Shift_L:
        return ImGuiKey_LeftShift;
    case XK_Control_L:
        return ImGuiKey_LeftCtrl;
    case XK_Alt_L:
        return ImGuiKey_LeftAlt;
    case XK_Super_L:
        return ImGuiKey_LeftSuper;
    case XK_Shift_R:
        return ImGuiKey_RightShift;
    case XK_Control_R:
        return ImGuiKey_RightCtrl;
    case XK_Alt_R:
        return ImGuiKey_RightAlt;
    case XK_Super_R:
        return ImGuiKey_RightSuper;
    case XK_Menu:
        return ImGuiKey_Menu;
    case XK_0:
        return ImGuiKey_0;
    case XK_1:
        return ImGuiKey_1;
    case XK_2:
        return ImGuiKey_2;
    case XK_3:
        return ImGuiKey_3;
    case XK_4:
        return ImGuiKey_4;
    case XK_5:
        return ImGuiKey_5;
    case XK_6:
        return ImGuiKey_6;
    case XK_7:
        return ImGuiKey_7;
    case XK_8:
        return ImGuiKey_8;
    case XK_9:
        return ImGuiKey_9;
    case XK_A:
        return ImGuiKey_A;
    case XK_B:
        return ImGuiKey_B;
    case XK_C:
        return ImGuiKey_C;
    case XK_D:
        return ImGuiKey_D;
    case XK_E:
        return ImGuiKey_E;
    case XK_F:
        return ImGuiKey_F;
    case XK_G:
        return ImGuiKey_G;
    case XK_H:
        return ImGuiKey_H;
    case XK_I:
        return ImGuiKey_I;
    case XK_J:
        return ImGuiKey_J;
    case XK_K:
        return ImGuiKey_K;
    case XK_L:
        return ImGuiKey_L;
    case XK_M:
        return ImGuiKey_M;
    case XK_N:
        return ImGuiKey_N;
    case XK_O:
        return ImGuiKey_O;
    case XK_P:
        return ImGuiKey_P;
    case XK_Q:
        return ImGuiKey_Q;
    case XK_R:
        return ImGuiKey_R;
    case XK_S:
        return ImGuiKey_S;
    case XK_T:
        return ImGuiKey_T;
    case XK_U:
        return ImGuiKey_U;
    case XK_V:
        return ImGuiKey_V;
    case XK_W:
        return ImGuiKey_W;
    case XK_X:
        return ImGuiKey_X;
    case XK_Y:
        return ImGuiKey_Y;
    case XK_Z:
        return ImGuiKey_Z;
    case XK_F1:
        return ImGuiKey_F1;
    case XK_F2:
        return ImGuiKey_F2;
    case XK_F3:
        return ImGuiKey_F3;
    case XK_F4:
        return ImGuiKey_F4;
    case XK_F5:
        return ImGuiKey_F5;
    case XK_F6:
        return ImGuiKey_F6;
    case XK_F7:
        return ImGuiKey_F7;
    case XK_F8:
        return ImGuiKey_F8;
    case XK_F9:
        return ImGuiKey_F9;
    case XK_F10:
        return ImGuiKey_F10;
    case XK_F11:
        return ImGuiKey_F11;
    case XK_F12:
        return ImGuiKey_F12;
    case XK_F13:
        return ImGuiKey_F13;
    case XK_F14:
        return ImGuiKey_F14;
    case XK_F15:
        return ImGuiKey_F15;
    case XK_F16:
        return ImGuiKey_F16;
    case XK_F17:
        return ImGuiKey_F17;
    case XK_F18:
        return ImGuiKey_F18;
    case XK_F19:
        return ImGuiKey_F19;
    case XK_F20:
        return ImGuiKey_F20;
    case XK_F21:
        return ImGuiKey_F21;
    case XK_F22:
        return ImGuiKey_F22;
    case XK_F23:
        return ImGuiKey_F23;
    case XK_F24:
        return ImGuiKey_F24;
    default:
        return ImGuiKey_None;
    }
}

void set_modifier(uint8_t &inout_modifiers, Modifier::Enum modifier, bool is_set)
{
    inout_modifiers &= ~modifier;
    inout_modifiers |= is_set ? modifier : 0;
}

bool any_modifier_set(const uint8_t &modifiers, const uint8_t &test_modifiers)
{
    return modifiers & test_modifiers;
}

static void x_default_dim(const WindowContext *ctx, const char *size, Rect &rect_out)
{
    auto work_w = DisplayWidth(ctx->dpy, ctx->screen);
    auto work_h = DisplayHeight(ctx->dpy, ctx->screen);

    int window_w, window_h;

    int w, h;
    if (size && sscanf(size, "%dx%d", &w, &h) == 2)
    {
        window_w = w;
        window_h = h;
    }
    else
    {
        window_w = (int)(work_w * 0.7f);
        window_h = (int)(work_h * 0.7f);

        // Set window to 16:9

        if (window_w * 9 > window_h * 16)
        {
            window_w = window_h * 16 / 9;
        }
        else
        {
            window_h = window_w * 9 / 16;
        }
    }

    rect_out.x = (work_w - window_w) / 2;
    rect_out.y = (work_h - window_h) / 2;
    rect_out.w = window_w;
    rect_out.h = window_h;
}

static void x_init(WindowContext *ctx, const char *size, Rect &rect_out)
{
    XInitThreads();

    ctx->dpy = XOpenDisplay((char *)0);
    ctx->screen = DefaultScreen(ctx->dpy);

    x_default_dim(ctx, size, rect_out);

    auto bg_color = BlackPixel(ctx->dpy, ctx->screen);
    auto fg_color = WhitePixel(ctx->dpy, ctx->screen);

    ctx->window = XCreateSimpleWindow(ctx->dpy, DefaultRootWindow(ctx->dpy), rect_out.x, rect_out.y,
                                      rect_out.w, rect_out.h, 5, fg_color, bg_color);

    const char *wm_deleted_window_name = "WM_DELETE_WINDOW";
    XInternAtoms(ctx->dpy, (char **)&wm_deleted_window_name, 1, False, &s_wm_deleted_window);
    XSetWMProtocols(ctx->dpy, ctx->window, &s_wm_deleted_window, 1);

    XSetStandardProperties(ctx->dpy, ctx->window, "Ant Engine", "Ant Engine", 0L, NULL, 0, NULL);
    XSelectInput(ctx->dpy, ctx->window, StructureNotifyMask | ExposureMask | PointerMotionMask | ButtonPressMask | ButtonReleaseMask | KeyPressMask | KeyReleaseMask);
    ctx->gc = XCreateGC(ctx->dpy, ctx->window, 0, 0);

    XSetBackground(ctx->dpy, ctx->gc, bg_color);
    XSetForeground(ctx->dpy, ctx->gc, fg_color);

    XClearWindow(ctx->dpy, ctx->window);
    XMapRaised(ctx->dpy, ctx->window);
};

static void x_close(WindowContext *ctx)
{
    XFreeGC(ctx->dpy, ctx->gc);
    XDestroyWindow(ctx->dpy, ctx->window);
    XCloseDisplay(ctx->dpy);
    ctx->dpy = NULL;
}

static void x_run(void *_userData) noexcept
{
    auto *s_thread_ctx = (ThreadContext *)_userData;
    auto L = s_thread_ctx->L;
    auto ctx = s_thread_ctx->win_ctx;
    uint8_t key_modifiers = 0;

    XIM im = XOpenIM(ctx->dpy, NULL, NULL, NULL);
    XIC ic = XCreateIC(
        im, XNInputStyle, 0 | XIMPreeditNothing | XIMStatusNothing, XNClientWindow, ctx->window, NULL);

    XEvent event;

    while (true)
    {
        // process configure event data in lazy mode to avoid frequently calling window_message_size when resizing
        if (!XPending(ctx->dpy) && s_config_event.received)
        {
            auto event_wait_time = now_ms() - s_config_event.received_time;
            if (event_wait_time > CONFIG_EVENT_MAX_WAIT_TIME)
            {
                s_config_event.received = false;
                s_config_event.received_time = 0;
                window_message_size(L, s_config_event.w, s_config_event.h);
            }
            else
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(CONFIG_EVENT_MAX_WAIT_TIME));
                continue;
            }
        }

        XNextEvent(ctx->dpy, &event);

        switch (event.type)
        {
        case ConfigureNotify:
        {
            s_config_event.received = true;
            s_config_event.received_time = now_ms();
            s_config_event.w = event.xconfigure.width;
            s_config_event.h = event.xconfigure.height;
            s_config_event.x = event.xconfigure.x;
            s_config_event.y = event.xconfigure.y;
        }
        break;

        case DestroyNotify:
        {
            goto LABEL_END_OF_THREAD;
        }
        break;

        case ClientMessage:
        {
            if ((Atom)event.xclient.data.l[0] == s_wm_deleted_window)
            {
                goto LABEL_END_OF_THREAD;
            }
        }
        break;

        case MotionNotify:
        {
            struct ant::window::msg_mousemove msg;
            msg.what = ant::window::mouse_buttons::none;
            msg.x = event.xmotion.x;
            msg.y = event.xmotion.y;
            ant::window::input_message(L, msg);

            // FIXME: it's kind of hack, but there should be a better way to pass the mouse move event to imgui in the backend implementation.
            ImGuiIO &io = ImGui::GetIO();
            io.AddMousePosEvent((float)msg.x, (float)msg.y);
        }
        break;

        case ButtonPress:
        case ButtonRelease:
        {
            struct ant::window::msg_mouseclick msg;
            msg.what = to_ant_mouse_button(event.xbutton.button);
            msg.state = event.type == ButtonPress ? ant::window::mouse_state::down : ant::window::mouse_state::up;
            msg.x = event.xbutton.x;
            msg.y = event.xbutton.y;
            ant::window::input_message(L, msg);
        }
        break;

        case KeyPress:
        case KeyRelease:
        {
            XKeyEvent &xkey = event.xkey;
            KeySym keysym = XLookupKeysym(&xkey, 0);
            uint8_t press;
            if (event.type == KeyRelease)
            {
                press = 0;
            }
            else
            {
                press = 1;
            }

            switch (keysym)
            {
            case XK_Super_L:
                set_modifier(key_modifiers, Modifier::LeftSuper, press);
                break;
            case XK_Super_R:
                set_modifier(key_modifiers, Modifier::RightSuper, press);
                break;
            case XK_Control_L:
                set_modifier(key_modifiers, Modifier::LeftCtrl, press);
                break;
            case XK_Control_R:
                set_modifier(key_modifiers, Modifier::RightCtrl, press);
                break;
            case XK_Shift_L:
                set_modifier(key_modifiers, Modifier::LeftShift, press);
                break;
            case XK_Shift_R:
                set_modifier(key_modifiers, Modifier::RightShift, press);
                break;
            case XK_Alt_L:
                set_modifier(key_modifiers, Modifier::LeftAlt, press);
                break;
            case XK_Alt_R:
                set_modifier(key_modifiers, Modifier::RightAlt, press);
                break;

            default:
            {
                if (press)
                {
                    Status status = 0;
                    wchar_t buffer[XC_INPUT_BUFF_LEN];
                    int len = XwcLookupString(ic, &xkey, buffer, XC_INPUT_BUFF_LEN, &keysym, &status);

                    switch (status)
                    {
                    case XLookupChars:
                    case XLookupBoth:
                        if (0 != len)
                        {
                            struct ant::window::msg_inputchar msg;
                            msg.what = ant::window::inputchar_type::utf16;
                            msg.code = (uint16_t)buffer[0];
                            ant::window::input_message(L, msg);
                        }
                        break;

                    default:
                        break;
                    }
                }

                struct ant::window::msg_keyboard msg;
                auto key = ToImGuiKey(keysym);
                msg.press = press;
                msg.state = ant::window::get_keystate(
                    any_modifier_set(key_modifiers, Modifier::LeftCtrl | Modifier::RightCtrl),
                    any_modifier_set(key_modifiers, Modifier::LeftShift | Modifier::RightShift),
                    any_modifier_set(key_modifiers, Modifier::LeftAlt | Modifier::RightAlt),
                    any_modifier_set(key_modifiers, Modifier::LeftSuper | Modifier::RightSuper),
                    false);
                msg.key = key;
                ant::window::input_message(L, msg);
            }
            break;
            }
            break;
        }
        }
    }

LABEL_END_OF_THREAD:
    window_message_exit(L);
    XDestroyIC(ic);
    XCloseIM(im);
    x_close(ctx);
}

bool window_init(lua_State *L, const char *size)
{
    auto ctx = &s_win_ctx;
    Rect rect_actual;
    x_init(ctx, size, rect_actual);
    void *win_handle = (void *)(uintptr_t)(ctx->window);
    window_message_init(L, ctx, win_handle, ctx->dpy, 0L, rect_actual.w, rect_actual.h);

    s_thread_ctx.L = L;
    s_thread_ctx.win_ctx = ctx;
    s_thread_h = bee::thread_create(x_run, &s_thread_ctx);

    return true;
}

void window_close()
{
    // TODO: implement actual logic
}

bool window_peek_message()
{
    if (s_win_ctx.dpy == NULL)
    {
        return true;
    }
    else
    {
        XEvent event;
        for (;;)
        {
            if (XCheckMaskEvent(s_win_ctx.dpy, StructureNotifyMask, &event))
            {
                if (event.type == DestroyNotify)
                {
                    return false;
                }
                else
                {
                    XPutBackEvent(s_win_ctx.dpy, &event);
                }
            }
            else
            {
                return true;
            }
        }
    }

    return true;
}

void window_set_cursor(int cursor)
{
    // TODO: implement actual logic
}

void window_set_title(bee::zstring_view title)
{
    // TODO: implement actual logic
}

void window_set_maxfps(float fps)
{
    // TODO: implement actual logic
}

void window_set_fullscreen(bool fullscreen)
{
    // TODO: implement actual logic
}

void window_show_cursor(bool show_cursor)
{
    // TODO: implement actual logic
}

void ant::window::set_message(ant::window::set_msg &msg)
{
    switch (msg.type)
    {
    case ant::window::set_msg::type::cursor:
        window_set_cursor(msg.cursor);
        break;
    case ant::window::set_msg::type::title:
        window_set_title(msg.title);
        break;
    case ant::window::set_msg::type::fullscreen:
        window_set_fullscreen(msg.fullscreen);
        break;
    case ant::window::set_msg::type::show_cursor:
        window_show_cursor(msg.show_cursor);
        break;
    default:
        break;
    }
}