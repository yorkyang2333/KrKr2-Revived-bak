// ZIPArchive.cpp -- ZIP archive support using minizip-ng public API
// Replaces the old hand-rolled minizip internals (unzip.c fork) with the
// official minizip-ng compatibility layer exposed in <minizip-ng/unzip.h>.
//
// Design notes:
//   - All file traversal is done via minizip-ng's public API (unzOpen2_64,
//     unzGoToFirstFile, unzGoToNextFile, unzGetFilePos64, etc.)
//   - For uncompressed (stored) entries we leverage the `disk_offset` field
//     from unz_file_info64 together with the local header size, giving us a
//     zero-copy TArchiveStream on the original tTJSBinaryStream.
//   - For compressed entries we decompress into a tTVPMemoryStream, just as
//     the original implementation did.
//   - The custom ioapi callbacks that were needed by the old code are still
//     used here; minizip-ng's unzOpen2_64 accepts a zlib_filefunc64_def so
//     we can feed it our tTJSBinaryStream-backed I/O functions.

#include "tjsCommHead.h"
#include "StorageIntf.h"
#include "UtilStreams.h"
#include <algorithm>

#include <zlib.h>
#include <minizip-ng/unzip.h>
#include <minizip-ng/ioapi.h>

// ---------------------------------------------------------------------------
// Local header layout constants (same in every ZIP implementation)
// ---------------------------------------------------------------------------
#define ZIP_LOCAL_HEADER_SIG  0x04034b50u
#define SIZEZIPLOCALHEADER    0x1e   /* 30 bytes fixed part */

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
class ZipArchive;

static voidpf       za_open   (voidpf opaque, const void *filename, int mode);
static unsigned long za_read  (voidpf opaque, voidpf stream, void *buf, unsigned long size);
static unsigned long za_write (voidpf opaque, voidpf stream, const void *buf, unsigned long size);
static ZPOS64_T      za_tell  (voidpf opaque, voidpf stream);
static long          za_seek  (voidpf opaque, voidpf stream, ZPOS64_T offset, int origin);
static int           za_close (voidpf opaque, voidpf stream);
static int           za_error (voidpf opaque, voidpf stream);

// ---------------------------------------------------------------------------
// ZipArchive
// ---------------------------------------------------------------------------
class ZipArchive : public tTVPArchive {
public:
    // The underlying binary stream.  Owned by this object.
    tTJSBinaryStream *_st = nullptr;

private:
    unzFile _uf = nullptr;

    using FileEntry = std::pair<ttstr, unz64_file_pos>;
    std::vector<FileEntry> _filelist;

    zlib_filefunc64_def _func;

public:
    ZipArchive(const ttstr &name, tTJSBinaryStream *st, bool normalize);
    ~ZipArchive() override;

    bool isValid() const { return _uf != nullptr; }

    tjs_uint GetCount() override { return (tjs_uint)_filelist.size(); }
    ttstr    GetName(tjs_uint idx) override { return _filelist[idx].first; }
    tTJSBinaryStream *CreateStreamByIndex(tjs_uint idx) override;
};

// ---------------------------------------------------------------------------
// ioapi callbacks
// ---------------------------------------------------------------------------
static voidpf za_open(voidpf /*opaque*/, const void *filename, int mode) {
    if(mode == (ZLIB_FILEFUNC_MODE_READ | ZLIB_FILEFUNC_MODE_EXISTING))
        return (voidpf)filename;   // "filename" is already our ZipArchive ptr
    return nullptr;
}

static unsigned long za_read(voidpf /*opaque*/, voidpf stream, void *buf, unsigned long size) {
    return ((ZipArchive *)stream)->_st->Read(buf, (tjs_uint)size);
}

static unsigned long za_write(voidpf /*opaque*/, voidpf stream, const void *buf, unsigned long size) {
    return ((ZipArchive *)stream)->_st->Write(buf, (tjs_uint)size);
}

static ZPOS64_T za_tell(voidpf /*opaque*/, voidpf stream) {
    return ((ZipArchive *)stream)->_st->GetPosition();
}

static long za_seek(voidpf /*opaque*/, voidpf stream, ZPOS64_T offset, int origin) {
    ((ZipArchive *)stream)->_st->Seek((tjs_int64)offset, origin);
    return 0;
}

static int za_close(voidpf /*opaque*/, voidpf /*stream*/) {
    return 0;   // stream lifetime managed by ZipArchive
}

static int za_error(voidpf /*opaque*/, voidpf /*stream*/) {
    return 0;
}

