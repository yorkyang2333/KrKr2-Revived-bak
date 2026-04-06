// krkr2_archive_adapter.cpp
// =========================
// C++ adapter for krkr2-archive Rust crate.
// Provides tTVPXP3Archive and tTVPXP3ArchiveStream utilizing Rust for parsing
// while preserving C++ exception handling and extraction filter compatibility.

#include "tjsCommHead.h"
#include "XP3Archive.h"
#include "MsgIntf.h"
#include "DebugIntf.h"
#include "SysInitIntf.h"

// cxx bridge headers
#include "krkr2-archive/src/lib.rs.h"
#include "krkr2_bridge_glue.h"

#include "EventIntf.h"
#include "StorageIntf.h"
#include "UtilStreams.h"

tTVPXP3ArchiveExtractionFilter TVPXP3ArchiveExtractionFilter = nullptr;

void TVPSetXP3ArchiveExtractionFilter(tTVPXP3ArchiveExtractionFilter filter) {
    TVPXP3ArchiveExtractionFilter = filter;
}

static tTVPXP3ArchiveContentFilter TVPXP3ArchiveContentFilter = nullptr;

void TVPSetXP3ArchiveContentFilter(tTVPXP3ArchiveContentFilter filter) {
    TVPXP3ArchiveContentFilter = filter;
}

// Global no-op segment cache clearer for API compatibility
// The Rust segment cache handles its own memory limits.
void TVPClearXP3SegmentCache() {
    // Note: Rust cache is bounded, no need for aggressive application-level clears
}

struct tTVPClearSegmentCacheCallback : public tTVPCompactEventCallbackIntf {
    void OnCompact(tjs_int level) override {
        if(level >= TVP_COMPACT_LEVEL_DEACTIVATE) {
            TVPClearXP3SegmentCache();
        }
    }
} static TVPClearSegmentCacheCallback;

static bool TVPClearSegmentCacheCallbackInit = false;

//---------------------------------------------------------------------------
// Original XP3 offset discovery
//---------------------------------------------------------------------------
bool TVPGetXP3ArchiveOffset(tTJSBinaryStream *st, const ttstr name, tjs_uint64 &offset, bool raise) {
    st->SetPosition(0);
    tjs_uint8 mark[11 + 1];
    static tjs_uint8 XP3Mark1[] = { 0x58, 0x50, 0x33, 0x0d, 0x0a, 0x20, 0x0a, 0x1a, 0xff };
    static tjs_uint8 XP3Mark2[] = { 0x8b, 0x67, 0x01, 0xff };

    static tjs_uint8 XP3Mark[11 + 1];
    static bool DoInit = true;
    if(DoInit) {
        DoInit = false;
        memcpy(XP3Mark, XP3Mark1, 8);
        memcpy(XP3Mark + 8, XP3Mark2, 3);
    }

    mark[0] = 0;
    st->ReadBuffer(mark, 11);
    if(mark[0] == 0x4d && mark[1] == 0x5a) {
        bool found = false;
        offset = 16;
        st->SetPosition(16);

        const tjs_uint one_read_size = 256 * 1024;
        tjs_uint read;
        tjs_uint8 *buffer = new tjs_uint8[one_read_size];

        while(0 != (read = st->Read(buffer, one_read_size))) {
            tjs_uint p = 0;
            while(p < read) {
                if(!memcmp(XP3Mark, buffer + p, 11)) {
                    offset += p;
                    found = true;
                    break;
                }
                p += 16;
            }
            if(found) break;
            offset += one_read_size;
        }
        delete[] buffer;
        if(!found) {
            if(raise) TVPThrowExceptionMessage(TVPCannotUnbindXP3EXE, name);
            else return false;
        }
    } else if(!memcmp(XP3Mark, mark, 11)) {
        offset = 0;
    } else {
        if(raise) {
            ttstr msg(TVPGetMessageByLocale("err_not_xp3_archive"));
            TVPThrowExceptionMessage(msg.c_str(), name);
        }
        return false;
    }

    return true;
}

bool TVPIsXP3Archive(const ttstr &name) {
    tTVPStreamHolder holder(name);
    try {
        tjs_uint64 offset;
        return TVPGetXP3ArchiveOffset(holder.Get(), name, offset, false);
    } catch(...) {
        return false;
    }
}

//---------------------------------------------------------------------------
// Rust Wrapper Stream
//---------------------------------------------------------------------------
class tTVPXP3ArchiveStream_Rust : public tTJSBinaryStream {
    tTVPArchive *Owner;
    tjs_int StorageIndex;
    ttstr ItemName;
    tjs_uint32 FileHash;
    tTJSBinaryStream *BaseStream;
    rust::Box<krkr2::archive::Xp3Stream> RustStream;
    tTJSVariant FilterContext;
    tjs_uint64 CurPos;

public:
    tTVPXP3ArchiveStream_Rust(
        tTVPArchive *owner, 
        tjs_int storage_index, 
        const ttstr& item_name, 
        tjs_uint32 file_hash, 
        tTJSBinaryStream *base_stream,
        rust::Box<krkr2::archive::Xp3Stream> rust_stream)
        : Owner(owner), StorageIndex(storage_index), ItemName(item_name), 
          FileHash(file_hash), BaseStream(base_stream), RustStream(std::move(rust_stream)), CurPos(0) 
    {
        Owner->AddRef();
    }

    ~tTVPXP3ArchiveStream_Rust() override {
        Owner->Release();
        if(BaseStream) delete BaseStream;
    }

    tTJSVariant &GetFilterContext() { return FilterContext; }

    tjs_uint64 Seek(tjs_int64 offset, tjs_int whence) override {
        CurPos = RustStream->seek(offset, whence);
        return CurPos;
    }

