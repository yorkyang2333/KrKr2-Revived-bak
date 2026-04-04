//---------------------------------------------------------------------------
/*
        Risa [りさ]      alias 吉里吉里3 [kirikiri-3]
         stands for "Risa Is a Stagecraft Architecture"
        Copyright (C) 2000 W.Dee <dee@kikyou.info> and contributors

        See details of license at "license.txt"
*/
//---------------------------------------------------------------------------
//! @file
//! @brief Waveセグメント/ラベルキュー管理 (Rust Adapter)
//---------------------------------------------------------------------------
#ifndef WAVESEGMENTH
#define WAVESEGMENTH

#include "tjsString.h"
#include <deque>
#include <string>
#include <memory>
// 引入 CXX 桥接头文件
#include "krkr2-audio/src/lib.rs.h"

//---------------------------------------------------------------------------
//! @brief 再生セグメント情報
//---------------------------------------------------------------------------
struct tTVPWaveSegment {
    //! @brief コンストラクタ
    tTVPWaveSegment(tjs_int64 start, tjs_int64 length) {
        Start = start;
        Length = FilteredLength = length;
    }

    tTVPWaveSegment(tjs_int64 start, tjs_int64 length, tjs_int64 filteredlength) {
        Start = start;
        Length = length;
        FilteredLength = filteredlength;
    }

    tjs_int64 Start; //!< オリジナルデコーダ上でのセグメントのスタート位置 (PCM サンプルグラニュール数単位)
    tjs_int64 Length; //!< オリジナルデコーダ上でのセグメントの長さ (PCM サンプルグラニュール数単位)
    tjs_int64 FilteredLength; //!< フィルタ後の長さ (PCM サンプルグラニュール数単位)
};
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//! @brief 再生ラベル情報
//---------------------------------------------------------------------------
struct tTVPWaveLabel {
    //! @brief コンストラクタ
    tjs_int64 Position; //!< オリジナルデコーダ上でのラベル位置 (PCM サンプルグラニュール数単位)
    tTJSString Name; //!< ラベル名
    tjs_int Offset;

#ifdef TVP_IN_LOOP_TUNER
    // these are only used by the loop tuner
    tjs_int NameWidth; // display name width
    tjs_int Index; // index
#endif

    struct tSortByPositionFuncObj {
        bool operator()(const tTVPWaveLabel &lhs, const tTVPWaveLabel &rhs) const {
            return lhs.Position < rhs.Position;
        }
    };

    struct tSortByOffsetFuncObj {
        bool operator()(const tTVPWaveLabel &lhs, const tTVPWaveLabel &rhs) const {
            return lhs.Offset < rhs.Offset;
        }
    };

#ifdef TVP_IN_LOOP_TUNER
    struct tSortByIndexFuncObj {
        bool operator()(const tTVPWaveLabel &lhs, const tTVPWaveLabel &rhs) const {
            return lhs.Index < rhs.Index;
        }
    };
#endif

    tTVPWaveLabel() {
        Position = 0;
        Offset = 0;
#ifdef TVP_IN_LOOP_TUNER
        NameWidth = 0;
        Index = 0;
#endif
    }

    tTVPWaveLabel(tjs_int64 position, const tTJSString &name, tjs_int offset) :
        Position(position), Name(name), Offset(offset) {
#ifdef TVP_IN_LOOP_TUNER
        NameWidth = 0;
        Index = 0;
#endif
    }
};

//---------------------------------------------------------------------------
bool inline operator<(const tTVPWaveLabel &lhs, const tTVPWaveLabel &rhs) {
    return lhs.Position < rhs.Position;
}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//! @brief Waveのセグメント・ラベルのキューを管理するクラス
//---------------------------------------------------------------------------
class tTVPWaveSegmentQueue {
    rust::Box<krkr2::audio::WaveSegmentQueue_Rust> RustQueue;
    
    // Cached objects for GetSegments() and GetLabels()
    mutable std::deque<tTVPWaveSegment> CachedSegments;
    mutable std::deque<tTVPWaveLabel> CachedLabels;
    mutable bool SegmentsDirty;
    mutable bool LabelsDirty;

public:
    tTVPWaveSegmentQueue() : 
        RustQueue(krkr2::audio::create_wave_segment_queue()),
        SegmentsDirty(false), LabelsDirty(false) {
    }

    // copy constructor (required by some deque/copy assignments)
    tTVPWaveSegmentQueue(const tTVPWaveSegmentQueue &other) : 
        RustQueue(krkr2::audio::create_wave_segment_queue()),
        SegmentsDirty(true), LabelsDirty(true) {
        RustQueue->enqueue_queue(*other.RustQueue);
    }
    
