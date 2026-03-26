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

#include "fdt_locate.h"

#include <sys/asinfo.h>

/**
 * walk_asinfo() callback invoked for each asinfo entry whose leaf name is
 * "fdt".  Fills in the fdt_region_t pointed to by @p data and returns 0 to
 * tell walk_asinfo() to stop (entry found).
 *
 * Callback contract (from QNX docs):
 *   return 0  → stop walking  (walk_asinfo returns 0 → success)
 *   return !0 → keep walking
 */
static int fdt_found_cb(struct asinfo_entry *as, char *name, void *data)
{
    (void)name; /* already matched by walk_asinfo — not needed here */

    fdt_region_t *region = (fdt_region_t *)data;
    region->phys_addr    = (uint64_t)as->start;
    region->size         = (uint64_t)(as->end - as->start + 1ULL);

    return 0; /* stop — we only expect one "fdt" entry */
}

int locate_fdt(fdt_region_t *region)
{
    if (!region) {
        return -1;
    }

    /*
     * walk_asinfo("fdt", ...) matches asinfo entries whose leaf name is
     * exactly "fdt" (e.g. "/memory/below4G/ram/fdt").
     * Returns 0 when the callback stopped the walk (entry found),
     * returns 1 when no matching entry was found or the walk completed
     * without the callback returning 0.
     */
    int rc = walk_asinfo("fdt", fdt_found_cb, region);

    return (rc == 0) ? 0 : -1;
}
