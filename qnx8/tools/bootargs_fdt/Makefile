# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

#
# Makefile for bootargs_fdt
#
# Target: QNX 8.0 aarch64le (arm64)
#
# Prerequisites:
#   - QNX SDP 8.0 installed (QNX_HOST and QNX_TARGET set in environment, or
#     sourced via qnxsdp-env.sh)
#   - qcc available on PATH (or QCC variable set to full path)
#
# Usage:
#   make              – build bootargs_fdt
#   make clean        – remove build artefacts
#

QCC     ?= qcc
CPUVAR  ?= gcc_ntoaarch64le

CC      := $(QCC) -V$(CPUVAR)
TARGET  := bootargs_fdt

SRCS    := main.c \
           args.c \
           libfdt_loader.c \
           fdt_locate.c \
           fdt_map.c \
           bootargs.c \
           output.c

OBJS    := $(SRCS:.c=.o)

CFLAGS  := -Wall -Wextra -Wpedantic \
           -std=c11 \
           -D_QNX_SOURCE \
           -O2

LDFLAGS := 

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Header dependencies (keep roughly in sync with includes)
main.o:          main.c args.h bootargs.h fdt_locate.h fdt_map.h libfdt_loader.h output.h
args.o:          args.c args.h
libfdt_loader.o: libfdt_loader.c libfdt_loader.h
fdt_locate.o:    fdt_locate.c fdt_locate.h
fdt_map.o:       fdt_map.c fdt_map.h fdt_locate.h libfdt_loader.h
bootargs.o:      bootargs.c bootargs.h libfdt_loader.h
output.o:        output.c output.h args.h bootargs.h

clean:
	$(RM) $(TARGET) $(OBJS)
