#ifndef _AVRNTRU_UTILS_H
#define _AVRNTRU_UTILS_H

#include <stddef.h>
#include <stdio.h>
#include "typedefs.h"

// function prototypes

#ifdef __AVR__
void init_uart(void);
int uart_putch(char c, FILE *stream);
#endif

void print_bytes(const char *str, const uint8_t *a, size_t len);
void print_words(const char *str, const uint32_t *a, size_t len);

#endif  /* _AVRNTRU_UTILS_H */
