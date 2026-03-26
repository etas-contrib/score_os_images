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

#ifndef BOOTARGS_FDT_OUTPUT_H
#define BOOTARGS_FDT_OUTPUT_H

#include "args.h"
#include "bootargs.h"

/**
 * Dump the entire raw bootargs string to stdout, followed by a newline.
 *
 * @param bootargs  NUL-terminated bootargs string; must not be NULL.
 */
void dump_bootargs(const char *bootargs);

/**
 * Print selected key-value pairs to stdout according to the requested mode.
 *
 * Normal mode  (-e not set): prints  "KEY=VALUE\n"
 * Export mode  (-e set):     prints  "export KEY=VALUE\n" (shell-evaluable)
 *
 * A key that has no associated value (bare flag token) is printed as
 * "KEY=\n" / "export KEY=\n".
 *
 * @param pairs  NULL-terminated kv_pair_t array from parse_bootargs().
 * @param opts   Parsed CLI options (export_mode, strict, keys, num_keys).
 * @return Number of requested keys NOT found in pairs.
 *         The caller uses this to implement --strict behaviour.
 */
int output_keys(const kv_pair_t *pairs, const bootargs_opts_t *opts);

#endif /* BOOTARGS_FDT_OUTPUT_H */
