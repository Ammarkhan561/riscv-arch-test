# ######################################################################################################
#  Verification Goal: Set PTE.V = 0 and test the Read and write Access in User mode for Level0         # 
# 		      should raise a load page fault for read access and store amo fault for store     #	
# 		      access. 									       #                        
#                                                                                                      #
# Description:        If PTE does not have Valid (pte.V=0) permission, then accessing it would	       #
#                     raise page fault exception of the corresponding access type.           	       #
# ######################################################################################################

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV64I_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
#ifdef TEST_CASE_1

    RVTEST_CASE(1,"//check ISA:=regex(.*64.*); check ISA:=regex(.*I.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def TEST_CASE_1=True",sv64)

RVTEST_SIGBASE( x13,signature_x13_1)


main:

j _start

rvtest_data:									// rvtest_data region for RWX access(ppn1==0 and ppn0==0)
	.word 0xdeadbeef
_start:

# -------------------------------------------------------------------------

#ifdef rvtest_mtrap_routine							// Verification of existance of rvtest_mtrap_routine
	LI a4, 0xceed
	RVTEST_SIGUPD(x13,a4)
#endif
#ifdef rvtest_strap_routine					         	// Verification of existance of rvtest_strap_routine
	LI a4, 0xbeed
	RVTEST_SIGUPD(x13,a4)
#endif

# -------------------------Set the all mem PMP-----------------------------	

	ALL_MEM_PMP							        // set the permissions of all memory 
	csrw satp, zero								// write zero to the satp (bare mode)
	
# -------------------------------------------------------------------------

	.set va,       	 0x0900000000						// 39 bits of VA address
	.set pa,       	 0x80000000000000 					// 56 bits of PA address 
	.set va_data,  	 0x0900001000						// 39 bits of VA address	
	.set sig_data,   0x0900020118						// 39 bits of VA address (offset bits should be same as that of rvtest_sig_begin)

# -------------------------Set the PTE for level2 for sv39-----------------

	LA (a0, rvtest_slvl1_pg_tbl)                                            // loads the address in a0
	LI a1, ( PTE_V )           					        // sets the permission bits
	PTE_SETUP_RV64(a0, a1, t0, t1, va, LEVEL2,sv39)                         // setup the PTE for level2
	
	LA (a0, rvtest_slvl2_pg_tbl)                                            // loads the address in a0
	LI a1, ( PTE_V )           					        // sets the permission bits
	PTE_SETUP_RV64(a0, a1, t0, t1, va, LEVEL1,sv39)                         // setup the PTE for level1
								                // level0 PTE setup for pa (0x0900000000 -> 0x80000000000000)	
	LI (a0, pa)                                                             // loads the PA address in a0
	LI a1, ( PTE_D | PTE_A | PTE_U | PTE_X | PTE_W | PTE_R | PTE_V )        // sets the permission bits
	PTE_SETUP_RV64(a0, a1, t0, t1, va, LEVEL0,sv39)                         // setup the PTE for level0 for sv39
 										// level2 PTE setup for pa (0x0900001000 -> rvtest_data)
	LA( a0,rvtest_data)							// loads the PA address in a0 
	LI a1, ( PTE_D | PTE_A | PTE_U | PTE_X | PTE_W | PTE_R ) 		// sets the permission bits (PTE_V == 0)
	PTE_SETUP_RV64(a0, a1, t0, t1, va_data, LEVEL0,sv39)                    // setup the PTE for level2 for sv39
	
# -------------------------Set the PTE for signature update-----------------
                                                                                // PTE setup for 0x0900020118 -> rvtest_sig_begin
	la a0, rvtest_sig_begin   						// Physical address of signature area
	li a1, ( PTE_D | PTE_A | PTE_U | PTE_R | PTE_W | PTE_X | PTE_V )        // sets the permissions bits 
	PTE_SETUP_RV64(a0, a1, t0, t1, sig_data, LEVEL0,sv39) 			// PTE Setup for signature area address at pgtbl0
	
	LI (t0, sig_data)                                                       // loads the value of the sig_data
	LA (t1, rvtest_sig_begin)                                               // loads the address of the rvtest_sig_begin       
	sub t0, t0, t1 					        		// (VA-PA) Note: VA > PA 
	add s11, x13, t0				        		// Translation of Signature reg

# -------------------------Set the SATP for virtulization------------------

	SATP_SETUP_RV64 (sv39)                                                  // set the SATP for virtualization