    tTVPWaveSegmentQueue& operator=(const tTVPWaveSegmentQueue &other) {
        if (this != &other) {
            RustQueue->clear();
            RustQueue->enqueue_queue(*other.RustQueue);
            SegmentsDirty = true;
            LabelsDirty = true;
        }
        return *this;
    }

    //! @brief        内容をクリアする
    void Clear() {
        RustQueue->clear();
        SegmentsDirty = true;
        LabelsDirty = true;
    }

    //! @brief        セグメントの配列を得る
    //! @return       セグメントの配列
    [[nodiscard]] const std::deque<tTVPWaveSegment> &GetSegments() const {
        if (SegmentsDirty) {
            CachedSegments.clear();
            size_t len = RustQueue->get_segments_len();
            for (size_t i = 0; i < len; ++i) {
                auto seg = RustQueue->get_segment(i);
                CachedSegments.emplace_back(seg.start, seg.length, seg.filtered_length);
            }
            SegmentsDirty = false;
        }
        return CachedSegments;
    }

    //! @brief        ラベルの配列を得る
    //! @return       ラベルの配列
    [[nodiscard]] const std::deque<tTVPWaveLabel> &GetLabels() const {
        if (LabelsDirty) {
            CachedLabels.clear();
            size_t len = RustQueue->get_labels_len();
            for (size_t i = 0; i < len; ++i) {
                auto lbl = RustQueue->get_label(i);
#ifdef TVP_IN_LOOP_TUNER
                tTJSString namestr = tTJSString(lbl.name.c_str());
#else
                tTJSString namestr = tTJSString(lbl.name.c_str());
#endif
                CachedLabels.emplace_back(lbl.position, namestr, lbl.offset);
            }
            LabelsDirty = false;
        }
        return CachedLabels;
    }

    //! @brief        tTVPWaveSegmentQueueをエンキューする
    void Enqueue(const tTVPWaveSegmentQueue &queue) {
        RustQueue->enqueue_queue(*queue.RustQueue);
        SegmentsDirty = true;
        LabelsDirty = true;
    }

    //! @brief        tTVPWaveSegmentをエンキューする
    void Enqueue(const tTVPWaveSegment &segment) {
        krkr2::audio::WaveSegment ext_seg;
        ext_seg.start = segment.Start;
        ext_seg.length = segment.Length;
        ext_seg.filtered_length = segment.FilteredLength;
        RustQueue->enqueue_segment(ext_seg);
        SegmentsDirty = true;
    }

    //! @brief        tTVPWaveLabelをエンキューする
    void Enqueue(const tTVPWaveLabel &Label) {
        krkr2::audio::WaveLabel ext_lbl;
        ext_lbl.position = Label.Position;
#ifdef TVP_IN_LOOP_TUNER
        ext_lbl.name = std::string(Label.Name.c_str());
#else
        ext_lbl.name = Label.Name.AsNarrowStdString();
#endif
        ext_lbl.offset = Label.Offset;
        RustQueue->enqueue_label(ext_lbl);
        LabelsDirty = true;
    }

    //! @brief        tTVPWaveSegmentの配列をエンキューする
    void Enqueue(const std::deque<tTVPWaveSegment> &segments) {
        for (const auto &segment : segments) Enqueue(segment);
    }

    //! @brief        tTVPWaveLabelの配列をエンキューする
    void Enqueue(const std::deque<tTVPWaveLabel> &Labels) {
        tjs_int64 Label_offset = RustQueue->get_filtered_length();
        for(auto one_Label : Labels) {
            one_Label.Offset += static_cast<tjs_int>(Label_offset);
            Enqueue(one_Label);
        }
    }

    //! @brief        先頭から指定長さ分をデキューする
    void Dequeue(tTVPWaveSegmentQueue &dest, tjs_int64 length) {
        RustQueue->dequeue(*dest.RustQueue, length);
        SegmentsDirty = true;
        LabelsDirty = true;
        dest.SegmentsDirty = true;
        dest.LabelsDirty = true;
    }

    //! @brief        このキューの全体の長さを得る
    [[nodiscard]] tjs_int64 GetFilteredLength() const {
        return RustQueue->get_filtered_length();
    }

    //! @brief        このキューの長さを変化させる
    void Scale(tjs_int64 new_total_filtered_length) {
        RustQueue->scale(new_total_filtered_length);
        SegmentsDirty = true;
        LabelsDirty = true;
    }

    //! @brief        フィルタされた位置からデコード位置へ変換を行う
    [[nodiscard]] tjs_int64 FilteredPositionToDecodePosition(tjs_int64 pos) const {
        return RustQueue->filtered_position_to_decode_position(pos);
    }
    
    // Expose internal Rust Box for friends
    krkr2::audio::WaveSegmentQueue_Rust& GetRustQueue() { return *RustQueue; }
};
//---------------------------------------------------------------------------

#endif
