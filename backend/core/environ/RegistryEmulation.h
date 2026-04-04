#pragma once
#include "tjsNative.h"
#include "tjsString.h"
#include "tjsVariant.h"

// Registry simulation layer to replace Windows Reg API
void TVPInitRegistryEmulation();
bool TVPReadRegistryKV(tTJSVariant &result, const ttstr &key);
void TVPWriteRegistryKV(const ttstr &key, const tTJSVariant &value);
