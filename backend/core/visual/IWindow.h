#pragma once

#include <string>
#include <cstdint>

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
struct tTVPFont;

// These types are from tjsTypes.h – using plain integers so IWindow
// does not need to pull in the TJS2 headers (keeping it truly platform-neutral)
using tjs_uint16  = uint16_t;
using tjs_uint32  = uint32_t;
using tjs_char    = wchar_t;

// ---------------------------------------------------------------------------
// TVP border style enum (originally from VCL/Win32)
// ---------------------------------------------------------------------------
enum tTVPBorderStyle {
    bsNone     = 0,
    bsSingle   = 1,
    bsSizeable = 2,
    bsDialog   = 3
};

// TVP mouse cursor state
enum tTVPMouseCursorState {
    mcsVisible = 0,
    mcsHidden  = 1
};

// TVP update type
enum tTVPUpdateType {
    utNone  = 0,
    utForce = 1
};

// TVP display orientation
enum tTVPDisplayOrientation {
    orientUnknown             = -1,
    orientPortrait            = 0,
    orientLandscape           = 1,
    orientPortraitUpsideDown  = 2,
    orientLandscapeRight      = 3
};

// ---------------------------------------------------------------------------
// IWindow – platform-neutral abstract window interface
// ---------------------------------------------------------------------------
class IWindow {
public:
    virtual ~IWindow() = default;

    // --- Core window properties ---
    virtual void SetTitle(const std::string& title) = 0;
    virtual void SetSize(int width, int height) = 0;
    virtual void SetVisible(bool visible) = 0;
    virtual void SetFullScreen(bool fullscreen) = 0;

    virtual int  GetWidth() const = 0;
    virtual int  GetHeight() const = 0;
    virtual bool IsVisible() const = 0;

    // Platform specific native handle if needed
    virtual void* GetNativeHandle() const = 0;

    // --- Extended window geometry ---
    virtual void SetWidth(int w)         { SetSize(w, GetHeight()); }
    virtual void SetHeight(int h)        { SetSize(GetWidth(), h); }
    virtual void SetLeft(int /*x*/)      {}
    virtual int  GetLeft() const         { return 0; }
    virtual void SetTop(int /*y*/)       {}
    virtual int  GetTop() const          { return 0; }
    virtual void SetPosition(int x, int y) { SetLeft(x); SetTop(y); }

    virtual void SetMinWidth(int /*v*/)  {}
    virtual int  GetMinWidth() const     { return 0; }
    virtual void SetMinHeight(int /*v*/) {}
    virtual int  GetMinHeight() const    { return 0; }
    virtual void SetMinSize(int w, int h){ SetMinWidth(w); SetMinHeight(h); }

    virtual void SetMaxWidth(int /*v*/)  {}
    virtual int  GetMaxWidth() const     { return 0; }
    virtual void SetMaxHeight(int /*v*/) {}
    virtual int  GetMaxHeight() const    { return 0; }
    virtual void SetMaxSize(int w, int h){ SetMaxWidth(w); SetMaxHeight(h); }

    // Inner size == client area (SDL windows have no decorations we track here)
    virtual void SetInnerWidth(int w)    { SetWidth(w); }
    virtual int  GetInnerWidth() const   { return GetWidth(); }
    virtual void SetInnerHeight(int h)   { SetHeight(h); }
    virtual int  GetInnerHeight() const  { return GetHeight(); }
    virtual void SetInnerSize(int w, int h) { SetSize(w, h); }

    // --- Window attributes ---
    virtual void            SetBorderStyle(tTVPBorderStyle /*st*/) {}
    virtual tTVPBorderStyle GetBorderStyle() const { return bsSizeable; }

    virtual void SetStayOnTop(bool /*b*/) {}
    virtual bool GetStayOnTop() const     { return false; }

    virtual void SetFocusable(bool /*b*/) {}
    virtual bool GetFocusable()           { return true; }

    // Full-screen (tracks state in implementation)
    virtual void SetFullScreenMode(bool b) { SetFullScreen(b); }
    virtual bool GetFullScreenMode()       { return false; }

    // Visibility (script-controlled, same as SetVisible by default)
    virtual void SetVisibleFromScript(bool s) { SetVisible(s); }
    virtual bool GetVisible() const           { return IsVisible(); }

    // Caption / title bar text
    virtual void GetCaption(std::string& v) const { v = ""; }
    virtual void SetCaption(const std::string& v) { SetTitle(v); }

    // --- Mouse cursor ---
    virtual void SetDefaultMouseCursor() {}
    virtual void SetMouseCursor(int /*cursor*/) {}
    virtual void SetMouseCursorState(tTVPMouseCursorState /*mcs*/) {}
    virtual tTVPMouseCursorState GetMouseCursorState() const { return mcsVisible; }
    virtual void HideMouseCursor() { SetMouseCursorState(mcsHidden); }
    virtual void GetCursorPos(int& x, int& y) { x = 0; y = 0; }
    virtual void SetCursorPos(int /*x*/, int /*y*/) {}

