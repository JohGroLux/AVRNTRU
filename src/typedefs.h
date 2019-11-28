///////////////////////////////////////////////////////////////////////////////
// typedefs.h: Definition of Fixed-Widh Integer Types for Pre-C99 Compilers. //
// This file is part of AVRNTRU, a fast NTRU implementation for 8-bit AVR.   //
// Version 1.0.0 (2018-12-17), see <http://www.cryptolux.org/> for updates.  //
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

#ifndef AVRNTRU_TYPEDEFS_H
#define AVRNTRU_TYPEDEFS_H

// The 1999 update to ISO C (i.e. the ISO C99 standard) defined a set of basic
// fixed-width integer types, which can be used in C programs by including the
// header file <stdint.h>. However, they are not supported by pre-C99 compilers
// like Microsoft's Visual C. The following type-definitions bring some of the
// fixed-width integers to Visual C.

#if (defined(_MSC_VER) && !defined(__ICL))
typedef __int8 int8_t;
typedef unsigned __int8 uint8_t;
typedef __int16 int16_t;
typedef unsigned __int16 uint16_t;
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#else
#include <stdint.h>
#endif

#endif  // AVRNTRU_TYPEDEFS_H
