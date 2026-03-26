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

#ifndef BOOTARGS_FDT_LIBFDT_LOADER_H
#define BOOTARGS_FDT_LIBFDT_LOADER_H

#include <stdint.h>

/**
 * Minimal FDT header layout (first 7 big-endian uint32_t fields).
 * Matches the public libfdt fdt_header struct exactly.
 * Used to read fdt_totalsize without needing a dlsym'd function
 * (fdt_totalsize is an inline/macro in libfdt — not an exported symbol).
 */
typedef struct {
    uint32_t magic;          /* 0xd00dfeed */
    uint32_t totalsize;      /* total FDT blob size in bytes (big-endian) */
    uint32_t off_dt_struct;
    uint32_t off_dt_strings;
    uint32_t off_mem_rsvmap;
    uint32_t version;
    uint32_t last_comp_version;
} fdt_header_raw_t;

/**
 * Return the total size of the FDT blob in bytes.
 * Reads the big-endian totalsize field from the raw header and byte-swaps it.
 * This replicates the fdt_totalsize() macro from libfdt.h without requiring
 * the symbol to be exported by the .so.
 */
static inline uint32_t fdt_get_totalsize(const void *fdt)
{
    const fdt_header_raw_t *hdr = (const fdt_header_raw_t *)fdt;
    /* Convert from big-endian (FDT on-disk format) to host byte order */
    uint32_t be = hdr->totalsize;
    return (uint32_t)(
        ((be & 0xff000000u) >> 24) |
        ((be & 0x00ff0000u) >>  8) |
        ((be & 0x0000ff00u) <<  8) |
        ((be & 0x000000ffu) << 24));
}

/**
 * Function pointers mirroring the required libfdt API subset.
 * libfdt.so is loaded at runtime via dlopen() to avoid a build-time
 * dependency on an undocumented QNX library.
 *
 * Note: fdt_totalsize is intentionally absent — it is an inline macro in
 * libfdt.h and therefore not exported by libfdt.so.  Use fdt_get_totalsize()
 * declared above instead.
 */
typedef struct {
    void       *handle;                              /* dlopen handle          */

    int        (*fdt_check_header)(const void *fdt); /* validate FDT magic     */
    int        (*fdt_path_offset)(const void *fdt,
                                  const char *path); /* find node by path      */
    const void *(*fdt_getprop)(const void *fdt,
                               int nodeoffset,
                               const char *name,
                               int *lenp);           /* read property value    */
} libfdt_api_t;

/**
 * Load libfdt.so via dlopen() and resolve all required symbols.
 *
 * @param api  Output structure; must not be NULL.
 * @return 0 on success, -1 on failure (diagnostic printed to stderr).
 */
int load_libfdt(libfdt_api_t *api);

/**
 * Release the library handle obtained by load_libfdt().
 *
 * @param api  Must not be NULL.
 */
void unload_libfdt(libfdt_api_t *api);

#endif /* BOOTARGS_FDT_LIBFDT_LOADER_H */
