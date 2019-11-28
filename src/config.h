///////////////////////////////////////////////////////////////////////////////
// config.h: Basic Configuration of AVRNTRU (e.g. C/ASM, VLAs/static arrays) //
// This file is part of AVRNTRU, a fast NTRU implementation for 8-bit AVR.   //
// Version 1.1.0 (2019-04-19), see <http://www.cryptolux.org/> for updates.  //
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

#ifndef AVRNTRU_CONFIG_H
#define AVRNTRU_CONFIG_H

#include "typedefs.h"

// The identifier AVRNTRU_MAX_NZC has to be set to the highest number of non-0
// coefficients in the three sparse ternary polynomials f1(x), f2(x), f3(x) of
// which a product-form polynomial f(x) = f1(x)*f2(x) + f3(x) is composed of.
// If multiple parameter sets are to be supported, AVRNTRU_MAX_PM1 must be set
// to the highest number of non-0 coefficients among all sparse polynomials of
// these parameter sets. The present version of AVRNTRU supports the parameter
// sets EES443EP1, EES587EP1, and EES743EP1, of which the polynomial f3(x) in
// EES743EP1 has the highest number of non-0 coefficients, namely 30.

#define AVRNTRU_MAX_NZC 30

// The identifier AVRNTRU_MAX_DIM has to be set to the dimension N of the NTRU
// ring. If multiple parameter sets (i.e. rings of different dimension) are to
// be supported, AVRNTRU_MAX_DEG must be set to the highest dimension among all
// rings of these parameter sets, which is N = 743 for the present version of
// AVRNTRU.

#define AVRNTRU_MAX_DIM 743

// The identifier AVRNTRU_USE_ASM determines whether AVRNTRU is compiled with
// the AVR-assembler implementation or the ANSI C99 implementation of the ring
// arithmetic and all other operations that are either performance-critical or
// need to have constant execution time. On non-AVR platforms the C99 version
// is always used, irrespective of whether AVRNTRU_USE_ASM is defined or not.

#define AVRNTRU_USE_ASM

// The identifier AVRNTRU_USE_VLA determines whether AVRNTRU is compiled with
// Variable-Length Arrays (VLAs) or static arrays for the ring arithmetic (e.g.
// temporary array <t> in ring_mul_tern_prodform) and other functions that are
// implemented in a scalable fashion to support multiple parameter sets without
// re-compilation. If AVRNTRU_USE_VLA is not defined then the length of these
// arrays is fixed to a certain maximum value like AVRNTRU_MAX_DIM. Using VLAs
// reduces the stack consumption of "small" parameterizations (e.g. ES443EP1)
// when AVRNTRU is compiled for multiple parameter sets. However, VLAs inhibit
// static stack-depth analysis and are not supported by some compilers. On the
// other hand, static arrays are usually faster (and also smaller in terms of
// code size) at the expense of higher stack consumption for "small" parameter
// sets (e.g. ES443EP1 would have the same stack footprint as EES743EP1).

#define AVRNTRU_USE_VLA

// xxx

#ifndef NDEBUG
#define AVRNTRU_DEBUG_PRINT
#endif

#define AVRNTRU_NO_ERROR           0
#define AVRNTRU_ERR_xxx1           1
#define AVRNTRU_ERR_xxx2           2
#define AVRNTRU_ERR_xxx3           4

// AVRNTRU comes with optimized Assembler implementations of many "low-level"
// functions that are performance-critical and/or can potentially leak secret
// information through operand-dependent execution times. In addition, AVRNTRU
// contains a plain C99 implementation of every function to ensure it can also
// be compiled for non-AVR platforms. The Assembler version and the C version
// of a function have basically the same name, but the former is appended with
// a "_avr" suffix and the latter with a "_c99" suffix. Higher-level functions
// call these low-level functions using a suffix-less version of the function
// name, which works because the following preprocessor directives rename the
// suffix-less function into either the Assembler function or the C function,
// depending on whether AVRNTRU_USE_ASM is defined or not.

#if defined(__AVR__) && defined(AVRNTRU_USE_ASM)
extern void ring_mul_tern_sparse_avr(uint16_t *z, const uint16_t *u, \
  uint16_t *v, int vlen, int N);
#define ring_mul_tern_sparse(z, u, v, vlen, N) \
  ring_mul_tern_sparse_avr((z), (u), (v), (vlen), (N))
#else   // the C versions of the functions are used
#define ring_mul_tern_sparse(z, u, v, vlen, N) \
  ring_mul_tern_sparse_c99((z), (u), (v), (vlen), (N))
#endif  // defined(__AVR__) && ...

#endif  // AVRNTRU_CONFIG_H
