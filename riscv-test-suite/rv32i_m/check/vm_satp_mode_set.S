#################################################################################################           
# Verification Goal: Test for satp mode field set                                               #
#                                                                                               #
# Description:  	 Verification of supported address translation scheme i.e sv32				#
#					 is selected by writing satp.mode=sv32 and reading back the satp			#
#################################################################################################   

#-----------------------------------------------#
#             Read and write Test               #
#  	PTE setup -- Level 1, supervisor mode		#
#	expected  -- Test Pass and satp mode is set	#
#-----------------------------------------------#

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

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=

#ifdef rvtest_mtrap_routine									// Verification of existance of rvtest_mtrap_routine
	LI a4, 0xceed
	RVTEST_SIGUPD(x13,a4)
#endif
#ifdef rvtest_strap_routine					         		// Verification of existance of rvtest_strap_routine
	LI a4, 0xbeed
	RVTEST_SIGUPD(x13,a4)
#endif
	
	ALL_MEM_PMP          								    # set the PMP permissions for the whole memory
	WRITE_CSR (satp,x0)  								    # Bare Mode setup

#-------------------Adresses--------------------#
	.set va,		0x90000000                  #           Page table level 1  VA   
	.set pa,		0x80000000                  #           rvtest_entry_point physical address
	.set va_data,	0x91000000                  #           rvtest_data Virtual address set at level 0 
#-----------------------------------------------#

#------------------------------------------------------PTE setup--------------------------------------------------------------
    #PTE SETUP at level 1 -- rvtest_entry_point physical address stored
	LI a0, pa														
	LI a1, (PTE_D | PTE_A | PTE_G | PTE_X | PTE_W | PTE_R | PTE_V)  
	PTE_SETUP_RV32(a0, a1, t0, t1, va, LEVEL1)

    #PTE SETUP at level 1 -- rvtest_data physical address stored
	LA (a0, rvtest_data)
	LI a1, (PTE_D | PTE_A | PTE_G | PTE_X | PTE_W | PTE_R | PTE_V) 
	PTE_SETUP_RV32(a0, a1, t0, t1, va_data, LEVEL1)
#-----------------------------------------------------------------------------------------------------------------------------

#---------------satp mode setup-----------------#
    LA(t6, rvtest_Sroot_pg_tbl)                 #
    LI(t5, SATP32_MODE)                         #
    srli t6, t6, 12                             #
    or t6, t6, t5                               #
    csrw satp, t6                               #               #satp mode setup -- write step
#-----------------------------------------------#

#--------------------------------------------------Save area code-------------------------------------------------------------
	/* Save Virtual addresses in of Code and Data 
	in their respective S-mode save area */

	/****** code ******/
	LI (t0, va)
	LI (t1, pa)
	sub t0, t0, t1 // (VA-PA) Note: VA > PA 
	csrr sp, mscratch
	add t1,sp,t0
	csrw sscratch, t1 
	
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
#-----------------------------------------------------------------------------------------------------------------------------
	RVTEST_GOTO_LOWER_MODE	Smode		                   # Switching to S mode
#-----------------------------------------------------------------------------------------------------------------------------
vm_en:
    csrr  t4, satp                                         #satp -- read step
    srli  t4, t4, 31                                       #get the value of mode available at the last bit
    li    t3, 1 
    beq   t4, t3, Passed

Failed:
    li t4, 22                                               #Just a check in the log -- we may add this in the sigupdate as well                                              
Passed:
	RVTEST_GOTO_MMODE		                               # Switching back to M mode
	LI (a4, 0x123)
	RVTEST_SIGUPD(x13,a4)
#endif

#-----------------------------------------------------------------------------------------------------------------------------
RVTEST_CODE_END
RVMODEL_HALT
RVTEST_DATA_BEGIN
.align 24
#-------------------------------------------------rvtest_data section---------------------------------------------------------
rvtest_data:
.word 0xbeefcafe
.word 0xbabecafe
.word 0xbabecafe
.word 0xbabecafe
#-----------------------------------------------------------------------------------------------------------------------------
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
#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=