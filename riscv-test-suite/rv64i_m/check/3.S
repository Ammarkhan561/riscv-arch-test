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

j _start
.align 3									// to align for 64 bit 
rvtest_data:									// rvtest_data region for RWX access(ppn1==0 and ppn0==0)
	.dword 0xFACECAFEBEEDCAFE
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

# -------------------------Set the PMP Permission and chnage mode----------	

	ALL_MEM_PMP							        // set the permissions of all memory 
	csrw satp, zero								// write zero to the satp (bare mode)	
	
        sfence.vma                                                              // flush the TLB
	csrw mstatus, zero
        
        LI (t1, MSTATUS_MPP)                                                    // loads the value of MSTATUS_MPP
        csrs mstatus,t1                                                         // sets the mstatus MPP bit 
        
        LI (t1, MSTATUS_MPRV)                                                   // loads the value of MSTATUS_MPP
        csrs mstatus,t1                                                         // sets the mstatus MPP bit 

	SATP_SETUP_RV64(sv39)                                                   // set the SATP for virtualization
      
        LA ( t1,vm_en)
        csrw mepc,t1 
        mret

# -------------------------------------------------------------------------
vm_en:	
        csrr s1,mstatus
        nop

        LA   ( t1, rvtest_data)
        LREG  s2, 0(t1)
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
