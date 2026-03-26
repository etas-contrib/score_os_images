/*
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "libfdt_loader.h"

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

/* The QNX-provided libfdt shared library name */
#define LIBFDT_SO_NAME "libfdt.so"

int load_libfdt(libfdt_api_t *api)
{
    if (!api) {
        return -1;
    }

    memset(api, 0, sizeof(*api));

    /* Clear any previous dlerror */
    dlerror();

    api->handle = dlopen(LIBFDT_SO_NAME, RTLD_NOW);
    if (!api->handle) {
        fprintf(stderr, "bootargs_fdt: dlopen(%s) failed: %s\n",
                LIBFDT_SO_NAME, dlerror());
        return -1;
    }

/* Helper macro: resolve one symbol and check for NULL */
#define LOAD_SYM(field, name)                                          \
    do {                                                               \
        dlerror(); /* clear */                                         \
        *(void **)(&api->field) = dlsym(api->handle, name);           \
        const char *_err = dlerror();                                  \
        if (_err || !api->field) {                                     \
            fprintf(stderr,                                            \
                    "bootargs_fdt: dlsym(%s) failed: %s\n",           \
                    name, _err ? _err : "symbol is NULL");             \
            dlclose(api->handle);                                      \
            api->handle = NULL;                                        \
            return -1;                                                 \
        }                                                              \
    } while (0)

    LOAD_SYM(fdt_check_header, "fdt_check_header");
    LOAD_SYM(fdt_path_offset,  "fdt_path_offset");
    LOAD_SYM(fdt_getprop,      "fdt_getprop");
    /* fdt_totalsize is an inline/macro in libfdt.h — not exported by the .so.
     * Use fdt_get_totalsize() from libfdt_loader.h instead. */

#undef LOAD_SYM

    return 0;
}

void unload_libfdt(libfdt_api_t *api)
{
    if (api && api->handle) {
        dlclose(api->handle);
        api->handle = NULL;
    }
}
