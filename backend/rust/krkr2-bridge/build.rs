fn main() {
    // Generate C++/Rust bridge code from the #[cxx::bridge] definition.
    // The generated header will be available as:
    //   #include "krkr2-bridge/src/lib.rs.h"
    cxx_build::bridge("src/lib.rs")
        // Add our include/ directory so the generated .cc can find krkr2_bridge_glue.h
        .include("include")
        .std("c++17")
        .compile("krkr2-bridge-cxxgen");

    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=include/krkr2_bridge_glue.h");
}
