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
};

inline void CreateShortCutKeyCodeTable() {}

class WindowMenuProperty : public tTJSDispatch {
public:
    tjs_error PropGet(tjs_uint32 flag, const tjs_char *membername, tjs_uint32 *hint, tTJSVariant *result, iTJSDispatch2 *objthis) override { return TJS_E_NOTIMPL; }
    tjs_error PropSet(tjs_uint32 flag, const tjs_char *membername, tjs_uint32 *hint, const tTJSVariant *param, iTJSDispatch2 *objthis) override { return TJS_E_NOTIMPL; }
};

#endif