    tjs_uint Read(void *buffer, tjs_uint read_size) override {
        rust::Slice<uint8_t> slice(static_cast<uint8_t*>(buffer), read_size);
        tjs_uint read_bytes = RustStream->read(slice);

        if(read_bytes > 0 && TVPXP3ArchiveExtractionFilter) {
            tTVPXP3ExtractionFilterInfo info(
                CurPos, buffer, read_bytes, FileHash, ItemName
            );
            TVPXP3ArchiveExtractionFilter(&info, &FilterContext);
        }

        CurPos += read_bytes;
        return read_bytes;
    }

    tjs_uint Write(const void *buffer, tjs_uint write_size) override {
        TVPThrowExceptionMessage(TVPWriteError);
        return 0; // unsupported
    }

    tjs_uint64 GetSize() override {
        const tjs_uint64 saved = CurPos;
        const tjs_uint64 size = RustStream->seek(0, TJS_BS_SEEK_END);
        RustStream->seek(saved, TJS_BS_SEEK_SET);
        return size;
    }
};

//---------------------------------------------------------------------------
// Rust Wrapper Archive
//---------------------------------------------------------------------------
class tTVPXP3Archive_Rust : public tTVPXP3Archive {
    rust::Box<krkr2::archive::Xp3Archive> RustArchive;

public:
    tTVPXP3Archive_Rust(const ttstr &name, rust::Box<krkr2::archive::Xp3Archive> rust_archive)
        : tTVPXP3Archive(name), RustArchive(std::move(rust_archive)) {}

    ~tTVPXP3Archive_Rust() override = default;

    tjs_uint GetCount() override {
        return RustArchive->get_count();
    }

    ttstr GetName(tjs_uint idx) override {
        try {
            auto info = RustArchive->get_item_info(idx);
            return ttstr(info.name.c_str());
        } catch(const rust::Error& e) {
            TVPThrowExceptionMessage(TVPReadError);
            return ttstr();
        }
    }

    tTJSBinaryStream *CreateStreamByIndex(tjs_uint idx) override {
        if(!TVPClearSegmentCacheCallbackInit) {
            (void)ArchiveName.c_str(); // Trigger internal c_str() to populate memory
            TVPAddCompactEventHook(&TVPClearSegmentCacheCallback);
            TVPClearSegmentCacheCallbackInit = true;
        }

        tjs_uint32 file_hash = 0;
        ttstr item_name;
        tjs_uint64 org_size = 0;

        try {
            auto info = RustArchive->get_item_info(idx);
            file_hash = info.file_hash;
            item_name = ttstr(info.name.c_str());
            org_size = info.org_size;
        } catch(const rust::Error& e) {
            TVPThrowExceptionMessage(TVPReadError);
        }

        tTJSBinaryStream *stream = TVPCreateStream(ArchiveName);
        auto bridge_stream = krkr2::bridge::make_stream_wrapper(reinterpret_cast<size_t>(stream));

        try {
            auto rust_stream = RustArchive->create_stream_by_index(idx, std::move(bridge_stream));

            auto *out = new tTVPXP3ArchiveStream_Rust(this, idx, item_name, file_hash, stream, std::move(rust_stream));

            if(TVPXP3ArchiveContentFilter) {
                tjs_int result = TVPXP3ArchiveContentFilter(
                    item_name, ArchiveName, org_size, &out->GetFilterContext());
#define XP3_CONTENT_FILTER_FETCH_FULLDATA 1
                if(result == XP3_CONTENT_FILTER_FETCH_FULLDATA) {
                    tTVPMemoryStream *memstr = new tTVPMemoryStream();
                    memstr->SetSize(org_size);
                    out->ReadBuffer(memstr->GetInternalBuffer(), org_size);
                    delete out;
                    return memstr;
                }
            }

            return out;
        } catch(const rust::Error& e) {
            // bridge_stream took ownership and then failed? No, TVPCreateStream creates unmanaged stream.
            // Wait, does BinaryStreamWrapper delete the underlying stream?
            // In krkr2_bridge_glue, BinaryStreamWrapper does NOT delete stream. We should delete it!
            delete stream;
            TVPThrowExceptionMessage(TVPReadError);
            return nullptr;
        }
    }
};

//---------------------------------------------------------------------------
// Factory for creating the XP3 archive wrapper
//---------------------------------------------------------------------------
tTVPArchive *tTVPXP3Archive::Create(const ttstr &name, tTJSBinaryStream *st, bool normalizeFileName) {
    bool refStream = st;
    if(!st) {
        st = TVPCreateStream(name);
    }
    tjs_uint64 offset;
    if(!TVPGetXP3ArchiveOffset(st, name, offset, false)) {
        if(!refStream) delete st;
        return nullptr;
    }

    auto bridge_stream = krkr2::bridge::make_stream_wrapper(reinterpret_cast<size_t>(st));

    try {
        std::string utf8_name; // to std::string
        tjs_int len = name.GetLen();
        if(len > 0) {
            tjs_char *buf = new tjs_char[len + 1];
            (void)name.c_str();
            // Since cxx::String requires utf-8, convert ttstr to utf-8.
            ttstr utf8_ttstr(name);
            utf8_name = std::string(utf8_ttstr.AsNarrowStdString());
        }

        auto rust_archive = krkr2::archive::open_xp3_archive(std::move(bridge_stream), offset, utf8_name);
        if(!refStream) delete st;
        return new tTVPXP3Archive_Rust(name, std::move(rust_archive));
    } catch(const rust::Error& e) {
        if(!refStream) delete st; // Need to ensure properly cleaned
        return nullptr;
    }
}
