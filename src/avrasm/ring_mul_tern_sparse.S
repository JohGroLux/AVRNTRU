///////////////////////////////////////////////////////////////////////////////
// ring_mul_tern_sparse.S: Ring Multiplication (Sparse Ternary Polynomials). //
// This file is part of AVRNTRU, a fast NTRU implementation for 8-bit AVR.   //
// Version 1.1.1 (2019-03-15), see <http://www.cryptolux.org/> for updates.  //
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


// Function prototype:
// -------------------
// void ring_mul_tern_sparse_avr(uint16_t *z, const uint16_t *u,
//                               const uint16_t *v, int vlen, int N);
//
// Description:
// ------------
// The function <ring_mul_tern_sparse_avr> performs a polynomial multiplication
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
//
// Parameters:
// -----------
// <z>: address of uint16-array of length 8*ceil(N/8) for coefficients of z(x)
// <u>: address of uint16-array of length N+7 for coefficients of u(x)
// <v>: address of uint16-array of length <vlen> for indices of the "+1" and
//      "-1" coefficients of v(x)
// <vlen>: number of non-0 coefficients of v(x), always even in classical NTRU
// <N>: dimension of the polynomial ring R, always a prime in classical NTRU
//
// Execution time on ATmega128 (including function-call overhead):
// ---------------------------------------------------------------
// N=443, vlen=??: xx cycles (to be added)
//
// Version history:
// ----------------
// 1.0.0: First implementation with separate loops for coeff-add and coeff-sub
// 1.1.0: Merged addition and subtraction of coefficients to a single main loop
// 1.1.1: Small performance improvements and further comments added by Johann


// Device-specific definitions
#include "avr/io.h"


///////////////////////////////////////////////////////////////////////////////
/////////////// DEFINITIONS TO GIVE REGISTERS A MEANINGFUL NAME ///////////////
///////////////////////////////////////////////////////////////////////////////

// lo-byte of a 16-bit coefficient
#define COEFL R24
// hi-byte of a 16-bit coefficient
#define COEFH R25

// lo-byte of a 16-bit index (shared with COEFL)
#define IDXL R24
// hi-byte of a 16-bit index (shared with COEFL)
#define IDXH R25

// lo-byte of a 16-bit temporary variable (shared with COEFL and IDXL)
#define TMPL R24
// hi-byte of a 16-bit temporary variable (shared with COEFH and IDXH)
#define TMPH R25

// lo-byte of address of element u[N] (resp. u[N-1]) of array <u>
#define ADUNL R22
// hi-byte of address of element u[N] (resp. u[N-1]) of array <u>
#define ADUNH R23

// loop-counter (for main loop)
#define LCTR R20
// Loop-stopper (for inner loops)
#define LSTOP R21

// length of array <v>
#define VLEN R18
// ZERO is always 0
#define ZERO R19

// lo-byte of 16-bit integer 2N
#define TWONL R16
// hi-byte of 16-bit integer 2N
#define TWONH R17

// lo-byte of a 16-bit mask
#define MASKL R14
// hi-byte of a 16-bit mask
#define MASKH R15

// registers for eight coefficient-sums
#define SUM0L R0
#define SUM0H R1
#define SUM1L R2
#define SUM1H R3
#define SUM2L R4
#define SUM2H R5
#define SUM3L R6
#define SUM3H R7
#define SUM4L R8
#define SUM4H R9
#define SUM5L R10
#define SUM5H R11
#define SUM6L R12
#define SUM6H R13
#define SUM7L R14
#define SUM7H R15


// Program flash data section (in code memory space)
.section .text


///////////////////////////////////////////////////////////////////////////////
/////// MACRO TO PUSH CALLEE-SAVED REGISTERS AND ALLOCATE SPACE ON STACK //////
///////////////////////////////////////////////////////////////////////////////

.macro RING_MUL_PROLOGUE
    // Push callee-saved registers on the stack.
    PUSH R0
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8
    PUSH R9
    PUSH R10
    PUSH R11
    PUSH R12
    PUSH R13
    PUSH R14
    PUSH R15
    PUSH R16
    PUSH R17
    PUSH R28
    PUSH R29
    // Allocate 2VLEN bytes on stack and set Y to the address of first byte.
    IN   YL, _SFR_IO_ADDR(SPL)
    IN   YH, _SFR_IO_ADDR(SPH)
    SUB  YL, VLEN
    SBC  YH, ZERO
    SUB  YL, VLEN
    SBC  YH, ZERO
    IN   ZERO, _SFR_IO_ADDR(SREG)
    CLI
    OUT  _SFR_IO_ADDR(SPH), YH
    OUT  _SFR_IO_ADDR(SREG), ZERO
    OUT  _SFR_IO_ADDR(SPL), YL
    ADIW YL, 1
