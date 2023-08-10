// -----------
// Copyright (c) 2020. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// -----------
//
// This is a VM test file with SV32 address translation scheme, to verify the working of trap handler and other macros in arch_test.h
// 

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
#ifdef TEST_CASE_1
    RVTEST_CASE(1,"//check ISA:=regex(.*32.*); check ISA:=regex(.*I.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def TEST_CASE_1=True",sv32)

RVTEST_SIGBASE( x13,signature_x13_1)
  	
main:
#ifdef rvtest_mtrap_routine	// Verification of existance of rvtest_mtrap_routine
	LI (a4, 0xceed)
	RVTEST_SIGUPD(x13,a4)
#endif
#ifdef rvtest_strap_routine	// Verification of existance of rvtest_strap_routine
	LI (a4, 0xbeed)
	RVTEST_SIGUPD(x13,a4)
#endif
	
	LI (t2, -1)		// WHOLE PHYSICAL MEMORY AS SINGLE REGION
	csrw pmpaddr0, t2
	LI (t2, 0x0F)		// TOR MODE WITH LOCK BIT ON; WIll write in terms of MACROS later
	csrw pmpcfg0, t2
	// write satp with all zeros (bare mode)
	csrw satp, x0

	.set va,		0x90000000
	.set pa,		0x80000000 
	.set va_data,	0x90011000

	// PTE setup for Instruction memory 0x91240000 -> 0x80000000

	LA (a0, rvtest_slvl1_pg_tbl)
	// (PTE_D | PTE_A | PTE_G | PTE_U | PTE_X | PTE_W | PTE_R | PTE_V)
	LI (a1, (PTE_V))   // permissions for PTE to for address instruction of instruction memory
	PTE_SETUP_RV32(a0, a1, t0, t1, va, 1)
	
	LI (a0, pa)
	#LI (a4, 0x123)4


	// (PTE_D | PTE_A | PTE_G | PTE_U | PTE_X | PTE_W | PTE_R | PTE_V)
	LI (a1, (PTE_D | PTE_A | PTE_G | PTE_X | PTE_W | PTE_R | PTE_V))
	PTE_SETUP_RV32(a0, a1, t0, t1, va, 0)

	LA (a0, rvtest_data)
	#LI (a4, 0x123)4

	// (PTE_D | PTE_A | PTE_G | PTE_U | PTE_X | PTE_W | PTE_R | PTE_V)
	LI (a1, (PTE_D | PTE_A | PTE_G | PTE_R | PTE_V))
	PTE_SETUP_RV32(a0, a1, t0, t1, va_data, 0)


    LA(t6, rvtest_Sroot_pg_tbl)
    LI(t5, SATP32_MODE) 


    srli t6, t6, 12 
    or t6, t6, t5 
    csrw satp, t6   

	/* Save Virtual addresses in of Code and Data 
	in their respective S-mode save area */

	/****** code ******/
	LI (t0, va)
	LI (t1, pa)
	sub t0, t0, t1 // (VA-PA) Note: VA > PA 
	csrr sp, mscratch
	add t1,sp,t0
	csrw sscratch, t1 
	
	/******* code *******/
	LREG t1, code_bgn_off+0*sv_area_sz(sp)
	add t2, t1, t0
	SREG t2, code_bgn_off+1*sv_area_sz(sp)

	/******* data *******/
	// update save area
	LREG t1, data_bgn_off+0*sv_area_sz(sp)
	add  t2, t1,t0
	SREG t2, data_bgn_off+1*sv_area_sz(sp)
	//signature
	LREG t1, sig_bgn_off+0*sv_area_sz(sp)
	add t2, t1, t0
	SREG t2, sig_bgn_off+1*sv_area_sz(sp) 
	

	sfence.vma
	RVTEST_GOTO_LOWER_MODE	Smode		   // Switching to S mode
	
	

vm_en:
	LA (t1, va_data)
	LI (t0, 0xdead1234)
	SREG t0, 0(t1)

	RVTEST_GOTO_MMODE		// Switching back to M mode
	LI (a4, 0x123)
	RVTEST_SIGUPD(x13,a4)
mmode:
	LI (t2, 0xabab)			// Verification if handler is returning and SIGUPD is working afer the handler
	csrw pmpaddr1, t2		// If in M-mode, this instruction will work otherwise not.
	csrr a4, pmpaddr1
	RVTEST_SIGUPD(x13,a4)
#endif 
 # ---------------------------------------------------------------------------------------------
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.align 12
rvtest_data:
.word 0xbabecafe
.word 0xbabecafe
.word 0xbabecafe
.word 0xbabecafe

#ifdef rvtest_strap_routine
.align 12
rvtest_slvl1_pg_tbl:
		RVTEST_PTE_IDENT_MAP
#endif
RVTEST_DATA_END
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;

// test signatures initialization
signature_x13_1:
    .fill 32*(XLEN/32),4,0xcafebeef

// trap signatures initialization
#ifdef rvtest_mtrap_routine
mtrap_sigptr:
    .fill 32*(XLEN/32),4,0xdeadbeef
#endif

sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END
