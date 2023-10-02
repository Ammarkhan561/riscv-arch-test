# ###############################################################################################           
# Verification Goal: mstatus is accessible only in M not in S mode and U mode			#		
#                                                                                               #
# Description:       mstatus is only accessible in M mode and illegal instruction          	#
#                    exception is generated when accessed in lower privilege mode             	#
# ############################################################################################### 

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

# -------------------------------------------------------------------------

#ifdef rvtest_mtrap_routine							// Verification of existance of rvtest_mtrap_routine
	LI a4, 0xceed
	RVTEST_SIGUPD(x13,a4)
#endif
#ifdef rvtest_strap_routine					         	// Verification of existance of rvtest_strap_routine
	LI a4, 0xbeed
	RVTEST_SIGUPD(x13,a4)
#endif

# -------------------------Set the PMP Permission and chnage mode----------	

	ALL_MEM_PMP							        // set the permissions of all memory 
	csrw satp, zero								// write zero to the satp (bare mode)	
	sfence.vma                                                              // flush the TLB
	
        li      t1, 0x4                                                         
        csrs    medeleg, t1                                                     // makes the 2nd bit to 1

        RVTEST_GOTO_LOWER_MODE	Smode		                                // Switching to S mode

# -------------------------------------------------------------------------
	
        csrr s1,mstatus
        nop
        RVTEST_GOTO_MMODE		                                        // Switching back to M mode

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
