#ifndef WaveImplH
#define WaveImplH

#include "WaveIntf.h"

class tTJSNI_WaveSoundBuffer : public tTJSNI_BaseWaveSoundBuffer {
    typedef tTJSNI_BaseWaveSoundBuffer inherited;
public:
    tTJSNI_WaveSoundBuffer() {}

protected:
    void SetVolume(tjs_int i) override {}
    [[nodiscard]] tjs_int GetVolume() const override { return 0; }
};

#endif
