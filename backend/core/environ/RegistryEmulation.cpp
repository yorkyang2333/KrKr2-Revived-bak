#include "tjsCommHead.h"
#include "RegistryEmulation.h"
#include "StorageIntf.h"
#include "SystemImpl.h"
#include <map>
#include <string>
#include <spdlog/spdlog.h>

static std::map<ttstr, tTJSVariant> g_RegistryCache;
static ttstr g_RegistryFilePath;

static void SaveRegistry() {
    // A simplified custom saving logic since TJS dictionaries can be complex 
    // Here we can output a simple text file if yyjson is not used
    // (To be fully implemented with a config manager if needed)
}

void TVPInitRegistryEmulation() {
    g_RegistryFilePath = TJS_W("savedata/registry_mock.txt");
    // Load logic to be implemented
    spdlog::info("Registry Emulation Initialized");
}

bool TVPReadRegistryKV(tTJSVariant &result, const ttstr &key) {
    auto it = g_RegistryCache.find(key);
    if (it != g_RegistryCache.end()) {
        result = it->second;
        return true;
    }
    return false;
}

void TVPWriteRegistryKV(const ttstr &key, const tTJSVariant &value) {
    g_RegistryCache[key] = value;
    SaveRegistry();
}
