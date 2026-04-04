fn main() {
    cxx_build::bridge("src/lib.rs")
        .include("include")
        .std("c++17")
        .compile("krkr2-image-cxxgen");

    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=include/krkr2_image_adapter.h");
}
