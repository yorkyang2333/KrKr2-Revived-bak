#pragma once
#include "tjsCommHead.h"
#include "tjsNative.h"
#include "XP3Archive.h"
#include "tjsVariant.h"
#include <vector>
#include <functional>
#include <string>

struct tTVPXP3CryptoStrategy {
    std::string strategyName;
    std::function<void(tTVPXP3ExtractionFilterInfo *info, tTJSVariant* ctx)> filterFunc;
};

void TVPInitXP3CryptoRegistry();
void TVPRegisterXP3CryptoStrategy(const tTVPXP3CryptoStrategy& strategy);
