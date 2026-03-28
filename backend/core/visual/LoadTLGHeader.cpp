//---------------------------------------------------------------------------
/*
        TVP2 ( T Visual Presenter 2 )  A script authoring tool
        Copyright (C) 2000 W.Dee <dee@kikyou.info> and contributors

        See details of license at "license.txt"
*/
//---------------------------------------------------------------------------
// TLG header reader (extracted from LoadTLG.cpp)
// The main TLG5/6 decoding logic has been moved to Rust (krkr2-image crate).
//---------------------------------------------------------------------------
#include "tjsCommHead.h"

#include "GraphicsLoaderIntf.h"
#include "MsgIntf.h"
#include "tjsDictionary.h"

#include <stdlib.h>

//---------------------------------------------------------------------------
void TVPLoadHeaderTLG(void *formatdata, tTJSBinaryStream *src,
                      iTJSDispatch2 **dic) {
    if(dic == nullptr)
        return;

    // read header
    unsigned char mark[12];
    src->ReadBuffer(mark, 11);

    tjs_int width = 0;
    tjs_int height = 0;
    tjs_int colors = 0;
    // check for TLG0.0 sds
    if(!memcmp("TLG0.0\x00sds\x1a\x00", mark, 11)) {
        // read raw data size
        tjs_uint rawlen = src->ReadI32LE();
        (void)rawlen;
        src->ReadBuffer(mark, 11);
        if(!memcmp("TLG5.0\x00raw\x1a\x00", mark, 11)) {
            src->ReadBuffer(mark, 1);
            colors = mark[0];
            width = src->ReadI32LE();
            height = src->ReadI32LE();
        } else if(!memcmp("TLG6.0\x00raw\x1a\x00", mark, 11)) {
            src->ReadBuffer(mark, 4);
            colors = mark[0]; // color component count
            width = src->ReadI32LE();
            height = src->ReadI32LE();
        } else {
            TVPThrowExceptionMessage(
                TVPTLGLoadError,
                (const tjs_char *)TVPInvalidTlgHeaderOrVersion);
        }
    } else if(!memcmp("TLG5.0\x00raw\x1a\x00", mark, 11)) {
        src->ReadBuffer(mark, 1);
        colors = mark[0];
        width = src->ReadI32LE();
        height = src->ReadI32LE();
    } else if(!memcmp("TLG6.0\x00raw\x1a\x00", mark, 11)) {
        src->ReadBuffer(mark, 4);
        colors = mark[0]; // color component count
        width = src->ReadI32LE();
        height = src->ReadI32LE();
    } else {
        TVPThrowExceptionMessage(
            TVPTLGLoadError, (const tjs_char *)TVPInvalidTlgHeaderOrVersion);
    }
    tjs_int bpp = colors * 8;
    *dic = TJSCreateDictionaryObject();
    tTJSVariant val(width);
    (*dic)->PropSet(TJS_MEMBERENSURE, TJS_W("width"), nullptr, &val, (*dic));
    val = tTJSVariant(height);
    (*dic)->PropSet(TJS_MEMBERENSURE, TJS_W("height"), nullptr, &val, (*dic));
    val = tTJSVariant(bpp);
    (*dic)->PropSet(TJS_MEMBERENSURE, TJS_W("bpp"), nullptr, &val, (*dic));
}
//---------------------------------------------------------------------------
