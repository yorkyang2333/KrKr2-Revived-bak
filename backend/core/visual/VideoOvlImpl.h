#ifndef VideoOvlImplH
#define VideoOvlImplH

#include "VideoOvlIntf.h"

class tTJSNI_VideoOverlay : public tTJSNI_BaseVideoOverlay {
    typedef tTJSNI_BaseVideoOverlay inherited;
public:
    tTJSNI_VideoOverlay() {}

    void Disconnect() override {}
    [[nodiscard]] bool GetVisible() const override { return false; }
    [[nodiscard]] const tTVPRect &GetBounds() const override {
        static tTVPRect r{0, 0, 0, 0};
        return r;
    }
    [[nodiscard]] tTVPVideoOverlayMode GetMode() const override { return vomOverlay; }
    bool GetVideoSize(tjs_int &w, tjs_int &h) const override { w = h = 0; return false; }

    void Open(const ttstr&) {}
    void Play() {}
    void Stop() {}
    void Close() {}
    void SetPosition(tjs_int, tjs_int) {}
    void SetSize(tjs_int, tjs_int) {}
    void SetBounds(const tTVPRect&) {}
    void Pause() {}
    void Rewind() {}
    void Prepare() {}
    void SetSegmentLoop(tjs_int, tjs_int) {}
    void CancelSegmentLoop() {}
    void SetPeriodEvent(tjs_int) {}
    void SelectAudioStream(tjs_uint) {}
    void SetMixingLayer(tTJSVariant) {}
    void ResetMixingBitmap() {}
    tjs_int GetAudioBalance() { return 0; }
    void SetAudioBalance(tjs_int) {}
    tjs_int GetAudioVolume() { return 0; }
    void SetAudioVolume(tjs_int) {}
    double GetBrightness() { return 0; }
    void SetBrightness(double) {}
    double GetBrightnessDefaultValue() { return 0; }
    double GetBrightnessRangeMax() { return 0; }
    double GetBrightnessRangeMin() { return 0; }
    double GetBrightnessStepSize() { return 0; }
    double GetContrast() { return 0; }
    void SetContrast(double) {}
    double GetContrastDefaultValue() { return 0; }
    double GetContrastRangeMax() { return 0; }
    double GetContrastRangeMin() { return 0; }
    double GetContrastStepSize() { return 0; }
    bool GetEnabledAudioStream() { return false; }
    bool GetEnabledVideoStream() { return false; }
    double GetFPS() { return 0; }
    tjs_int GetFrame() { return 0; }
    void SetFrame(tjs_int) {}
    double GetHue() { return 0; }
    void SetHue(double) {}
    double GetHueDefaultValue() { return 0; }
    double GetHueRangeMax() { return 0; }
    double GetHueRangeMin() { return 0; }
    double GetHueStepSize() { return 0; }
    tTJSNI_BaseLayer* GetLayer1() { return nullptr; }
    void SetLayer1(tTJSNI_BaseLayer*) {}
    tTJSNI_BaseLayer* GetLayer2() { return nullptr; }
    void SetLayer2(tTJSNI_BaseLayer*) {}
    bool GetLoop() { return false; }
    void SetLoop(bool) {}
    double GetMixingMovieAlpha() { return 0; }
    void SetMixingMovieAlpha(double) {}
    tjs_int GetMixingMovieBGColor() { return 0; }
    void SetMixingMovieBGColor(tjs_int) {}
    void SetMode(tTVPVideoOverlayMode) {}
    tjs_int GetNumberOfAudioStream() { return 0; }
    tjs_int GetNumberOfFrame() { return 0; }
    tjs_int GetNumberOfVideoStream() { return 0; }
    tjs_int GetOriginalHeight() { return 0; }
    tjs_int GetOriginalWidth() { return 0; }
    tjs_int GetPeriodEventFrame() { return 0; }
    double GetPlayRate() { return 0; }
    void SetPlayRate(double) {}
    double GetSaturation() { return 0; }
    void SetSaturation(double) {}
    double GetSaturationDefaultValue() { return 0; }
    double GetSaturationRangeMax() { return 0; }
    double GetSaturationRangeMin() { return 0; }
    double GetSaturationStepSize() { return 0; }
    tjs_int GetSegmentLoopEndFrame() { return 0; }
    tjs_int GetSegmentLoopStartFrame() { return 0; }
    tjs_int GetTimePosition() { return 0; }
    void SetTimePosition(tjs_int) {}
    tjs_int GetTotalTime() { return 0; }
    tjs_int GetLeft() { return 0; }
    void SetLeft(tjs_int) {}
    tjs_int GetTop() { return 0; }
    void SetTop(tjs_int) {}
    tjs_int GetWidth() { return 0; }
    void SetWidth(tjs_int) {}
    tjs_int GetHeight() { return 0; }
    void SetHeight(tjs_int) {}
    void SetVisible(bool) {}
    void SelectVideoStream(tjs_uint) {}
    tTJSVariantClosure GetActionOwnerNoAddRef() const { return tTJSVariantClosure(NULL, NULL); }

    void DetachVideoOverlay() {}
    void ResetOverlayParams() {}
    void SetRectangleToVideoOverlay() {}
};

#endif
