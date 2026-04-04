#ifndef MenuItemImplH
#define MenuItemImplH

#include "MenuItemIntf.h"

class tTJSNI_MenuItem : public tTJSNI_BaseMenuItem {
    typedef tTJSNI_BaseMenuItem inherited;
public:
    tTJSNI_MenuItem() {}

protected:
    [[nodiscard]] bool CanDeliverEvents() const override { return false; }

public:
    void Add(tTJSNI_MenuItem *item) override {}
    void Insert(tTJSNI_MenuItem *item, tjs_int index) override {}
    void Remove(tTJSNI_MenuItem *item) override {}

    tjs_int TrackPopup(tjs_uint32 flags, tjs_int x, tjs_int y) { return 0; }
    void GetCaption(ttstr &res) const { res = ""; }
    void SetCaption(const ttstr &param) {}
    bool GetChecked() const { return false; }
    void SetChecked(bool) {}
    bool GetEnabled() const { return true; }
    void SetEnabled(bool) {}
    tjs_int GetGroup() const { return 0; }
    void SetGroup(tjs_int) {}
    bool GetRadio() const { return false; }
    void SetRadio(bool) {}
    void GetShortcut(ttstr &res) const { res = ""; }
    void SetShortcut(const ttstr &param) {}
    bool GetVisible() const { return true; }
    void SetVisible(bool) {}
    tjs_int GetIndex() const { return 0; }
    void SetIndex(tjs_int) {}
};

inline void CreateShortCutKeyCodeTable() {}

class WindowMenuProperty : public tTJSDispatch {
public:
    tjs_error PropGet(tjs_uint32 flag, const tjs_char *membername, tjs_uint32 *hint, tTJSVariant *result, iTJSDispatch2 *objthis) override { return TJS_E_NOTIMPL; }
    tjs_error PropSet(tjs_uint32 flag, const tjs_char *membername, tjs_uint32 *hint, const tTJSVariant *param, iTJSDispatch2 *objthis) override { return TJS_E_NOTIMPL; }
};

#endif
