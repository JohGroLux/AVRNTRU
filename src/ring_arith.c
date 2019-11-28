///////////////////////////////////////////////////////////////////////////////
// ring_arith.c: Polynomial Arithmetic for the NTRU Ring Z_q[x]/(x^N - 1).   //
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


#include "config.h"
#include "ring_arith.h"


// The macro INTMASK(x) converts an integer x to an "all-1" mask when x = 1 and
// to an "all-0" mask when x = 0.

#define INTMASK(x) (~((x) - 1))


// The following preprocessor directives define the length of two local arrays
// in the ring arithmetic, namely array <index> in ring_mul_tern_sparse and <t>
// in ring_mul_tern_prodform. Depending on AVRNTRU_USE_VLA, these lengths are
// defined such that the concerned arrays become either Variable-Length Arrays
// (VLAs) or static arrays (see config.h for further information).

#ifdef AVRNTRU_USE_VLA
// Microsoft Visual C does not support VLAs
#if !(defined(_MSC_VER) && !defined(__ICL))
#define _vlen vlen
#define _tlen (N + 7)
#else  // static arrays are used
#define _vlen AVRNTRU_MAX_NZC
#define _tlen (AVRNTRU_MAX_DIM + 7)
#endif
#endif


// The function <ring_mul_tern_sparse_c99> performs a polynomial multiplication
// z(x) = u(x)*v(x) in the quotient ring R = (Z/Zq)[x]/(x^N-1), where u(x) is
// an arbitrary element of the ring (i.e. a polynomial of degree up to N-1 with
// coefficients in [0, q-1]) and v(x) is a ternary polynomial of degree up to
// N-1. Both the operand u(x) and the result r(x) are represented by arrays of
// 16-bit unsigned integers containing the coefficients of the polynomial (the
// element with index 0 holds the least-significant coefficient). The array <u>
// consists of N+7 elements, whereby u[0]-u[N-1] contain the <N> coefficients
// of u(x) and u[N+i] = u[i] for 0 <= i < 7. On the other hand, the length of
// the result-array <z> is the smallest multiple of eight that is greater than
// or equal to <N>. The operand v(x) is represented by <v>, an array of 16-bit
// unsigned integers whose elements contain the indices of the "+1" and "-1"
// coefficients (and not the coefficients themselves!). This array consists of
// <vlen> elements, whereby the first half (i.e. v[0]-v[vlen/2-1]) holds the
// indices of the "+1" coefficients and the second half the indices of the "-1"
// coefficients. The coefficients of the product z(x) are written to the first
// <N> elements of array <z> and are not reduced modulo q, which means they can
// even be negative. Note that the up to seven remaining elements of array <z>
// will contain arbitrary values and can be ignored. It is assumed that <z> has
// been initialized to 0 before calling the function; if not, a MAC operation
// of the form z(x) = z(x) + u(x)*v(x) is computed instead of a multiplication.

void ring_mul_tern_sparse_c99(uint16_t *r, const uint16_t *u, const uint16_t *v,
                              int vlen, int N)
{
  int index[_vlen], i, j, idx;
  register uint16_t sum0, sum1, sum2, sum3, sum4, sum5, sum6, sum7;

  // compute index = -j mod N for every j for which coefficient v_j != 0
  for (i = 0; i < vlen; i ++)
    index[i] = INTMASK(v[i] != 0) & (N - v[i]);

  for (i = 0; i < N; i += 8) {
    // hybrid method: load eight coefficients of r(x) to eight registers
    sum0 = r[i  ]; sum1 = r[i+1]; sum2 = r[i+2]; sum3 = r[i+3];
    sum4 = r[i+4]; sum5 = r[i+5]; sum6 = r[i+6]; sum7 = r[i+7];
    // process all "+1" coefficients of the sparse ternary polynomial v(x)
    for (j = 0; j < vlen/2; j ++) {
      idx = index[j];
      sum0 += u[idx++]; sum1 += u[idx++]; sum2 += u[idx++]; sum3 += u[idx++];
      sum4 += u[idx++]; sum5 += u[idx++]; sum6 += u[idx++]; sum7 += u[idx++];
      index[j] = idx - (INTMASK(idx >= N) & N);
    }
    // process all "-1" coefficients of the sparse ternary polynomial v(x)
    for (j = vlen/2; j < vlen; j ++) {
      idx = index[j];
      sum0 -= u[idx++]; sum1 -= u[idx++]; sum2 -= u[idx++]; sum3 -= u[idx++];
      sum4 -= u[idx++]; sum5 -= u[idx++]; sum6 -= u[idx++]; sum7 -= u[idx++];
      index[j] = idx - (INTMASK(idx >= N) & N);
    }
    // hybrid method: write the (updated) eight coefficients back to RAM
    r[i  ] = sum0; r[i+1] = sum1; r[i+2] = sum2; r[i+3] = sum3;
    r[i+4] = sum4; r[i+5] = sum5; r[i+6] = sum6; r[i+7] = sum7;
  }
}