.endm


///////////////////////////////////////////////////////////////////////////////
////// MACRO TO POP CALLEE-SAVED REGISTERS AND DE-ALLOCATE SPACE ON STACK /////
///////////////////////////////////////////////////////////////////////////////

.macro RING_MUL_EPILOGUE
    // De-allocate 2VLEN bytes from the stack.
    IN   YL, _SFR_IO_ADDR(SPL)
    IN   YH, _SFR_IO_ADDR(SPH)
    ADD  YL, VLEN
    ADC  YH, ZERO
    ADD  YL, VLEN
    ADC  YH, ZERO
    IN   ZERO, _SFR_IO_ADDR(SREG)
    CLI
    OUT  _SFR_IO_ADDR(SPH), YH
    OUT  _SFR_IO_ADDR(SREG), ZERO
    OUT  _SFR_IO_ADDR(SPL), YL
    // Pop callee-saved registers from the stack.
    POP  R29
    POP  R28
    POP  R17
    POP  R16
    POP  R15
    POP  R14
    POP  R13
    POP  R12
    POP  R11
    POP  R10
    POP  R9
    POP  R8
    POP  R7
    POP  R6
    POP  R5
    POP  R4
    POP  R3
    POP  R2
    POP  R0
    CLR  R1
.endm


///////////////////////////////////////////////////////////////////////////////
////////////// MACRO TO INITIALIZE LOCAL VARIABLES AND POINTERS ///////////////
///////////////////////////////////////////////////////////////////////////////

.macro INIT_LOCAL_VARS  // 17 CYCLES
    // We use Z-pointer to access array <z> and X-pointer to access array <v>,
    // which holds the indices of the non-0 coefficients of polynomial v(x).
    MOVW ZL, R24
    MOVW XL, R20
    // Due to the hybrid method, the main loop is iterated only ceil(N/8) times
    // and, consequently, LCTR has to be initialized with (N+7)>>3.
    MOVW LCTR, TWONL
    LDI  TMPL, 7
    CLR  ZERO
    ADD  LCTR, TMPL
    ADC  LSTOP, ZERO
    LSR  LSTOP
    ROR  LCTR
    LSR  LSTOP
    ROR  LCTR
    LSR  LSTOP
    ROR  LCTR
    // Having 2N instead of N in a register pair simplifies address arithmetic.
    ADD  TWONL, TWONL
    ADC  TWONH, TWONH
    // Set register pair (ADUNH:ADUNL) to address of element u[N] of array <u>.
    ADD  ADUNL, TWONL
    ADC  ADUNH, TWONH
.endm


///////////////////////////////////////////////////////////////////////////////
// MACRO TO CALCULATE COEFFICIENT ADDRESSES FOR FIRST ITERATION OF MAIN LOOP //
///////////////////////////////////////////////////////////////////////////////

// The macro CALC_COEFF_ADDR loops through the <vlen> elements of array <v>,
// which contains the indices of the "+1" and "-1" coefficients of the ternary
// polynomial v(x), and calculates the addresses of the corresponding elements
// of array <u>. Concretely, for every element j of array <v>, the address of
// coefficient u_i (i.e. element u[i] of <u>) with i = -j mod N is calculated
// and stored in a temporary array accessed via the Y-pointer. When i = 0, the
// address of u[0] is stored, otherwise the address of u[N-j].

.macro CALC_COEFF_ADDR  // xx cycles per iteration
    // The following loop L1 is iterated VLEN times, whereby VLEN is expected
    // to be small enough so that a single 8-bit register (namely LSTOP) can be
    // used to determine whether the loop-termination condition is satisfied.
    // In each iteration, the Y-pointer is incremented by 2 (since the elements
    // of the array consist of 2 bytes) and the loop terminates when Y-pointer
    // reaches the (2VLEN+1)-th byte of the temporary array. Hence, LSTOP must
    // be set to the lo-byte of this specific address before entering the loop.
    MOV  LSTOP, VLEN    // copy VLEN to the loop-stopper register LSTOP
    ADD  LSTOP, LSTOP   // double register LSTOP so that it now contains 2VLEN
    ADD  LSTOP, YL      // loop stops if Y reaches (2VLEN+1)-th byte of array
