# ######################################################################################################
#  Verification Goal: Verification Goal: Set PTE.V = 0 and test the Read Acces in Supervisor mode for  #
#                    Level1 Should raise a load page fault for read access.                            #                        
#                                                                                                      #
# Description:       If PTE does not have Valid (pte.V=0) permission, then accessing it would	       #
#                    raise page fault exception of the corresponding access type.           	       #
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
# ---------------------------------------------------------------------------------------------

#ifdef rvtest_mtrap_routine							// Verification of existance of rvtest_mtrap_routine
	LI a4, 0xceed
	RVTEST_SIGUPD(x13,a4)
#endif
#ifdef rvtest_strap_routine					         	// Verification of existance of rvtest_strap_routine
	LI a4, 0xbeed
	RVTEST_SIGUPD(x13,a4)
#endif
	
	ALL_MEM_PMP          						        // set the PMP permissions
	WRITE_CSR (satp,x0)  						        // write satp with all zeros (bare mode)

	# .set va,       0x90000000
	# .set pa,       0x80000000 
	# .set va_data,  0x91000000
        # .set sig_data, 0x93003110                                               // virtual address of signature_x13_1


	.set va,       	 0x0900000000
	.set pa,       	 0x80000000 
	.set va_data,  	 0x0980000000

        # .set va,       0x90000000
        # .set pa,       0x80000000 
	# .set va_data,  0xE1000000

	la s11,0x34
								                // PTE setup for rvtest_data 0x91000000 -> rvtest_data	

	LI (a0, pa)                                                             // loads the address in a0
	LI a1, ( PTE_D | PTE_A | PTE_X | PTE_W | PTE_R | PTE_V )                // sets the permission bits
	PTE_SETUP_RV64(a0, a1, t0, t1, va, LEVEL2,sv39)                              // setup the PTE for level1
								                // PTE setup for rvtest_data 0x91000000 -> rvtest_data	
	la s11,0x37
	LA (a0, rvtest_data)                                                    // loads the address of label rvtest_data in a0
	LI a1, ( PTE_D | PTE_A | PTE_X | PTE_W | PTE_R  | PTE_V)                	// sets the permission bits (PTE_V == 0)
	PTE_SETUP_RV64(a0, a1, t0, t1, va_data, LEVEL2,sv39)                         // setup the PTE for level1
        
	SATP_SETUP_RV64 (sv32)                                                        // set the SATP for virtualization

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

	/******* data *******/
	// update save area
	LI (t0, va_data)                                                        // load the virtual address of rvtest_data in t0
	LA (t1, rvtest_data)                                                    // load the physical address of rvtest_data in t1
	sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA 
	LREG t1, data_bgn_off+0*sv_area_sz(sp)                                  // load the address of data_bgn_off in t1
	add  t2, t1,t0                                                          // add the offset to the base address of save area
	SREG t2, data_bgn_off+1*sv_area_sz(sp)                                  // write the address of data_bgn_off in sscratch
	# //signature
	# LI (t0, sig_data)                                                       // load the virtual address of signature_x13_1 in t0
	# LA (t1, signature_x13_1)                                                // load the physical address of signature_x13_1 in t1
	# sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA 
	# LREG t1, sig_bgn_off+0*sv_area_sz(sp)                                   // load the address of sig_bgn_off in t1
	# add t2, t1, t0                                                          // add the offset to the base address of save area
	# SREG t2, sig_bgn_off+1*sv_area_sz(sp)                                   // write the address of sig_bgn_off in sscratch
	// vmem
	LI (t0, va_data)                                                        // load the virtual address of rvtest_data in t0
	LA (t1, rvtest_data)                                                    // load the physical address of rvtest_data in t1
	sub t0, t0, t1                                                          // (VA-PA) Note: VA > PA
	LREG t1, vmem_bgn_off+0*sv_area_sz(sp)                                  // load the address of vmem_bgn_off in t1
	add t2, t1, t0                                                          // add the offset to the base address of save area
	SREG t2, vmem_bgn_off+1*sv_area_sz(sp)                                  // write the address of vmem_bgn_off in sscratch

	sfence.vma                                                              // flush the TLB
	RVTEST_GOTO_LOWER_MODE	Smode		                                // Switching to S mode

vm_en:
	LI (a4, 0xdead)
        
	LI (t0, va_data)                                                        
	LREG x2, 0(t0)                                                          // test the load access (should raise an exception)
        nop                                             
        
	LI (a4, 0xbeef)                                                         // Verification of coming back from trap handler 

	RVTEST_GOTO_MMODE		                                        // Switching back to M mode
        
        nop
	LI (a4, 0x123)
	RVTEST_SIGUPD(x13,a4)                                                   // Verification of virtualization disabled

#endif

 # ---------------------------------------------------------------------------------------------

RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
 .align 24
rvtest_data:
.word 0xbeefcafe
.word 0xbabecafe
.word 0xbabecafe
.word 0xbabecafe
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
    .fill 64*(XLEN/32),8,0xcafebeef

// trap signatures initialization
#ifdef rvtest_mtrap_routine
mtrap_sigptr:
    .fill 64*(XLEN/32),8,0xdeadbeef
#endif

sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END
