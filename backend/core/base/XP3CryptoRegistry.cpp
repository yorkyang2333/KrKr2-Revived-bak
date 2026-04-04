#include "tjsCommHead.h"
#include "XP3CryptoRegistry.h"
#include <spdlog/spdlog.h>
#include <mutex>

static std::vector<tTVPXP3CryptoStrategy> g_CryptoStrategies;
static const tTVPXP3CryptoStrategy* g_ActiveStrategy = nullptr;
static bool g_DetectionFinished = false;
static std::mutex g_CryptoMutex;

static void TestAndSetStrategy(tTVPXP3ExtractionFilterInfo *info, tTJSVariant *ctx) {
    // Only heuristically detect using startup.tjs
    ttstr filename = info->FileName;
    if (filename == TJS_W("startup.tjs")) {
        // Try all scenarios
        for (const auto& strategy : g_CryptoStrategies) {
            // Copy buffer for testing
            std::vector<tjs_uint8> testBuffer((tjs_uint8*)info->Buffer, (tjs_uint8*)info->Buffer + info->BufferSize);
            tTVPXP3ExtractionFilterInfo testInfo = *info;
            testInfo.Buffer = testBuffer.data();
            
            strategy.filterFunc(&testInfo, ctx);
            
            // Heuristic check: does it look like valid TJS?
            // Valid TJS usually has readable ASCII or // comments at the beginning
            bool valid = true;
            for(size_t i=0; i < std::min<size_t>(testInfo.BufferSize, 10); ++i) {
                tjs_uint8 c = testBuffer[i];
                if ((c < 32 && c != '\r' && c != '\n' && c != '\t') || c > 127) {
                    // This is naive, sometimes files have BOM (EF BB BF or FF FE).
                    if (i == 0 && (c == 0xEF || c == 0xFF || c == 0xFE)) continue;
                    if (i == 1 && (c == 0xBB || c == 0xFE || c == 0xFF)) continue;
                    if (i == 2 && c == 0xBF) continue;
                    valid = false;
                    break;
                }
            }

            if (valid) {
                g_ActiveStrategy = &strategy;
                spdlog::info("XP3 Crypto Heuristic: Selected strategy '{}'", strategy.strategyName);
                
                // Apply to original buffer
                strategy.filterFunc(info, ctx);
                return;
            }
        }
        spdlog::warn("XP3 Crypto Heuristic: No matching strategy found for encrypted startup.tjs");
    }
}

static void TVP_tTVPXP3ArchiveExtractionFilter_CONVENTION TVPUniversalXP3Filter(tTVPXP3ExtractionFilterInfo *info, tTJSVariant *ctx) {
    if (!info || info->BufferSize == 0) return;
    
    std::lock_guard<std::mutex> lock(g_CryptoMutex);

    if (!g_DetectionFinished) {
        // If it's the first time and we haven't decided it's none, try to detect.
        TestAndSetStrategy(info, ctx);
        g_DetectionFinished = true; // We only try once on the first file (usually startup.tjs)
    } else if (g_ActiveStrategy) {
        g_ActiveStrategy->filterFunc(info, ctx);
    }
}

void TVPRegisterXP3CryptoStrategy(const tTVPXP3CryptoStrategy& strategy) {
    std::lock_guard<std::mutex> lock(g_CryptoMutex);
    g_CryptoStrategies.push_back(strategy);
}

void TVPInitXP3CryptoRegistry() {
    TVPSetXP3ArchiveExtractionFilter(TVPUniversalXP3Filter);
    
    // Register some known dummy or common strategies here
    TVPRegisterXP3CryptoStrategy({
        "Yuzusoft Example",
        [](tTVPXP3ExtractionFilterInfo *info, tTJSVariant *) {
            tjs_uint8* buff = (tjs_uint8*)info->Buffer;
            tjs_uint32 hash = info->FileHash;
            for (tjs_uint i = 0; i < info->BufferSize; ++i) {
                // buff[i] ^= (hash >> ((i % 4) * 8)) & 0xFF; // placeholder
            }
        }
    });

    spdlog::info("XP3 Crypto Registry Initialized (Universal Filter installed)");
}
