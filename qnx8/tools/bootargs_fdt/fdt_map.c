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

#include "fdt_map.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>

int map_fdt(const fdt_region_t *region, const libfdt_api_t *api,
            void **fdt_ptr, size_t *mapped_size)
{
    if (!region || !api || !fdt_ptr || !mapped_size) {
        return -1;
    }

    *fdt_ptr    = NULL;
    *mapped_size = 0;

    if (region->size == 0) {
        fprintf(stderr, "bootargs_fdt: FDT region has zero size\n");
        return -1;
    }

    /*
     * Map the physical FDT memory into the process address space.
     * mmap_device_memory() is the QNX-idiomatic interface for this;
     * it works without /dev/mem and is suitable for early-startup context.
     * PROT_NOCACHE ensures the CPU does not use stale cache lines for
     * memory written by the boot-loader.
     */
    void *mapped = mmap_device_memory(
            NULL,
            (size_t)region->size,
            PROT_READ | PROT_NOCACHE,
            0,
            region->phys_addr);

    if (mapped == MAP_FAILED) {
        fprintf(stderr,
                "bootargs_fdt: mmap_device_memory(0x%llx, %llu) failed: %s\n",
                (unsigned long long)region->phys_addr,
                (unsigned long long)region->size,
                strerror(errno));
        return -1;
    }

    /* Validate FDT magic and basic header integrity */
    if (api->fdt_check_header(mapped) != 0) {
        fprintf(stderr,
                "bootargs_fdt: invalid FDT header at physical address 0x%llx\n",
                (unsigned long long)region->phys_addr);
        munmap(mapped, (size_t)region->size);
        return -1;
    }

    *fdt_ptr     = mapped;
    *mapped_size = (size_t)region->size;
    return 0;
}

void unmap_fdt(void *fdt_ptr, size_t mapped_size)
{
    if (fdt_ptr && fdt_ptr != MAP_FAILED && mapped_size > 0) {
        munmap(fdt_ptr, mapped_size);
    }
}