L1: //------------------------ START OF THE 1ST LOOP ------------------------//
    LD   IDXL, X+       // load lo-byte of 16-bit index j from <v> via X-ptr
    LD   IDXH, X+       // load hi-byte of 16-bit index j from <v> via X-ptr
    ADD  IDXL, IDXL     // double IDXL to convert index j into a byte-offset
    ADC  IDXH, IDXH     // double IDXH to convert index j into a byte-offset
    COM  IDXL           // calculate 1's complement of IDXL (bitwise inverse)
    COM  IDXH           // calculate 1's complement of IDXH (bitwise inverse)
    ADIW IDXL, 1        // calculate 2's complement of (IDXH:IDXL) by adding 1
    SBC  MASKL, MASKL   // MASKL is either 0xFF (if j was 0) or 0 otherwise
    MOV  MASKH, MASKL   // MASKH is either 0xFF (if j was 0) or 0 otherwise
    ADD  IDXL, ADUNL    // IDXL contains now lo-byte of the address of u[N-j]
    ADC  IDXH, ADUNH    // IDXL contains now hi-byte of the address of u[N-j]
    AND  MASKL, TWONL   // MASKL is either lo8(2N) (if j was 0) or 0 otherwise
    AND  MASKH, TWONH   // MASKH is either hi8(2N) (if j was 0) or 0 otherwise
    SUB  IDXL, MASKL    // IDXL holds lo-byte of addr of u[i] with i = -j mod N
    SBC  IDXH, MASKH    // IDXL holds hi-byte of addr of u[i] with i = -j mod N
    ST   Y+, IDXL       // store lo-byte of address of u[i] to temporary array
    ST   Y+, IDXH       // store hi-byte of address of u[i] to temporary array
    CPSE LSTOP, YL      // check if Y reached (2VLEN+1)-th byte of tmp array
    RJMP L1             // if not then jump back to the start of the loop
    //------------------------- END OF THE 1ST LOOP -------------------------//
    SUB  YL, VLEN       // subtract VLEN from Y-ptr to restore original address
    SBC  YH, ZERO       // propagate carry to the higher byte of the Y-pointer
    SUB  YL, VLEN       // subtract VLEN from Y-ptr to restore original address
    SBC  YH, ZERO       // propagate carry to the higher byte of the Y-pointer
    // The address-arithmetic performed in the rest of this function, e.g. in
    // macro STORE_COEFF_ADDR, can be sped up when register pair (ADUNH:ADUNL)
    // contains the address of element u[N-1] instead of the address of u[N].
    SUBI ADUNL, 2       // ADUNL contains now lo-byte of the address of u[N-1]
    SBC  ADUNH, ZERO    // ADUNH contains now hi-byte of the address of u[N-1]
.endm


///////////////////////////////////////////////////////////////////////////////
//// MACRO TO STORE (UPDATED) COEFFICIENT ADDRESSES IN THE TEMPORARY ARRAY ////
///////////////////////////////////////////////////////////////////////////////

// In each iteration of the inner loop for coefficient addition/subtraction,
// eight elements of array <u> are loaded from memory via the X-pointer, which
// is initialized with a certain start address that is held in the temporary
// array. To maximize performance, the auto-increment addressing mode is used
// to load the eight elements from <u>, i.e. the address in the X-pointer gets
// incremented by 16. Thus, the address contained in the (XH:XL) register pair
// needs to be written back to the temporary array, but before this write-back
// operation, it must be checked whether (XH:XL) exceeds the address of u[N-1].
// If this is the case then 2N has to be subtracted from (XH:XL) because each
// coefficient consists of two bytes. The macro STORE_COEFF_ADDR performs this
// "correction" of the X-pointer in constant time and writes (XH:XL) back to
// the temporary array from where it was loaded.

.macro STORE_COEFF_ADDR // 13 CYCLES
    MOVW TMPL, ADUNL    // copy 16-bit address of u[N-1] to TMP register pair
    SUB  TMPL, XL       // subtract lo-byte of X (current coeff-addr) from TMPL
    SBC  TMPH, XH       // subtract hi-byte of X (current coeff-addr) from TMPH
    SBC  TMPL, TMPL     // TMPL is either 0xFF (if X-ptr > addr of u[N-1]) or 0
    MOV  TMPH, TMPL     // TMPH is either 0xFF (if X-ptr > addr of u[N-1]) or 0
    AND  TMPL, TWONL    // TMPL contains now either the lo-byte of 2N or 0
    AND  TMPH, TWONH    // TMPH contains now either the hi-byte of 2N or 0
    SUB  XL, TMPL       // sub TMPL from XL (to ensure X-ptr <= addr of u[N-1])
    SBC  XH, TMPH       // sub TMPH from XH (to ensure X-ptr <= addr of u[N-1])
    ST   Y+, XL         // store lo-byte of coeff-addr in temp array via Y-ptr
    ST   Y+, XH         // store hi-byte of coeff-addr in temp array via Y-ptr
