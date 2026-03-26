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

#ifndef BOOTARGS_FDT_FDT_LOCATE_H
#define BOOTARGS_FDT_FDT_LOCATE_H

#include <stdint.h>

/**
 * Physical address range of the FDT as found in the QNX syspage asinfo.
 */
typedef struct {
    uint64_t phys_addr; /* Start physical address of the FDT region */
    uint64_t size;      /* Length in bytes                          */
} fdt_region_t;

/**
 * Walk the asinfo entries in the QNX system page to locate the "fdt" region.
 *
 * The function searches for an asinfo entry whose name ends with the path
 * component "fdt" (e.g. "/memory/below4G/ram/fdt").
 *
 * @param region  Output parameter; filled on success.
 * @return 0 on success, -1 if no FDT region is found.
 */
int locate_fdt(fdt_region_t *region);

#endif /* BOOTARGS_FDT_FDT_LOCATE_H */
