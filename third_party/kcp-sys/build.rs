use bindgen::RustTarget;
use std::env;
use std::path::{Path, PathBuf};

fn android_bindgen_builder() -> bindgen::Builder {
    let mut builder = bindgen::Builder::default();
    if env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("android") {
        let target = env::var("TARGET").expect("TARGET is required for Android bindgen");
        let (clang_target, target_include) = match target.as_str() {
            "aarch64-linux-android" => ("aarch64-linux-android22", "aarch64-linux-android"),
            "armv7-linux-androideabi" => ("armv7a-linux-androideabi21", "arm-linux-androideabi"),
            "i686-linux-android" => ("i686-linux-android21", "i686-linux-android"),
            "x86_64-linux-android" => ("x86_64-linux-android21", "x86_64-linux-android"),
            _ => panic!("Unsupported Android target for bindgen: {}", target),
        };
        let ndk = env::var_os("ANDROID_NDK_HOME")
            .or_else(|| env::var_os("ANDROID_NDK_ROOT"))
            .or_else(|| env::var_os("NDK_HOME"))
            .expect("ANDROID_NDK_HOME is required for Android bindgen");
        let host = if cfg!(windows) {
            "windows-x86_64"
        } else if cfg!(target_os = "macos") {
            "darwin-x86_64"
        } else {
            "linux-x86_64"
        };
        let sysroot = PathBuf::from(ndk)
            .join("toolchains")
            .join("llvm")
            .join("prebuilt")
            .join(host)
            .join("sysroot");
        let include = sysroot.join("usr").join("include");
        builder = builder
            .clang_arg(format!("--target={}", clang_target))
            .clang_arg(format!("--sysroot={}", sysroot.display()))
            .clang_arg(format!("-I{}", include.display()))
            .clang_arg(format!("-I{}", include.join(target_include).display()));
    }
    builder
}
fn main() {
    println!("cargo:rustc-link-lib=kcp");
    let dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let fulldir = Path::new(&dir).join("kcp");

    let mut config = cc::Build::new();
    config.include(fulldir.clone());
    config.file(fulldir.join("ikcp.c"));
    config.opt_level(3);
    config.warnings(false);
    config.compile("libkcp.a");
    println!("cargo:rustc-link-search=native={}", fulldir.display());

    println!("cargo:rerun-if-changed=kcp/ikcp.h");
    println!("cargo:rerun-if-changed=kcp/ikcp.c");
    println!("cargo:rerun-if-changed=wrapper.h");

    let extra_header_path = std::env::var("KCP_SYS_EXTRA_HEADER_PATH").unwrap_or_default();
    let extra_header_paths = extra_header_path
        .split(":")
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>();

    let bindings = android_bindgen_builder()
        .header("wrapper.h")
        .rust_target(RustTarget::Stable_1_73)
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .clang_args(extra_header_paths.iter().map(|p| format!("-I{}", p)))
        .allowlist_function("ikcp_.*")
        .use_core()
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}
