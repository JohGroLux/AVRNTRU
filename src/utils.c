#include <stdlib.h>
#include <string.h>
#include "utils.h"


#ifdef __AVR__

#include <avr/io.h>

void init_uart(void)
{
  UCSR0B = _BV(TXEN) | _BV(RXEN);  // tx/rx enable
}

int uart_putch(char c, FILE *stream)
{
  if (c == '\n')
    uart_putch('\r', stream);
  loop_until_bit_is_set(UCSR0A, UDRE);
  UDR0 = c;
  
  return 0;
}

#endif  // __AVR__


void print_bytes(const char *str, const uint8_t *a, size_t len)
{
  size_t i;
  
  if ((str != NULL) && (strlen(str) > 0))
    printf(str);
  for (i = 0; i < len; i ++)
    printf("%02X", a[i]);
  printf("\n");
}


void print_words(const char *str, const uint32_t *a, size_t len)
{
  size_t i;
  
  if ((str != NULL) && (strlen(str) > 0))
    printf(str);
  for (i = 0; i < len; i ++) {  
    printf("%04x", ((uint16_t) (a[i]>>16)));
    printf("%04x", ((uint16_t) (a[i])));
  }
  printf("\n");
}
