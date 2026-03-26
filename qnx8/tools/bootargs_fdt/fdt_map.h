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

#ifndef BOOTARGS_FDT_FDT_MAP_H
#define BOOTARGS_FDT_FDT_MAP_H

#include "fdt_locate.h"
#include "libfdt_loader.h"

#include <stddef.h>

/**
 * Map the FDT physical region into the process virtual address space using
 * mmap_device_memory() (QNX extension).
 *
 * After a successful mapping the FDT header is validated via
 * api->fdt_check_header().
 *
 * @param region       Physical address and size of the FDT region (from asinfo).
 * @param api          Loaded libfdt function pointers.
 * @param fdt_ptr      Output: virtual address of the mapped FDT base.
 * @param mapped_size  Output: number of bytes mapped (use for unmap_fdt).
 * @return 0 on success, -1 on failure (diagnostic printed to stderr).
 */
int map_fdt(const fdt_region_t *region, const libfdt_api_t *api,
            void **fdt_ptr, size_t *mapped_size);

/**
 * Unmap a previously mapped FDT.
 *
 * @param fdt_ptr     Virtual base address returned by map_fdt().
 * @param mapped_size Number of bytes passed to mmap_device_memory().
 */
void unmap_fdt(void *fdt_ptr, size_t mapped_size);

#endif /* BOOTARGS_FDT_FDT_MAP_H */
