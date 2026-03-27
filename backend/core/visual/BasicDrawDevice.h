#ifndef BasicDrawDeviceH
#define BasicDrawDeviceH

#include "tjsNative.h"
#include "DrawDevice.h"

//---------------------------------------------------------------------------
// tTJSNC_BasicDrawDevice : TJS BasicDrawDevice class stub
//---------------------------------------------------------------------------
class tTJSNC_BasicDrawDevice : public tTJSNativeClass {
public:
    tTJSNC_BasicDrawDevice() : tTJSNativeClass(TJS_W("BasicDrawDevice")) {}

    static tjs_uint32 ClassID;

protected:
    tTJSNativeInstance *CreateNativeInstance() override { return nullptr; }
};

#endif
