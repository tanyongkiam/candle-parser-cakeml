# Run from this directory: make
.DEFAULT_GOAL := ../cake-ast-parse-ident
CC = cc
CFLAGS = -O2

../cake-ast-parse-ident: cake-ident.S basis_ffi.c
	$(CC) $(CFLAGS) cake-ident.S basis_ffi.c -DEVAL -o $@ -lm
