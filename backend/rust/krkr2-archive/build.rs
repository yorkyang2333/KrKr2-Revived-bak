fn main() {
    cxx_build::bridge("src/lib.rs")
        .include("include")
        // Also include krkr2-bridge so we can access krkr2_bridge_glue.h
        .include("../krkr2-bridge/include")
        .std("c++17")
        .compile("krkr2-archive-cxxgen");

    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=include/krkr2_archive_adapter.h");
}