// The function <ring_mul_tern_sparse_V2> is a more compact implementation of
// the function <ring_mul_tern_sparse_c99> above to show that a multiplication
// of a ring-element by a sparse ternary polynomial requires just 25 lines of
// C code.

void ring_mul_tern_sparse_V2(uint16_t *r, const uint16_t *u, const uint16_t *v,
                             int vlen, int N)
{
  int index[_vlen], i, j, k;

  // compute index = -j mod N for every j for which coefficient v_j != 0
  for (i = 0; i < vlen; i ++)
    index[i] = INTMASK(v[i] != 0) & (N - v[i]);

  for (i = 0; i < N; i += 8) {
    // process the "+1" coefficients of the sparse ternary polynomial v(x)
    for (j = 0; j < vlen/2; j ++) {
      k = index[j];
      r[i  ] += u[k  ]; r[i+1] += u[k+1]; r[i+2] += u[k+2]; r[i+3] += u[k+3];
      r[i+4] += u[k+4]; r[i+5] += u[k+5]; r[i+6] += u[k+6]; r[i+7] += u[k+7];
      index[j] = k + 8 - (INTMASK(k + 8 >= N) & N);
    }
    // process the "-1" coefficients of the sparse ternary polynomial v(x)
    for (j = vlen/2; j < vlen; j ++) {
      k = index[j];
      r[i  ] -= u[k  ]; r[i+1] -= u[k+1]; r[i+2] -= u[k+2]; r[i+3] -= u[k+3];
      r[i+4] -= u[k+4]; r[i+5] -= u[k+5]; r[i+6] -= u[k+6]; r[i+7] -= u[k+7];
      index[j] = k + 8 - (INTMASK(k + 8 >= N) & N);
    }
  }
}


// The function <ring_mul_tern_prodform> performs a polynomial multiplication
// r(x) = a(x)*b(x) in the quotient ring R = (Z/Zq)[x]/(x^N-1), where a(x) is
// an arbitrary element of the ring (i.e. a polynomial of degree up to N-1 with
// coefficients in [0, q-1]) and b(x) is a ternary polynomial given in "product
// form" (i.e. b(x) = b1(x)*b2(x) + b3(x) is composed of three sub-polynomials
// b1(x), b2(x), and b3(x), all of which are sparse and have a degree of up to
// N-1). Both the operand u(x) and the result r(x) are represented by arrays of
// 16-bit unsigned integers containing the coefficients of the polynomial (the
// element with index 0 holds the least-significant coefficient). The array <a>
// consists of N+7 elements, whereby a[0]-a[N-1] contain the <N> coefficients
// of a(x) and a[N+i] = a[i] for 0 <= i < 7. On the other hand, the length of
// the result-array <r> is the smallest multiple of eight that is greater than
// or equal to <N>. The second operand b(x) is a product-form polynomial and
// represented by the struct prod_form_poly_t (defined in ring_arith.h), which
// consists of (i) an array containing the indices of the non-0 coefficients of
// b1(x), b2(x), b3(x), and (ii) three integers specifying the number of non-0
// coefficients of each sub-polynomial. The coefficients of the product r(x)
// are written to the first <N> elements of array <r> and are reduced modulo
// q = 2^11 = 2048. Note that the up to seven remaining elements of array <z>
// will contain arbitrary values and can be ignored.

void ring_mul_tern_prodform(uint16_t *r, const uint16_t *a,
                            const prod_form_poly_t *b, int N)
{
  int i;
  uint16_t t[_tlen], *bstart = b->indices;

  // Initialization of array <r> and <t>
  for (i = ((N+7)&(-8))-1; i >= 0; i--) r[i] = t[i] = 0;
  // 1st multiplication: t(x) = a(x)*b1(x)
  ring_mul_tern_sparse(t, a, bstart, b->num_nzc_poly1, N);
  // 2nd multiplication: r(x) = t(x)*b2(x) = a(x)*b1(x)*b2(x)
  bstart = &(b->indices[b->num_nzc_poly1]);
  for (i = 6; i >= 0; i--) t[N+i] = t[i];
  ring_mul_tern_sparse(r, t, bstart, b->num_nzc_poly2, N);
  // 3rd multiplication: r(x) = r(x) + a(x)*b3(x) = a(x)*[b1(x)*b2(x) + b3(x)]
  bstart = &(b->indices[b->num_nzc_poly1 + b->num_nzc_poly2]);
  ring_mul_tern_sparse(r, a, bstart, b->num_nzc_poly3, N);
  // Reduction of the coefficients of r(x) modulo 2048
  for (i = N-1; i >= 0; i--) r[i] &= 0x07FF;
}
