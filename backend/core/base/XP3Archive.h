//---------------------------------------------------------------------------
/*
        TVP2 ( T Visual Presenter 2 )  A script authoring tool
        Copyright (C) 2000 W.Dee <dee@kikyou.info> and contributors

        See details of license at "license.txt"
*/
//---------------------------------------------------------------------------
// XP3 virtual file system support
//---------------------------------------------------------------------------

#ifndef XP3ArchiveH
#define XP3ArchiveH

#include "StorageIntf.h"

/*[*/
//---------------------------------------------------------------------------
// Extraction filter related
//---------------------------------------------------------------------------
#pragma pack(push, 4)

struct tTVPXP3ExtractionFilterInfo {
    const tjs_uint SizeOfSelf; // structure size of tTVPXP3ExtractionFilterInfo itself
    const tjs_uint64 Offset; // offset of the buffer data in uncompressed stream position
    void *Buffer; // target data buffer
    const tjs_uint BufferSize; // buffer size in bytes pointed by "Buffer"
    const tjs_uint32 FileHash; // hash value of the file (since inteface v2)
    const ttstr &FileName;

    tTVPXP3ExtractionFilterInfo(tjs_uint64 offset, void *buffer,
                                tjs_uint buffersize, tjs_uint32 filehash,
                                const ttstr &filename) :
        Offset(offset), Buffer(buffer), BufferSize(buffersize),
        FileHash(filehash), FileName(filename),
        SizeOfSelf(sizeof(tTVPXP3ExtractionFilterInfo)) {
        ;
    }
};

#pragma pack(pop)

#define TVP_tTVPXP3ArchiveExtractionFilter_CONVENTION

typedef void(TVP_tTVPXP3ArchiveExtractionFilter_CONVENTION
                 *tTVPXP3ArchiveExtractionFilter)(
    tTVPXP3ExtractionFilterInfo *info, tTJSVariant *ctx);

typedef tjs_int(
    TVP_tTVPXP3ArchiveExtractionFilter_CONVENTION *tTVPXP3ArchiveContentFilter)(
    const ttstr &filepath, const ttstr &archivename, tjs_uint64 filesize, tTJSVariant *ctx);

/*]*/
//---------------------------------------------------------------------------
TJS_EXP_FUNC_DEF(void, TVPSetXP3ArchiveExtractionFilter,
                 (tTVPXP3ArchiveExtractionFilter filter));

TJS_EXP_FUNC_DEF(void, TVPSetXP3ArchiveContentFilter,
                 (tTVPXP3ArchiveContentFilter filter));
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
// tTVPXP3Archive  : XP3 ( TVP's native archive format ) Implmentation
//---------------------------------------------------------------------------
extern bool TVPIsXP3Archive(const ttstr &name); // check XP3 archive
extern void TVPClearXP3SegmentCache(); // clear XP3 segment cache
//---------------------------------------------------------------------------
struct tTVPXP3ArchiveSegment {
    tjs_uint64 Start; // start position in archive storage
    tjs_uint64 Offset; // offset in in-archive storage (in uncompressed offset)
    tjs_uint64 OrgSize; // original segment (uncompressed) size
    tjs_uint64 ArcSize; // in-archive segment (compressed) size
    bool IsCompressed; // is compressed ?
};

//---------------------------------------------------------------------------
// Forward declarations for Rust adapter subclasses
// (The actual classes are implemented in krkr2_archive_adapter.cpp)
//---------------------------------------------------------------------------
class tTVPXP3Archive : public tTVPArchive {
public:
    tTVPXP3Archive(const ttstr &name) : tTVPArchive(name) {}

    static tTVPArchive *Create(const ttstr &name,
                               tTJSBinaryStream *st = nullptr,
                               bool normalizeFileName = true);
};

#endif
