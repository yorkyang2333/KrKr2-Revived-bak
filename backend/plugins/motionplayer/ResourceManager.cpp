//
// Created by LiDon on 2025/9/15.
//

#include "ResourceManager.h"

#include "tjsArray.h"
#include "tjsObject.h"
#include "psbfile/PSBFile.h"
#include "psbfile/TJSCompat.h"

#define LOGGER spdlog::get("plugin")

motion::ResourceManager::ResourceManager(iTJSDispatch2 *kag,
                                         tjs_int cacheSize) {
    LOGGER->info("kag: {}, cacheSize: {}", static_cast<void *>(kag), cacheSize);
}

tjs_error motion::ResourceManager::setEmotePSBDecryptSeed(tTJSVariant *,
                                                          tjs_int count,
                                                          tTJSVariant **p,
                                                          iTJSDispatch2 *) {
    if(count != 1 || !p || !p[0] || (*p)->Type() != tvtInteger) {
        return TJS_E_BADPARAMCOUNT;
    }
    _decryptSeed = static_cast<tjs_int>(*p[0]);
    LOGGER->info("setEmotePSBDecryptSeed: {}", _decryptSeed);
    return TJS_S_OK;
}

tjs_error motion::ResourceManager::setEmotePSBDecryptFunc(tTJSVariant *r,
                                                          tjs_int n,
                                                          tTJSVariant **p,
                                                          iTJSDispatch2 *obj) {
    if(n != 1 || !p || !p[0]) {
        return TJS_E_BADPARAMCOUNT;
    }

    if(p[0]->Type() == tvtVoid) {
        _decryptFunc = tTJSVariantClosure();
        return TJS_S_OK;
    }

    if(p[0]->Type() != tvtObject) {
        return TJS_E_INVALIDPARAM;
    }

    _decryptFunc = p[0]->AsObjectClosure();
    return TJS_S_OK;
}

tTJSVariant motion::ResourceManager::load(ttstr path) const {
    PSB::PSBFile f;
    int seed = _decryptSeed;
    if(_decryptFunc.Object) {
        tTJSVariant pathVar(path);
        tTJSVariant result;
        tTJSVariant *args[] = { &pathVar };
        if(TJS_SUCCEEDED(_decryptFunc.FuncCall(
               0, nullptr, nullptr, &result, 1, args, _decryptFunc.ObjThis)) &&
           result.Type() == tvtInteger) {
            seed = static_cast<tjs_int>(result);
        }
    }
    f.setSeed(seed);
    if(!f.loadPSBFile(path)) {
        LOGGER->error("emote load file: {} failed", path.AsStdString());
    }

    return PSB::BuildCompatRootVariant(f);
}
