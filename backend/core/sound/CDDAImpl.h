#ifndef CDDAImplH
#define CDDAImplH

#include "CDDAIntf.h"

class tTJSNI_CDDASoundBuffer : public tTJSNI_BaseCDDASoundBuffer {
    typedef tTJSNI_BaseCDDASoundBuffer inherited;
public:
    tTJSNI_CDDASoundBuffer() {}

protected:
    void SetVolume(tjs_int i) override {}
    [[nodiscard]] tjs_int GetVolume() const override { return 0; }
};

#endif
