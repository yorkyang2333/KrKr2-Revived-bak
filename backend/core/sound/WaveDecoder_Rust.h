#ifndef WaveDecoder_Rust_H
#define WaveDecoder_Rust_H

#include "WaveIntf.h"
#include <memory>
#include "krkr2-audio/src/lib.rs.h"

//---------------------------------------------------------------------------
//! @brief Rust Backend Adapter for tTVPWaveDecoder
//---------------------------------------------------------------------------
class tTVPWaveDecoder_Rust : public tTVPWaveDecoder {
    rust::Box<krkr2::audio::AudioDecoder_Rust> RustDecoder;

public:
    tTVPWaveDecoder_Rust(rust::Box<krkr2::audio::AudioDecoder_Rust> rust_decoder)
        : RustDecoder(std::move(rust_decoder)) {}

    ~tTVPWaveDecoder_Rust() override = default;

    void GetFormat(tTVPWaveFormat &format) override {
        krkr2::audio::WaveFormat fmt = RustDecoder->get_format();
        format.SamplesPerSec = fmt.samples_per_sec;
        format.Channels = fmt.channels;
        format.BitsPerSample = fmt.bits_per_sample;
        format.BytesPerSample = fmt.bytes_per_sample;
        format.TotalSamples = fmt.total_samples;
        format.TotalTime = fmt.total_time;
        format.SpeakerConfig = fmt.speaker_config;
        format.IsFloat = fmt.is_float;
        format.Seekable = fmt.seekable;
    }

    bool Render(void *buf, tjs_uint bufsamplelen, tjs_uint &rendered) override {
        // Warning: This requires buf to be large enough for format
        // AudioDecoder_Rust returns whether the stream is active
        uint32_t render_out = 0;
        bool b = RustDecoder->render(static_cast<uint8_t*>(buf), 0, bufsamplelen, render_out);
        rendered = render_out;
        return b;
    }

    bool SetPosition(tjs_uint64 samplepos) override {
        return RustDecoder->set_position(samplepos);
    }
    
    // Default DesiredFormat (can be extended to query Rust)
    bool DesiredFormat(const tTVPWaveFormat &format) override {
        return false;
    }
};

#endif