# -------------------------Save area logic----------------------------------

	/* Save Virtual addresses in of Code and Data 
	in their respective S-mode save area */

	/****** code ******/
	LI (t0, va)                                                             // load the virtual address of vm_en in t0
	LI (t1, pa)                                                             // load the physical address of vm_en in t1
	sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA 
	csrr sp, mscratch                                                       // load the value of mscratch in sp
	add t1,sp,t0                                                            // add the offset to the base address of save area
	csrw sscratch, t1                                                       // write the address of save area in sscratch

	LREG t1, code_bgn_off+0*sv_area_sz(sp)                                  // load the address of code_bgn_off in t1
	add t2, t1, t0                                                          // add the offset to the base address of save area
	SREG t2, code_bgn_off+1*sv_area_sz(sp)                                  // write the address of code_bgn_off in sscratch
	SREG t2, code_bgn_off+2*sv_area_sz(sp)                                  // write the address of code_bgn_off in sscratch

	/******* data *******/
	// update save area
	LI (t0, va_data)                                                        // load the virtual address of pa_data in t0
	LA (t1, rvtest_data)                                                    // load the physical address of pa_data in t1
	sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA 
	LREG t1, data_bgn_off+0*sv_area_sz(sp)                                  // load the address of data_bgn_off in t1
	add  t2, t1,t0                                                          // add the offset to the base address of save area
	SREG t2, data_bgn_off+1*sv_area_sz(sp)                                  // write the address of data_bgn_off in sscratch
	SREG t2, data_bgn_off+2*sv_area_sz(sp)                                  // write the address of data_bgn_off in sscratch	
	//signature
	LI (t0, sig_data)                                                       // load the virtual address of rvtest_sig_begin in t0
	LA (t1, signature_x13_1)                                                // load the physical address of rvtest_sig_begin in t1
	sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA 
	LREG t1, sig_bgn_off+0*sv_area_sz(sp)                                   // load the address of sig_bgn_off in t1
	add t2, t1, t0                                                          // add the offset to the base address of save area
	SREG t2, sig_bgn_off+1*sv_area_sz(sp)                                   // write the address of sig_bgn_off in sscratch
	SREG t2, sig_bgn_off+2*sv_area_sz(sp)                                   // write the address of sig_bgn_off in sscratch
	// vmem
	LI (t0, va_data)                	                                // load the virtual address of pa_data in t0
	LA (t1, rvtest_data)                                                    // load the physical address of pa_data in t1
	sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA
	LREG t1, vmem_bgn_off+0*sv_area_sz(sp)                                  // load the address of vmem_bgn_off in t1
	add t2, t1, t0                                                          // add the offset to the base address of save area
	SREG t2, vmem_bgn_off+1*sv_area_sz(sp)                                  // write the address of vmem_bgn_off in sscratch
	SREG t2, vmem_bgn_off+2*sv_area_sz(sp)                                  // write the address of vmem_bgn_off in sscratch

	sfence.vma                                                              // flush the TLB
	RVTEST_GOTO_LOWER_MODE	Umode		                                // Switching to U mode

# -------------------------virtulization enabled----------------------------------

vm_en:
	LI (a4, 0xdead)
	RVTEST_SIGUPD(s11,a4)                                                   // Verification of virtualization enabeled
	nop
	LI (t0, va_data)                                                        
	LREG x2, 0(t0)                                                          // test the load access  (should raise an exception)
        nop                                             
	SREG x2, 0(t0)                                                          // test the store access (should raise an exception)
	nop
	LI (a4, 0xbeef)
	RVTEST_SIGUPD(s11,a4)                                                   // Verification of virtualization enabeled
        nop

# -------------------------virtulization disabled----------------------------------

	RVTEST_GOTO_MMODE		                                        // Switching back to M mode
	addi x13,x13,REGWIDTH

	LI (a4, 0x123)
	RVTEST_SIGUPD(x13,a4)                                                   // Verification of virtualization disabled

#endif

 # -----------------------------------------------------------------------------

RVTEST_CODE_END

RVMODEL_HALT

RVTEST_DATA_BEGIN

#ifdef rvtest_strap_routine
.align 12
rvtest_slvl1_pg_tbl:
        RVTEST_PTE_IDENT_MAP
rvtest_slvl2_pg_tbl:
        RVTEST_PTE_IDENT_MAP        
#endif

RVTEST_DATA_END

RVMODEL_DATA_BEGIN

rvtest_sig_begin:
sig_begin_canary:
CANARY;

// test signatures initialization
signature_x13_1:
    .fill 64*(XLEN/64),4,0xdeadbeef

// trap signatures initialization

#ifdef rvtest_mtrap_routine
mtrap_sigptr:
    .fill 64*(XLEN/64),4,0xcafebeef
#endif

sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END
