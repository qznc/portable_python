def _python_derived_dist_impl(ctx):
    python_exe = ctx.executable.python_exe
    requirements_txt = ctx.file.requirements_txt
    dist_dir = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run(
        executable=python_exe,
        arguments=["-m", "ppd_instantiate", dist_dir.path, requirements_txt.path],
        inputs=[python_exe, requirements_txt],
        outputs=[dist_dir],
    )
    # Bazel cannot have the executable in the same folder as the runfiles
    # thus we must create a wrapper script:
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output=launcher,
        content="""#!/bin/sh
PY_EXE=$(find . -name "python3" -executable)
exec "$PY_EXE" "$@"
""",
        is_executable=True,
    )
    return DefaultInfo(
        files=depset([launcher]),
        executable=launcher,
        runfiles=ctx.runfiles(files=[dist_dir]),
    )

python_derived_dist = rule(
    implementation=_python_derived_dist_impl,
    attrs={
        "python_exe": attr.label(executable=True, cfg="exec", mandatory=True,
            doc="A Portable Python distribution"),
        "requirements_txt": attr.label(allow_single_file=True,
            doc="Python modules to install"),
    },
)

## SPHINX BUILD

def _uses_python_impl(ctx):
    out = ctx.actions.declare_directory("html")
    src_folder = "WHERE_CONF_PY"
    for f in ctx.files.srcs:
        if f.basename != "conf.py":
            continue
        src_folder = f.dirname  # found a conf.py, use this dir as source root
        break
    ctx.actions.run(
        executable = ctx.executable.python_distro,
        arguments = [
            "-m", "sphinx", "build",
            "-b", "html",
            src_folder,
            out.path,
        ],
        inputs = ctx.files.srcs,
        outputs = [out],
    )
    return [DefaultInfo(files = depset([out]))]


sphinx_build = rule(
    implementation=_uses_python_impl,
    attrs={
        "python_distro": attr.label(executable=True, cfg="exec"),
        "srcs": attr.label_list(allow_files=True),
    },
)
