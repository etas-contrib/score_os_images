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

/**
 * @file main.c
 * @brief bootargs_fdt — read key=value pairs from FDT /chosen/bootargs.
 *
 * Entry point and orchestration for the bootargs_fdt utility.
 *
 * Exit codes
 *   0  Success
 *   1  Logical error (missing key in strict mode, bad arguments)
 *   2  System error  (FDT not found, mmap failed, libfdt not loaded, …)
 */

#include "args.h"
#include "bootargs.h"
#include "fdt_locate.h"
#include "fdt_map.h"
#include "libfdt_loader.h"
#include "output.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    /* ------------------------------------------------------------------ */
    /* 1. Parse command-line arguments                                     */
    /* ------------------------------------------------------------------ */
    bootargs_opts_t opts = { 0 };
    if (parse_args(argc, argv, &opts) != 0) {
        return 1;
    }

    /* ------------------------------------------------------------------ */
    /* 2. Load libfdt.so at runtime                                        */
    /* ------------------------------------------------------------------ */
    libfdt_api_t api = { 0 };
    if (load_libfdt(&api) != 0) {
        fprintf(stderr, "bootargs_fdt: failed to load libfdt.so\n");
        return 2;
    }

    /* ------------------------------------------------------------------ */
    /* 3. Locate the FDT physical address via syspage asinfo               */
    /* ------------------------------------------------------------------ */
    fdt_region_t region = { 0 };
    if (locate_fdt(&region) != 0) {
        fprintf(stderr,
                "bootargs_fdt: FDT region not found in syspage asinfo\n");
        unload_libfdt(&api);
        return 2;
    }

    /* ------------------------------------------------------------------ */
    /* 4. Map the FDT physical region into our address space               */
    /* ------------------------------------------------------------------ */
    void  *fdt         = NULL;
    size_t mapped_size = 0;
    if (map_fdt(&region, &api, &fdt, &mapped_size) != 0) {
        fprintf(stderr,
                "bootargs_fdt: failed to map FDT at physical address 0x%llx\n",
                (unsigned long long)region.phys_addr);
        unload_libfdt(&api);
        return 2;
    }

    /* ------------------------------------------------------------------ */
    /* 5. Extract /chosen/bootargs from the FDT                            */
    /* ------------------------------------------------------------------ */
    const char *bootargs = get_bootargs(fdt, &api);
    if (!bootargs) {
        fprintf(stderr,
                "bootargs_fdt: /chosen/bootargs not found in FDT\n");
        unmap_fdt(fdt, mapped_size);
        unload_libfdt(&api);
        return 2;
    }

    /* ------------------------------------------------------------------ */
    /* 6. Process and output according to user options                     */
    /* ------------------------------------------------------------------ */
    int rc = 0;

    if (opts.dump_all) {
        dump_bootargs(bootargs);
    } else {
        kv_pair_t *pairs   = parse_bootargs(bootargs);
        int        missing = output_keys(pairs, &opts);
        if (opts.strict && missing > 0) {
            rc = 1;
        }
        free_kv_pairs(pairs);
    }

    /* ------------------------------------------------------------------ */
    /* 7. Clean up                                                         */
    /* ------------------------------------------------------------------ */
    unmap_fdt(fdt, mapped_size);
    unload_libfdt(&api);

    return rc;
}
