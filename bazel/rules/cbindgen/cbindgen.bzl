# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# quick hack to get cbindgen up - taken from https://github.com/bazelbuild/rules_rust/pull/392/files
# pending revival of the PR in a separate effort. once its merged we can remove this

"""Cbindgen rule for rules_rust"""

load("@rules_rust//rust/private:providers.bzl", "CrateInfo", "DepInfo")

def _rust_cbindgen_library_impl(ctx):
    """'rust_cbindgen' rule implementation
    Args:
        ctx: A context object that is passed to the implementation function for a rule or aspect.
    Returns:
        (list) a list of Providers
    """

    # Ensure the target lib is compatible with this rule.
    rust_lib = ctx.attr.lib
    supported_crate_types = ["cdylib", "staticlib"]
    if not rust_lib[CrateInfo].type in supported_crate_types:
        fail("Rust library '{}' of type '{}' must be one of {}".format(
            rust_lib.label,
            rust_lib[CrateInfo].type,
            supported_crate_types,
        ))

    # Determine the location of the cbindgen executable
    cbindgen_bin = ctx.executable._cbindgen

    config = ctx.file.config

    output_header = ctx.actions.declare_file(
        ctx.attr.header_name if ctx.attr.header_name else "{}.h".format(ctx.label.name),
    )



    args = ctx.actions.args()
    args.add("--config")
    args.add(config)
    args.add("--output")
    args.add(output_header)
    args.add(ctx.attr.dirname)
    inputs = depset(
        [config],
        transitive = [
            rust_lib[CrateInfo].srcs,
            # rust_lib[OutputGroupInfo].,
            # depset(transitive = [
            #     print(dep)
            #     for dep in rust_lib[CrateInfo].deps.to_list()
            # ]),
        ],
    )

    rust_toolchain = ctx.toolchains["@rules_rust//rust:toolchain"]
    env = {
        "CARGO": rust_toolchain.cargo.path,
        "HOST": rust_toolchain.exec_triple,
        "RUSTC": rust_toolchain.rustc.path,
        "TARGET": rust_toolchain.target_triple,
    }

    tools = depset(
        [
            rust_toolchain.cargo,
            rust_toolchain.rustc,
        ],
        transitive = [
            rust_toolchain.rustc_lib,
            rust_toolchain.rust_lib,
        ],
    )
    ctx.actions.run(
        mnemonic = "RustCbindgen",
        progress_message = "Generating bindings for '{}'..".format(
            output_header.short_path,
        ),
        outputs = [output_header],
        executable = cbindgen_bin,
        inputs = inputs,
        arguments = [args],
        tools = tools,
        env = env,
    )

    rust_compilation_context = rust_lib[CcInfo].compilation_context

    # Add the new headers to the existing CompilationContext info
    compilation_context = cc_common.create_compilation_context(
        headers = depset([output_header], transitive = [rust_compilation_context.headers]),
        defines = rust_compilation_context.defines,
        framework_includes = rust_compilation_context.framework_includes,
        includes = rust_compilation_context.includes,
        local_defines = rust_compilation_context.local_defines,
        quote_includes = rust_compilation_context.quote_includes,
        system_includes = rust_compilation_context.system_includes,
    )

    # Return all providers given by `cc_library` and `rust_library` to ensure
    # compatiblity with other rules
    return [
        rust_lib[CrateInfo],
        rust_lib[DepInfo],
        CcInfo(
            compilation_context = compilation_context,
            linking_context = rust_lib[CcInfo].linking_context,
        ),
        DefaultInfo(
            files = depset([output_header], transitive = [rust_lib.files]),
            runfiles = ctx.runfiles([output_header], transitive_files = rust_lib.files),
        ),
    ]

rust_cbindgen_library = rule(
    implementation = _rust_cbindgen_library_impl,
    attrs = {
        "lib": attr.label(
            doc = (
                "The `rust_library` target from which to run cbindgen on. " +
                "The `crate_type` of the target passed here must be " +
                "either `cdylib` or `staticlib`."
            ),
            providers = [CrateInfo, CcInfo],
            mandatory = True,
        ),
        "cbindgen_flags": attr.string_list(
            doc = (
                "Optional flags to pass directly to the bindgen executable. " +
                "See https://docs.rs/cbindgen/latest/cbindgen/ for details."
            ),
        ),
        "header_name": attr.string(
            doc = (
                "Optional override for the name of the generated header. The default is the " +
                "name of the target created by this rule."
            ),
        ),
        "dirname": attr.string(
            doc = "this should not be necessary",
        ),
        "config": attr.label(
            doc = "cbindgen configuration",
            allow_single_file = True,
        ),
        "_cbindgen": attr.label(
            doc = "cbindgen binary",
            executable = True,
            cfg = "exec",
            default = Label("//ddprof-ffi/cargo:cargo_bin_cbindgen"),
            allow_single_file = True,
        ),
    },
    toolchains = [
        "@rules_rust//rust:toolchain",
    ],
)
