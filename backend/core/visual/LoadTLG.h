//---------------------------------------------------------------------------
/*
        TVP2 ( T Visual Presenter 2 )  A script authoring tool
        Copyright (C) 2000-2007 W.Dee <dee@kikyou.info> and
   contributors

        See details of license at "license.txt"
*/
//---------------------------------------------------------------------------
// TLG5/6 decoder — now implemented in Rust (krkr2-image crate)
//---------------------------------------------------------------------------

#ifndef LoadTLGH
#define LoadTLGH

// Rust-based TLG decoder (replaces the original C++ TVPLoadTLG)
extern "C" void TVPLoadTLG_Rust(
    void *formatdata, void *callbackdata,
    tTVPGraphicSizeCallback sizecallback,
    tTVPGraphicScanLineCallback scanlinecallback,
    tTVPMetaInfoPushCallback metainfopushcallback,
    tTJSBinaryStream *src, tjs_int keyidx,
    tTVPGraphicLoadMode mode);

// Alias for backward compatibility
#define TVPLoadTLG TVPLoadTLG_Rust

#endif