// ---------------------------------------------------------------------------
// Helper: shared declaration from TARArchive.cpp
// ---------------------------------------------------------------------------
void storeFilename(ttstr &name, const char *narrowName, const ttstr &filename);

// ---------------------------------------------------------------------------
// ZipArchive implementation
// ---------------------------------------------------------------------------
ZipArchive::ZipArchive(const ttstr &name, tTJSBinaryStream *st, bool normalize)
    : tTVPArchive(name)
{
    if(!st) st = TVPCreateStream(name);
    _st = st;

    // Build the ioapi function table
    _func.zopen64_file  = za_open;
    _func.zread_file    = za_read;
    _func.zwrite_file   = za_write;
    _func.ztell64_file  = za_tell;
    _func.zseek64_file  = za_seek;
    _func.zclose_file   = za_close;
    _func.zerror_file   = za_error;
    _func.opaque        = nullptr;

    // Open: pass `this` as the "path"; za_open will return it as the stream
    _uf = unzOpen2_64(this, &_func);
    if(!_uf) return;

    // Enumerate all entries
    if(unzGoToFirstFile(_uf) != UNZ_OK) return;
    do {
        unz64_file_pos pos;
        if(unzGetFilePos64(_uf, &pos) != UNZ_OK) continue;

        unz_file_info fi;
        char fname[1024];
        if(unzGetCurrentFileInfo(_uf, &fi, fname, sizeof(fname),
                                 nullptr, 0, nullptr, 0) != UNZ_OK)
            continue;

        ttstr filename;
        storeFilename(filename, fname, name);
        if(normalize) NormalizeInArchiveStorageName(filename);
        _filelist.emplace_back(filename, pos);

    } while(unzGoToNextFile(_uf) == UNZ_OK);

    if(normalize) {
        std::sort(_filelist.begin(), _filelist.end(),
                  [](const FileEntry &a, const FileEntry &b) {
                      return a.first < b.first;
                  });
    }
}

ZipArchive::~ZipArchive()
{
    if(_uf) { unzClose(_uf); _uf = nullptr; }
    if(_st) { delete _st;   _st = nullptr; }
}

tTJSBinaryStream *ZipArchive::CreateStreamByIndex(tjs_uint idx)
{
    if(unzGoToFilePos64(_uf, &_filelist[idx].second) != UNZ_OK)
        return nullptr;

    unz_file_info64 fi;
    if(unzGetCurrentFileInfo64(_uf, &fi, nullptr, 0, nullptr, 0, nullptr, 0) != UNZ_OK)
        return nullptr;

    if(fi.compression_method == 0) {
        // Stored (uncompressed): use a TArchiveStream for zero-copy access.
        // disk_offset is the byte offset of the local file header inside the ZIP.
        // The actual data starts after: local header (30 bytes) + filename_len +
        // extra field (both stored in the local copy, which may differ from the
        // central directory extra field length).
        //
        // We obtain the local extra field length by seeking to the local header
        // and reading it directly.
        const ZPOS64_T localHdrOff = fi.disk_offset;
        _st->SetPosition(localHdrOff + 26); // offset of filename_len in local header
        uint16_t fnLen = 0, exLen = 0;
        _st->Read(&fnLen, 2);
        _st->Read(&exLen, 2);
        ZPOS64_T dataStart = localHdrOff + SIZEZIPLOCALHEADER + fnLen + exLen;
        return new TArchiveStream(this, dataStart, fi.uncompressed_size);
    } else {
        // Compressed: decompress into memory
        if(unzOpenCurrentFile(_uf) != UNZ_OK) return nullptr;
        auto *mem = new tTVPMemoryStream();
        mem->SetSize((tjs_uint)(fi.uncompressed_size));
        unzReadCurrentFile(_uf, mem->GetInternalBuffer(), (unsigned)fi.uncompressed_size);
        unzCloseCurrentFile(_uf);
        return mem;
    }
}

// ---------------------------------------------------------------------------
// Factory function (called from StorageIntf.cpp)
// ---------------------------------------------------------------------------
tTVPArchive *TVPOpenZIPArchive(const ttstr &name, tTJSBinaryStream *st,
                               bool normalizeFileName)
{
    // Quick magic-byte check: ZIP files start with 'PK' (0x50 0x4B)
    tjs_uint64 pos = st->GetPosition();
    bool isZip = (st->ReadI16LE() == 0x4B50);
    st->SetPosition(pos);
    if(!isZip) return nullptr;

    auto *arc = new ZipArchive(name, st, normalizeFileName);
    if(!arc->isValid()) {
        arc->_st = nullptr;   // prevent double-delete; caller still owns st
        delete arc;
        return nullptr;
    }
    return arc;
}
