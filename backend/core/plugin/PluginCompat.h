#pragma once
#include <string>
#include <algorithm>
#include "tjsNative.h"
#include "StorageIntf.h"

inline bool TVPIsKnownWindowsOnlyPlugin(const ttstr& pluginName) {
    std::string name = TVPChopStorageExt(TVPExtractStorageName(pluginName)).AsStdString();
    std::transform(name.begin(), name.end(), name.begin(), ::tolower);
    
    if (name == "wuvorbis" || name == "wmv" || name == "layerexsave" ||
        name == "win32dialog" || name == "win32ole" || name == "menu" || 
        name == "kagparser" || name == "extrans" || name == "extnagano" || 
        name == "csvparser" || name == "json" || name == "fstat" || 
        name == "psbfile" || name == "dirlist" || name == "tjs2krmovie" || 
        name == "tjs2krflash" || name == "krmovie" || name == "wsehelp" ||
        name == "wdf" || name == "vrm" || name == "zoom" || 
        name == "shrinkcopy" || name == "savemap" || name == "fftgraph" ||
        name == "fstat" || name == "getcvd" || name == "joystick" ||
        name == "krmenu" || name == "packinone" || name == "scriptdebugger" ||
        name == "spellcheck" || name == "sqlite3" || name == "texture" ||
        name == "windowex" || name == "zlib" || name == "varfile" ||
        name == "texdec" || name == "tlg5" || name == "util_generic") {
        return true;
    }
    
    return false;
}