.endm


///////////////////////////////////////////////////////////////////////////////
//// MACRO TO LOAD A 16-BIT VALUE VIA X-POINTER AND ADD IT TO REGISTER-PAIR ///
///////////////////////////////////////////////////////////////////////////////

.macro LXAD REGH:req, REGL:req
    LD   COEFL, X+
    LD   COEFH, X+
    ADD  \REGL, COEFL
    ADC  \REGH, COEFH
.endm


///////////////////////////////////////////////////////////////////////////////
// MACRO TO LOAD A 16-BIT VALUE VIA X-PTR AND SUBTRACT IT FROM REGISTER-PAIR //
///////////////////////////////////////////////////////////////////////////////

.macro LXSB REGH:req, REGL:req
    LD   COEFL, X+
    LD   COEFH, X+
    SUB  \REGL, COEFL
    SBC  \REGH, COEFH
.endm


///////////////////////////////////////////////////////////////////////////////
////// MACRO TO ADD EIGHT COEFFICIENTS TO COEFF-SUMS HELD IN SUM0L-SUM7H //////
///////////////////////////////////////////////////////////////////////////////

// The macro ADD_COEFFICIENTS loops through the vlen/2 lower elements of the
// temporary array and performs the addition of elements of array <u>. In each
// iteration, the following operations are carried out: (i) an element of the
// temporary array (which contains 16-bit addresses of elements of array <u>)
// is loaded into the X-pointer register-pair, (ii) eight elements of array <u>
// are loaded from RAM via the X-pointer and added to eight coefficient-sums
// held in 16 registers, whereby the X-pointer is incremented after each load,
// and (iii) the current address in (XH:XL) is written back to the temporary
// array (if the X-pointer exceeds the address of u[N-1] then 2N is subtracted
// from (XH:XL) before the write-back operation).

.macro ADD_COEFFICIENTS // xx cycles per iteration
    // The following loop L2 is iterated VLEN/2 times. Similar to loop L1, we
    // use register LSTOP to determine whether the loop-termination condition
    // is satisfied. When this macro gets executed, LSTOP contains the lo-byte
    // of the address of the (2VLEN+1)-th byte of the temporary array. Hence,
    // we have to subtract VLEN from LSTOP to ensure the loop terminates when
    // Y-pointer has reached the (VLEN+1)-th byte of the temporary array; this
    // happens after exactly VLEN/2 iterations (VLEN is always even).
    SUB  LSTOP, VLEN    // sub VLEN from LSTOP (L2 is iterated VLEN/2 times)
L2: //------------------------ START OF THE 2ND LOOP ------------------------//
    LD   XL, Y          // load lo-byte of coeff-addr from temp array via Y-ptr
    LDD  XH, Y+1        // load hi-byte of coeff-addr from temp array via Y-ptr
    LXAD SUM0H, SUM0L   // load 1st coeff via X-ptr and add it to (SUM0H:SUM0L)
    LXAD SUM1H, SUM1L   // load 2nd coeff via X-ptr and add it to (SUM1H:SUM1L)
    LXAD SUM2H, SUM2L   // load 3rd coeff via X-ptr and add it to (SUM2H:SUM2L)
    LXAD SUM3H, SUM3L   // load 4th coeff via X-ptr and add it to (SUM3H:SUM3L)
    LXAD SUM4H, SUM4L   // load 5th coeff via X-ptr and add it to (SUM4H:SUM4L)
    LXAD SUM5H, SUM5L   // load 6th coeff via X-ptr and add it to (SUM5H:SUM5L)
    LXAD SUM6H, SUM6L   // load 7th coeff via X-ptr and add it to (SUM6H:SUM6L)
    LXAD SUM7H, SUM7L   // load 8th coeff via X-ptr and add it to (SUM7H:SUM7L)
    STORE_COEFF_ADDR    // write (corrected) address of X-pointer to temp array
    CPSE LSTOP, YL      // check if Y reached (VLEN+1)-th byte of temp array
    RJMP L2             // if not then jump back to the start of the loop
    //------------------------- END OF THE 2ND LOOP -------------------------//
