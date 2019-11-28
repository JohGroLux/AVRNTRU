///////////////////////////////////////////////////////////////////////////////
// ring_red_mod3.S: Reduction of a 16-bit unsigned integer modulo 3.         //
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


// Function prototype:
// -------------------
// 
// Description:
// ------------
// 
// Operands:
// ---------
// 
// Version history:
// ----------------


// define register names

#define HIBYTE R25     // upper byte of 16-bit UINT to be reduced mod 3
#define LOBYTE R24     // upper byte of 16-bit UINT to be reduced mod 3
#define ZERO R23       // ZERO is always 0


.global ring_red_mod3
.func ring_red_mod3
ring_red_mod3:
    
    // initialize variables
    
    CLR  ZERO
    
    // first step: reduction modulo 85*3 = 255 = 2^8 - 1
    
    ADD  LOBYTE, HIBYTE // 
    ADC  LOBYTE, ZERO   // 
    
    // second step: reduction modulo 5*3 = 15 = 2^4 - 1
    
    MOV  HIBYTE, LOBYTE // 
    SWAP HIBYTE         // swap the 4-bit nibbles of HIBYTE
    ANDI LOBYTE, 0xF    // 
    ANDI HIBYTE, 0xF    // 
    ADD  LOBYTE, HIBYTE // 
    MOV  HIBYTE, LOBYTE // 
    SWAP HIBYTE         // swap the 4-bit nibbles of HIBYTE
    ADD  LOBYTE, HIBYTE // 
    ANDI LOBYTE, 0xF    // 
    
    // third step: reduction modulo 3 = 2^2 - 1
    
    MOV  HIBYTE, LOBYTE // 
    LSR  HIBYTE         // 
    LSR  HIBYTE         // 
    ANDI LOBYTE, 0x3    // 
    ADD  LOBYTE, HIBYTE // 
    MOV  HIBYTE, LOBYTE // 
    LSR  HIBYTE         // 
    LSR  HIBYTE         // 
    ANDI LOBYTE, 0x3    // 
    ADD  LOBYTE, HIBYTE // 
    
    // final subtraction of 3, followed by addition of 3 if difference < 0
    
    SUBI LOBYTE, 0x3    // 
    SBC  ZERO, ZERO     // 
    ANDI ZERO, 0x3      // ZERO is now either 0 or 3
    ADD  LOBYTE, ZERO   // 
    
    // pop registers from stack
    
    CLR  HIBYTE
    CLR  R1
    
    // that's all folks :-)
    
    RET
    
.end func
