/*
 * Bootstrap Python Launcher
 *
 * A truly portable launcher that works on any Linux system (glibc, musl, or other).
 *
 * Strategy:
 * 1. Try to load libpython with dlopen
 * 2. If it fails (wrong libc), re-exec ourselves through bundled musl
 * 3. Try again - if still fails, give up with error
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>
#include <dlfcn.h>
#include <libgen.h>

/* Python version to load */
#define PYTHON_VERSION "3.12"
#define LIBPYTHON_NAME "libpython" PYTHON_VERSION ".so.1.0"
#define MUSL_LOADER "libc.musl-x86_64.so.1"

/* Function pointer types for Python API */
typedef int (*Py_MainFunc)(int, wchar_t **);
typedef wchar_t* (*Py_DecodeLocaleFunc)(const char*, size_t*);
typedef void (*PyMem_RawFreeFunc)(void*);

static void error_exit(const char *message, const char *detail) {
    fprintf(stderr, "Python Launcher Error: %s", message);
    if (detail) {
        fprintf(stderr, ": %s", detail);
    }
    fprintf(stderr, "\n");
    exit(1);
}

static void get_launcher_dir(char *buffer, size_t size) {
    char path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
    if (len == -1) {
        error_exit("Failed to read /proc/self/exe", strerror(errno));
    }
    path[len] = '\0';

    strncpy(buffer, dirname(path), size - 1);
    buffer[size - 1] = '\0';
}

static void build_path(char *buffer, size_t size, const char *dir, const char *relative) {
    int written = snprintf(buffer, size, "%s/%s", dir, relative);
    if (written < 0 || (size_t)written >= size) {
        error_exit("Path buffer too small", NULL);
    }

    /* Resolve to absolute path if possible */
    char resolved[PATH_MAX];
    if (realpath(buffer, resolved) != NULL) {
        strncpy(buffer, resolved, size - 1);
        buffer[size - 1] = '\0';
    }
}

static void* load_python_symbol(void *handle, const char *symbol) {
    void *func = dlsym(handle, symbol);
    if (!func) {
        error_exit("Failed to find symbol in libpython", symbol);
    }
    return func;
}

static void reexec_with_musl(int argc, char *argv[]) {
    char launcher_dir[PATH_MAX];
    get_launcher_dir(launcher_dir, sizeof(launcher_dir));

    /* Try bundled musl loader first, then system musl */
    char musl_loader[PATH_MAX];
    build_path(musl_loader, sizeof(musl_loader), launcher_dir, "../lib/" MUSL_LOADER);

    if (access(musl_loader, X_OK) != 0) {
        const char *system_musl = "/lib/ld-musl-x86_64.so.1";
        if (access(system_musl, X_OK) != 0) {
            error_exit("Cannot find musl dynamic linker", musl_loader);
        }
        strncpy(musl_loader, system_musl, sizeof(musl_loader) - 1);
    }

    /* Set up LD_LIBRARY_PATH */
    char lib_path[PATH_MAX];
    build_path(lib_path, sizeof(lib_path), launcher_dir, "../lib");

    const char *old_path = getenv("LD_LIBRARY_PATH");
    if (old_path && old_path[0]) {
        char combined[PATH_MAX * 2];
        snprintf(combined, sizeof(combined), "%s:%s", lib_path, old_path);
        setenv("LD_LIBRARY_PATH", combined, 1);
    } else {
        setenv("LD_LIBRARY_PATH", lib_path, 1);
    }

    /* Build new argv: [musl_loader, launcher_path, original_args...] */
    char launcher_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", launcher_path, sizeof(launcher_path) - 1);
    if (len == -1) {
        error_exit("Failed to read /proc/self/exe", strerror(errno));
    }
    launcher_path[len] = '\0';

    char **new_argv = malloc(sizeof(char*) * (argc + 2));
    if (!new_argv) {
        error_exit("Failed to allocate memory", NULL);
    }

    new_argv[0] = musl_loader;
    new_argv[1] = launcher_path;
    for (int i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];
    }
    new_argv[argc + 1] = NULL;

    execv(musl_loader, new_argv);
    error_exit("Failed to exec through musl loader", strerror(errno));
}

int main(int argc, char *argv[]) {
    char launcher_dir[PATH_MAX];
    get_launcher_dir(launcher_dir, sizeof(launcher_dir));

    /* Construct path to libpython */
    char libpython_path[PATH_MAX];
    build_path(libpython_path, sizeof(libpython_path), launcher_dir, "../lib/" LIBPYTHON_NAME);

    /* Try to load libpython */
    void *libpython_handle = dlopen(libpython_path, RTLD_NOW | RTLD_GLOBAL);

    if (!libpython_handle) {
        /* Any dlopen failure - try re-exec through musl */
        reexec_with_musl(argc, argv);
    }

    /* Load Python API functions */
    Py_MainFunc py_main = (Py_MainFunc)load_python_symbol(libpython_handle, "Py_Main");
    Py_DecodeLocaleFunc py_decode_locale = (Py_DecodeLocaleFunc)load_python_symbol(libpython_handle, "Py_DecodeLocale");
    PyMem_RawFreeFunc pymem_raw_free = (PyMem_RawFreeFunc)load_python_symbol(libpython_handle, "PyMem_RawFree");

    /* Convert argv to wchar_t* */
    wchar_t **wargv = (wchar_t**)malloc(sizeof(wchar_t*) * argc);
    if (!wargv) {
        error_exit("Failed to allocate memory for arguments", NULL);
    }

    for (int i = 0; i < argc; i++) {
        wargv[i] = py_decode_locale(argv[i], NULL);
        if (!wargv[i]) {
            fprintf(stderr, "Fatal Python error: unable to decode argument %d\n", i);
            exit(1);
        }
    }

    /* Run Python */
    int ret = py_main(argc, wargv);

    /* Cleanup (note: in practice, Py_Main doesn't return until exit) */
    for (int i = 0; i < argc; i++) {
        if (wargv[i]) {
            pymem_raw_free(wargv[i]);
        }
    }
    free(wargv);
    dlclose(libpython_handle);

    return ret;
}