.endm


///////////////////////////////////////////////////////////////////////////////
/// MACRO TO SUBTRACT EIGHT COEFFICIENTS FROM COEFF-SUMS HELD IN SUM0L-SUM7H //
///////////////////////////////////////////////////////////////////////////////

// The macro SUB_COEFFICIENTS is similar to the macro ADD_COEFFICIENTS except
// that it loops through the vlen/2 upper elements of the temporary array and
// subtracts eight elements of array <u> from the coefficient-sums held in 16
// registers.

.macro SUB_COEFFICIENTS // xx cycles per iteration
    // The following loop L3 is iterated VLEN/2 times. Similar to loop L1, we
    // use register LSTOP to determine whether the loop-termination condition
    // is satisfied. When this macro gets executed, LSTOP contains the lo-byte
    // of the address of the (VLEN+1)-th byte of the temporary array. Thus, we
    // have to add VLEN to LSTOP to ensure the loop terminates when Y-pointer
    // has reached the (2VLEN+1)-th byte of the temporary array; this happens
    // after exactly VLEN/2 iterations (VLEN is always even).
    ADD  LSTOP, VLEN    // add VLEN to LSTOP (L3 is iterated VLEN/2 times)
L3: //------------------------ START OF THE 3RD LOOP ------------------------//
    LD   XL, Y          // load lo-byte of coeff-addr from temp array via Y-ptr
    LDD  XH, Y+1        // load hi-byte of coeff-addr from temp array via Y-ptr
    LXSB SUM0H, SUM0L   // load 1st coeff via X, subtract it from (SUM0H:SUM0L)
    LXSB SUM1H, SUM1L   // load 2nd coeff via X, subtract it from (SUM1H:SUM1L)
    LXSB SUM2H, SUM2L   // load 3rd coeff via X, subtract it from (SUM2H:SUM2L)
    LXSB SUM3H, SUM3L   // load 4th coeff via X, subtract it from (SUM3H:SUM3L)
    LXSB SUM4H, SUM4L   // load 5th coeff via X, subtract it from (SUM4H:SUM4L)
    LXSB SUM5H, SUM5L   // load 6th coeff via X, subtract it from (SUM5H:SUM5L)
    LXSB SUM6H, SUM6L   // load 7th coeff via X, subtract it from (SUM6H:SUM6L)
    LXSB SUM7H, SUM7L   // load 8th coeff via X, subtract it from (SUM7H:SUM7L)
    STORE_COEFF_ADDR    // write (corrected) address in X-pointer to temp array
    CPSE LSTOP, YL      // check if Y reached (2VLEN+1)-th byte of temp array
    RJMP L3             // if not then jump back to the start of the loop
    //------------------------- END OF THE 3RD LOOP -------------------------//
    // After termination of loop L3, the Y-pointer contains the address of the
    // (2VLEN+1)-th byte of the temporary array. As preparation for the next
    // iteration of the main loop, its original address (i.e. the address of
    // the very first byte of the temporary array) needs to be restored, which
    // requires to subtractions of VLEN from the Y-pointer.
    SUB  YL, VLEN       // subtract VLEN from the lo-byte of Y-pointer
    SBC  YH, ZERO       // propagate carry
    SUB  YL, VLEN       // subtract VLEN from the lo-byte of Y-pointer
    SBC  YH, ZERO       // propagate carry
.endm


///////////////////////////////////////////////////////////////////////////////
//// MACRO TO LOAD EIGHT COEFFICIENTS FROM RAM TO SUM0L-SUM7H VIA Z-POINTER ///
///////////////////////////////////////////////////////////////////////////////

.macro LOAD_COEFFICIENTS        // 32 CYCLES
    LD   SUM0L, Z
    LDD  SUM0H, Z+1
    LDD  SUM1L, Z+2
    LDD  SUM1H, Z+3
    LDD  SUM2L, Z+4
    LDD  SUM2H, Z+5
    LDD  SUM3L, Z+6
    LDD  SUM3H, Z+7
    LDD  SUM4L, Z+8
    LDD  SUM4H, Z+9
    LDD  SUM5L, Z+10
    LDD  SUM5H, Z+11
    LDD  SUM6L, Z+12
    LDD  SUM6H, Z+13
    LDD  SUM7L, Z+14
    LDD  SUM7H, Z+15
.endm


///////////////////////////////////////////////////////////////////////////////
//// MACRO TO STORE EIGHT COEFFICIENTS IN SUM0L-SUM7H TO RAM VIA Z-POINTER ////
///////////////////////////////////////////////////////////////////////////////

