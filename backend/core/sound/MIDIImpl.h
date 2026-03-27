#ifndef MIDIImplH
#define MIDIImplH

#include "MIDIIntf.h"

class tTJSNI_MIDISoundBuffer : public tTJSNI_BaseMIDISoundBuffer {
    typedef tTJSNI_BaseMIDISoundBuffer inherited;
public:
    tTJSNI_MIDISoundBuffer() {}

protected:
    void SetVolume(tjs_int i) override {}
    [[nodiscard]] tjs_int GetVolume() const override { return 0; }
};

#endif
