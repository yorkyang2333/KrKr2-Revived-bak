//
// Created by LiDon on 2025/9/13.
// TODO: implement emoteplayer.dll plugin
//
#include <spdlog/spdlog.h>
#include "tjs.h"
#include "ncbind.hpp"
#include "psbfile/PSBFile.h"

#include "D3DAdaptor.h"
#include "ResourceManager.h"
#include "EmotePlayer.h"
#include "Player.h"
#include "SeparateLayerAdaptor.h"

using namespace motion;

#define NCB_MODULE_NAME TJS_W("motionplayer.dll")
#define LOGGER spdlog::get("plugin")

NCB_REGISTER_SUBCLASS_DELAY(SeparateLayerAdaptor) { NCB_CONSTRUCTOR(()); }

NCB_REGISTER_SUBCLASS_DELAY(D3DAdaptor) {
    NCB_CONSTRUCTOR((iTJSDispatch2 *, tjs_int, tjs_int, tjs_real, tjs_real));
    NCB_METHOD_RAW_CALLBACK(captureCanvas, &D3DAdaptor::captureCanvas, 0);
    NCB_METHOD_RAW_CALLBACK(unloadUnusedTextures,
                            &D3DAdaptor::unloadUnusedTextures, 0);
}

NCB_REGISTER_SUBCLASS_DELAY(Player) {
    NCB_CONSTRUCTOR(());
    NCB_PROPERTY(motion, getMotion, setMotion);
    NCB_PROPERTY(count, getCount, setCount);
    NCB_PROPERTY(loopTime, getLoopTime, setLoopTime);
    NCB_PROPERTY(variableKeys, getVariableKeys, setVariableKeys);
    NCB_PROPERTY(outline, getOutline, setOutline);
}

NCB_REGISTER_SUBCLASS_DELAY(EmotePlayer) {
    NCB_CONSTRUCTOR((ResourceManager));
    NCB_PROPERTY(useD3D, getUseD3D, setUseD3D);
}

NCB_REGISTER_SUBCLASS(ResourceManager) {
    NCB_CONSTRUCTOR((iTJSDispatch2 *, tjs_int));
    NCB_METHOD(load);
    NCB_METHOD_RAW_CALLBACK(setEmotePSBDecryptSeed,
                            &ResourceManager::setEmotePSBDecryptSeed,
                            TJS_STATICMEMBER);
    NCB_METHOD_RAW_CALLBACK(setEmotePSBDecryptFunc,
                            &ResourceManager::setEmotePSBDecryptFunc,
                            TJS_STATICMEMBER);
}

class Motion {
public:
    static tjs_error setEnableD3D(tTJSVariant *, tjs_int count, tTJSVariant **p,
                                  iTJSDispatch2 *) {
        if(count == 1 && (*p)->Type() == tvtInteger) {
            _enableD3D = static_cast<bool>(**p);
            return TJS_S_OK;
        }
        return TJS_E_INVALIDPARAM;
    }

    static tjs_error getEnableD3D(tTJSVariant *r, tjs_int, tTJSVariant **,
                                  iTJSDispatch2 *) {
        *r = tTJSVariant{ _enableD3D };
        return TJS_S_OK;
    }

private:
    inline static bool _enableD3D;
};

NCB_REGISTER_CLASS(Motion) {
    // Variant("MaskModeAlpha", static_cast<int>(MaskMode::MaskModeAlpha));
    NCB_PROPERTY_RAW_CALLBACK(enableD3D, Motion::getEnableD3D,
                              Motion::setEnableD3D, TJS_STATICMEMBER);
    NCB_SUBCLASS(ResourceManager, ResourceManager);
    NCB_SUBCLASS(D3DAdaptor, D3DAdaptor);
    NCB_SUBCLASS(Player, Player);
    NCB_SUBCLASS(EmotePlayer, EmotePlayer);
    NCB_SUBCLASS(SeparateLayerAdaptor, SeparateLayerAdaptor);
}

static void PreRegistCallback() {}

static void PostUnregistCallback() {}

NCB_PRE_REGIST_CALLBACK(PreRegistCallback);
NCB_POST_UNREGIST_CALLBACK(PostUnregistCallback);