.macro STORE_COEFFICIENTS       // 32 CYCLES
    ST   Z+, SUM0L
    ST   Z+, SUM0H
    ST   Z+, SUM1L
    ST   Z+, SUM1H
    ST   Z+, SUM2L
    ST   Z+, SUM2H
    ST   Z+, SUM3L
    ST   Z+, SUM3H
    ST   Z+, SUM4L
    ST   Z+, SUM4H
    ST   Z+, SUM5L
    ST   Z+, SUM5H
    ST   Z+, SUM6L
    ST   Z+, SUM6H
    ST   Z+, SUM7L
    ST   Z+, SUM7H
.endm


///////////////////////////////////////////////////////////////////////////////
///////// MULTIPLICATION OF RING ELEMENT BY SPARSE TERNARY POLYNOMIAL /////////
///////////////////////////////////////////////////////////////////////////////

// Since the coefficients of v(x) can only be -1, 0, or +1, the computation of
// the product z(x) = u(x)*v(x) boils down to the addition and subtraction of
// coefficients of u(x), whereby v(x) determines which coefficients of u(x) are
// to be added or subtracted. The first half of array <v> contains the indices
// of the "+1" coefficients (i.e. all j for which v_j = 1) and the second half
// the indices of the "-1" coefficients. Similar to the hybrid multiplication
// technique for integers (CHES 2004), the below implementation of polynomial
// multiplication exploits the large register file of the AVR architecture to
// reduce the number of load/store instructions. It computes eight coefficients
// of z(x) per iteration of the main loop, starting with the least-significant
// coefficients z_0-z_7. The computation of a coefficient z_k consists of two
// steps; in the first step, all coefficients u_i of u(x) with i = k - j mod N
// are summed up, where j encompasses the indices of the "+1" coefficients of
// v(x). Then, in the second step, all coefficients u_i corresponding to the
// "-1" coefficients of v(x) are subtracted from the coefficient-sum obtained
// in the first step. The coefficients u_i to be subtracted in this second step
// are exactly those with i = k - j mod N for any index j for which v_j = -1.
// In total, the number of coefficients that have to be added or subtracted to
// obtain z_k equals the number of non-0 coefficients of v(x).

// The first step of the computation of the least-significant coefficient z_0
// consists of adding up all coefficients u_i with i = -j mod N for any j that
// is an index of a "+1" coefficient of v(x). This requires the computation of
// the addresses of the array elements u[i] holding these coefficients, which
// is done by the macro CALC_COEFF_ADDR. More concretely, this macro computes
// for each j the address of either u[N-j] (when j != 0) or u[0] (when j == 0)
// and stores these addresses in a temporary array allocated on the stack. The
// length of this temporary array is <vlen>, the length of array <v>. In each
// iteration of the main loop, eight coefficients of z(x) are loaded from RAM
// into 16 registers using the macro LOAD_COEFFICIENTS. Thereafter, the macros
// ADD_COEFFICIENTS and SUB_COEFFICIENTS are executed to add or subtract <vlen>
// coefficients of u(x) to/from each of these eight coefficients of z(x). When
// all 8*vlen coefficients of u(x) have been processed, the eight results are
// written back to RAM using the macro STORE_COEFFICIENTS, which concludes the
// loop-iteration. In total, the main loop is iterated ceil(N/8) times.

.global ring_mul_tern_sparse_avr
.func ring_mul_tern_sparse_avr
ring_mul_tern_sparse_avr:
    RING_MUL_PROLOGUE   // push registers on stack and allocate temp array
    INIT_LOCAL_VARS     // initialize local variables and pointers X and Z
    CALC_COEFF_ADDR     // compute addr of u[-j mod N] for any index j in <v>
MAIN_LOOP:
    LOAD_COEFFICIENTS   // load 8 coefficients from array <z> via Z-pointer
    ADD_COEFFICIENTS    // load 8 coeffs from <u> and add them to 8 coeff-sum
    SUB_COEFFICIENTS    // load 8 coeffs from <u> and sub them from 8 coeff-sum
    STORE_COEFFICIENTS  // store 8 coefficient-sums to array <z> via Z-pointer
    DEC  LCTR           // decrement loop-counter by 1
    CPSE LCTR, ZERO     // check whether the loop-counter is 0
    RJMP MAIN_LOOP      // if not then jump back to the start of the loop
    RING_MUL_EPILOGUE   // pop registers from stack and deallocate temp array
    RET
.end func