    // --- Zooming ---
    virtual void SetZoom(int /*numer*/, int /*denom*/) {}
    virtual void SetZoomNumer(int /*n*/) {}
    virtual int  GetZoomNumer() const    { return 1; }
    virtual void SetZoomDenom(int /*n*/) {}
    virtual int  GetZoomDenom() const    { return 1; }

    // --- Touch ---
    virtual void SetEnableTouch(bool /*b*/) {}
    virtual bool GetEnableTouch() const     { return false; }

    virtual void   SetTouchScaleThreshold(double /*threshold*/) {}
    virtual double GetTouchScaleThreshold() const               { return 0.0; }
    virtual void   SetTouchRotateThreshold(double /*threshold*/) {}
    virtual double GetTouchRotateThreshold() const              { return 0.0; }

    virtual double GetTouchPointStartX(int /*index*/) { return 0.0; }
    virtual double GetTouchPointStartY(int /*index*/) { return 0.0; }
    virtual double GetTouchPointX(int /*index*/)      { return 0.0; }
    virtual double GetTouchPointY(int /*index*/)      { return 0.0; }
    virtual double GetTouchPointID(int /*index*/)     { return 0.0; }
    virtual int    GetTouchPointCount()               { return 0; }

    virtual bool GetTouchVelocity(int /*id*/, float& x, float& y, float& speed) const {
        x = y = speed = 0.0f; return false;
    }
    virtual void ResetTouchVelocity(int /*id*/) {}

    // --- Mouse velocity ---
    virtual bool GetMouseVelocity(float& x, float& y, float& speed) const {
        x = y = speed = 0.0f; return false;
    }
    virtual void ResetMouseVelocity() {}

    // --- Hint / IME ---
    virtual void SetHintText(const std::string& /*text*/) {}
    virtual void SetHintText(const tjs_char* /*text*/) {}
    // Overload used by tTJSNI_Window::SetHintText(sender, text)
    virtual void SetHintText(void* /*sender*/, const std::string& text) {
        SetHintText(text);
    }
    virtual void SetHintDelay(int /*delay*/) {}
    virtual int  GetHintDelay() const        { return 0; }

    virtual void SetImeMode(int /*mode*/)  {}
    virtual void ResetImeMode()            {}
    virtual int  GetDefaultImeMode()       { return 0; /* imDisable */ }

    virtual void SetAttentionPoint(int /*x*/, int /*y*/, const tTVPFont* /*font*/) {}
    virtual void DisableAttentionPoint()   {}

    // --- Display orientation ---
    virtual int GetDisplayOrientation()    { return orientUnknown; }
    virtual int GetDisplayRotate()         { return -1; }

    // --- Mouse / keyboard trapping ---
    virtual void SetUseMouseKey(bool /*b*/) {}
    virtual bool GetUseMouseKey() const     { return false; }
    virtual void SetTrapKey(bool /*b*/)     {}
    virtual bool GetTrapKey() const         { return false; }

    // --- Window state / actions ---
    virtual void BringToFront()               {}
    virtual void UpdateWindow(tTVPUpdateType) {}
    virtual void ShowWindowAsModal()          {}
    virtual void Close()                      {}
    virtual void OnCloseQueryCalled(bool /*b*/) {}
    virtual void SendCloseMessage()           {}
    virtual void TickBeat()                   {}

    // --- Region / mask ---
    virtual void RemoveMaskRegion()           {}

    // --- Paint box ---
    virtual void SetPaintBoxSize(int /*w*/, int /*h*/) {}

    // --- Video overlay ---
    virtual void GetVideoOffset(int& x, int& y) { x = 0; y = 0; }
    virtual void ZoomRectangle(int& /*x*/, int& /*y*/, int& /*w*/, int& /*h*/) {}

    // --- Legacy key/input stubs (called from PostInputEvent) ---
    virtual void OnKeyPress(tjs_uint16 /*key*/) {}
    virtual void OnKeyPress(tjs_uint16 /*key*/, tjs_uint32 /*shift*/,
                            bool /*a*/, bool /*b*/) {}
    virtual void OnKeyUp(tjs_uint16 /*key*/, tjs_uint32 /*shift*/) {}
    virtual void InternalKeyDown(tjs_uint16 /*key*/, tjs_uint32 /*shift*/) {}
    virtual void InternalKeyDown(tjs_uint16 /*key*/, tjs_uint32 /*shift*/,
                                 bool /*repeat*/, bool /*process*/ = true) {}
    virtual void InvalidateClose()    {}
    virtual bool GetWindowActive()    { return true; }
    virtual bool GetFormEnabled()     { return true; }
    virtual void ResetDrawDevice()    {}
    virtual void RegisterWindow()     {}
    virtual void UnregisterWindow()   {}

    // Plugin integration
    virtual void RegisterWindowMessageReceiver(void* /*mode*/, void* /*proc*/,
                                               const void* /*userdata*/) {}
};
