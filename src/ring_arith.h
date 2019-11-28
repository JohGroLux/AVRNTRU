///////////////////////////////////////////////////////////////////////////////
// ring_arith.h: Polynomial Arithmetic for the NTRU Ring Z_q[x]/(x^N - 1).   //
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

#ifndef AVRNTRU_RING_ARITH_H
#define AVRNTRU_RING_ARITH_H

#include "typedefs.h"

// Struct for a product-form polynomial f(x) = f1(x)*f2(x) + f3(x) where f1(x),
// f2(x), and f3(x) are sparse ternary polynomials.

typedef struct prod_form_poly {
  uint16_t *indices;  // array with indices of non-0 coefficients in f1, f2, f3
  int num_nzc_poly1;  // number of non-0 coefficients in sparse polynomial f1
  int num_nzc_poly2;  // number of non-0 coefficients in sparse polynomial f2
  int num_nzc_poly3;  // number of non-0 coefficients in sparse polynomial f3
} prod_form_poly_t;

// Function prototypes

void ring_mul_tern_sparse_c99(uint16_t *r, const uint16_t *u, const uint16_t *v,
                              int vlen, int N);
void ring_mul_tern_prodform(uint16_t *r, const uint16_t *a,
                            const prod_form_poly_t *b, int N);

#endif  // AVRNTRU_RING_ARITH_H
