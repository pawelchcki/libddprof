load("@rules_rust//rust:defs.bzl", "rust_shared_library", "rust_static_library", "rust_test")
load("//bazel/rules/cbindgen:cbindgen.bzl", "rust_cbindgen_library")
package(default_visibility = ["//visibility:public"])

deps = [
    "//ddprof-exporter",
    "//ddprof-profiles",
    "//ddprof-ffi/cargo:chrono",
    "//ddprof-ffi/cargo:libc",
    "//ddprof-ffi/cargo:reqwest",
]

rust_shared_library(
    name = "ddprof-ffi",
    srcs = glob(["src/**/*.rs"]),
    deps = deps,
)

rust_static_library(
    name = "static",
    srcs = glob(["src/**/*.rs"]),
    deps = deps,
)

rust_test(
    name = "test",
    srcs = glob(["src/**/*.rs"]),
    deps = deps,
)

rust_cbindgen_library(
    name = "cbindgen",
    lib = ":ddprof-ffi",
    config = "cbindgen.toml",
    dirname = "ddprof-ffi" # this shouldn't be necessary
)

