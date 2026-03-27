#ifndef VideoOvlImplH
#define VideoOvlImplH

#include "VideoOvlIntf.h"

class tTJSNI_VideoOverlay : public tTJSNI_BaseVideoOverlay {
    typedef tTJSNI_BaseVideoOverlay inherited;
public:
    tTJSNI_VideoOverlay() {}

    void Disconnect() override {}
    [[nodiscard]] bool GetVisible() const override { return false; }
    [[nodiscard]] const tTVPRect &GetBounds() const override {
        static tTVPRect r{0, 0, 0, 0};
        return r;
    }
    [[nodiscard]] tTVPVideoOverlayMode GetMode() const override { return vomOverlay; }
    bool GetVideoSize(tjs_int &w, tjs_int &h) const override { w = h = 0; return false; }
};

#endif
