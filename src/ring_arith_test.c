///////////////////////////////////////////////////////////////////////////////
// ring_arith_test.c: Simple Test Programs for the Ring Arithmetic of NTRU.  //
// This file is part of AVRNTRU, a fast NTRU implementation for 8-bit AVR.   //
// Version 1.1.0 (2019-02-26), see <http://www.cryptolux.org/> for updates.  //
// Authors: Johann Groszschaedl and Hao Cheng (University of Luxembourg).    //
// License: GPLv3 (see LICENSE file), other licenses available upon request. //
// Copyright (C) 2018-2019 University of Luxembourg <http://www.uni.lu/>     //
// ------------------------------------------------------------------------- //
// This program is free software: you can redistribute it and/or modify it   //
// under the terms of the GNU General Public License as published by the     //
// Free Software Foundation, either version 3 of the License, or (at your    //
// option) any later version. This program is distributed in the hope that   //
// it will be useful, but WITHOUT ANY WARRANTY; without even the implied     //
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the  //
// GNU General Public License for more details. You should have received a   //
// copy of the GNU General Public License along with this program. If not,   //
// see <http://www.gnu.org/licenses/>.                                       //
///////////////////////////////////////////////////////////////////////////////


#include <stdio.h>
#include "config.h"
#include "ring_arith.h"
#include "ring_arith_test.h"
#include "utils.h"


#ifdef __AVR__
static FILE mystdout = FDEV_SETUP_STREAM(uart_putch, NULL, _FDEV_SETUP_WRITE);
#endif


// Example from NTRU PKCS Tutorial (Section 3)

void test_ring_mul_11(void)
{
  int i, N = 11;
  // a(x) is the public key, i.e. a polynomial of degree N-1 with coefficients
  // in the range [0, q-1]. However, our implementation requires array <a> to
  // have N+7 elements, whereby a[N] = a[0], a[N+1] = a[1], ..., a[N+6] = a[6].
  uint16_t a[18] = { 8, 25, 22, 20, 12, 24, 15, 19, 12, 19, 16, 8, 25, 22, \
                     20, 12, 24, 15 };
  // b(x) is a sparse ternary polynomial; in our example the coefficients b_2,
  // b_3, b_4 are +1, while the coefficients b_0, b_5, b_7 are -1.
  uint16_t b[6] = { 2, 3, 4, 0, 5, 7 };
  // c(x) is the message to become encrypted, a polynomial of degree N-1 with
  // coefficients in { -1, 0, 1 }.
  uint16_t c[11] = { -1, 0, 0, 1, -1, 0, 0, 0, -1, 1, 1 };
  // r(x) is the result (i.e. the ciphertext), a polynomial of degree N-1 with
  // coefficients in the range [0, q-1]. Our implementation requires the array
  // <r> to have a length that is a multiple of 8 and >= N.
  uint16_t r[16];

  for (i = 0; i < N; i ++) r[i] = 0;
  ring_mul_tern_sparse(r, a, b, 6, 11);
  for (i = 0; i < N; i ++) r[i] = (r[i] + c[i]) & 0x1F;

  printf("r = { ");
  for (i = 0; i < N-1; i ++) printf("%i, ", r[i]);
  printf("%i }\n", r[N-1]);
  // Expected result: { 14, 11, 26, 24, 14, 16, 30, 7, 25, 6, 19 }
}


void test_ring_mul_401(void)
{
  int i, N = 401;
  // Our implementation requires array <a> to have a length of N+7 elements.
  uint16_t a401[408] = { A401COEFFS }; // see ring_arith_test.h for A401COEFFS
  uint16_t b401[44] = { B401INDICES }; // see ring_arith_test.h for B401INDICES
  // The polynomial b(x) is a ternary polynomial in "product form," which means
  // it is given as b(x) = [b1(x)*b2(x) + b3(x)]. When N = 401, b1(x) and b2(x)
  // have 16 non-0 coefficients (namely eight "+1" and eight "-1"), while b3(x)
  // has 12 non-0 coefficients, half of which are "+1" and the other half "-1".
  prod_form_poly_t b = { &(b401[0]), 16, 16, 12 };
  uint16_t r[408];  // the length of array <r> must be >= N and a multiple of 8

  // Our implementation requires array <a> to have a length of N+7 elements,
  // whereby a[N] = a[0], a[N+1] = a[1], ..., and a[N+6] = a[6].
  for (i = 0; i < 7; i ++) a401[N+i] = a401[i];

  ring_mul_tern_prodform(r, a401, &b, N);

  printf("r = { ");
  for (i = 0; i < N-1; i ++) printf("%03x, ", r[i]);
  printf("%03x }\n", r[N-1]);
  // Expected result: { 002, 006, 7fc, 002, 7fe, ..., 7f2, 00d, 007, 004, 7f8 }
}


int main(void)
{
#ifdef __AVR__
  init_uart();
  stdout = &mystdout;
#endif
  
  test_ring_mul_11();
  test_ring_mul_401();
  
  // testmod3();
  
  return 0;
}
