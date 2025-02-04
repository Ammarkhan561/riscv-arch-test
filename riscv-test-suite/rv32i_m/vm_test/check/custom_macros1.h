#include "encoding.h"

#define LEVEL0       0x00
#define LEVEL1       0x01
#define ALL_F_S      0xFFFFFFFF
#define NO_EXCEP_NO  110
#define PMPADDR0     0x0
#define PMPADDR1     0x1
#define PMPADDR2     0x2
#define PMPADDR3     0x3
#define SUCCESS      0
#define FAILED       1

#define INSTRUCTION_ADDRESS_MISALIGNED 0
#define INSTRUCTION_ACCESS_FAULT       1
#define ILLEGAL_INSTRUCTION            2 
#define BREAKPOINT                     3
#define LOAD_ADDRESS_MISALIGNED        4
#define LOAD_ACCESS_FAULT              5
#define STORE_AMO_ADDRESS_MISALIGNED   6
#define STORE_AMO_ACCESS_FAULT         7
#define ENVIRONMENT_CALL_FROM_U_MODE   8
#define ENVIRONMENT_CALL_FROM_S_MODE   9
#define ENVIRONMENT_CALL_FROM_M_MODE   11
#define INSTRUCTION_PAGE_FAULT         12
#define LOAD_PAGE_FAULT                13
#define STORE_AMO_PAGE_FAULT           15

#define ASID_IMPLE_CVA6 0x00400000
#define EXPECTED_ASID   0x00400000

#define WRITE_CSR(CSR_REG, SRC_REG)                                ;\
    csrw CSR_REG, SRC_REG                                          ;

#define CLEAR_CSR(CSR_REG, SRC_REG)                                ;\
    csrc CSR_REG, SRC_REG                                          ;

#define SET_CSR(CSR_REG, SRC_REG)                                  ;\
    csrs CSR_REG, SRC_REG                                          ;

#define READ_CSR(CSR_REG, DST_REG)                                 ;\
    csrr DST_REG, CSR_REG                                          ;

#define CLEAR_REG(REG)                                             ;\
    li REG, 0                                                      ;

#define CHANGE_T0_S_MODE(MEPC_ADDR)                                ;\
    li        t0, MSTATUS_MPP                                      ;\
    CLEAR_CSR (mstatus, t0)                                        ;\
    li  t1, MSTATUS_MPP & ( MSTATUS_MPP >> 1)                      ;\
    SET_CSR   (mstatus,t1)                                         ;\
    WRITE_CSR (mepc,MEPC_ADDR)                                     ;\
    mret                                                           ;
    
#define CHANGE_T0_U_MODE(MEPC_ADDR)                                ;\
    li        t0, MSTATUS_SPP                                      ;\
    CLEAR_CSR (mstatus,t0)                                         ;\
    WRITE_CSR (mepc,MEPC_ADDR)                                     ;\
    mret                                                           ;
    
#define ALL_MEM_PMP                                                ;\
    li t2, ALL_F_S                                                 ;\
    csrw pmpaddr0, t2                                              ;\
    CLEAR_REG(t2)                                                  ;\
    SET_PMP_TOR_RWX(t2, t6, PMPADDR0)                              ;\
    csrw pmpcfg0, t2                                               ;\


#define SET_PMP_R(REG, TMP, PMPADDR)                               ;\
    .if(PMPADDR == PMPADDR0)                                       ;\
        ori REG, REG, PMP_R                                        ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR1)                                       ;\
        li TMP, PMP_R                                              ;\
        slli TMP, TMP, PMPADDR1 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR2)                                       ;\
        li TMP, PMP_R                                              ;\
        slli TMP, TMP, PMPADDR2 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR3)                                       ;\
        li TMP, PMP_R                                              ;\
        slli TMP, TMP, PMPADDR3 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    CLEAR_REG(TMP)                                                 ;

#define SET_PMP_W(REG, TMP, PMPADDR)                               ;\
    .if(PMPADDR == PMPADDR0)                                       ;\
        ori REG, REG, PMP_W                                        ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR1)                                       ;\
        li TMP, PMP_W                                              ;\
        slli TMP, TMP, PMPADDR1 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR2)                                       ;\
        li TMP, PMP_W                                              ;\
        slli TMP, TMP, PMPADDR2 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR3)                                       ;\
        li TMP, PMP_W                                              ;\
        slli TMP, TMP, PMPADDR3 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    CLEAR_REG(TMP)                                                 ;

#define SET_PMP_X(REG, TMP, PMPADDR)                               ;\
    .if(PMPADDR == PMPADDR0)                                       ;\
        ori REG, REG, PMP_X                                        ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR1)                                       ;\
        li TMP, PMP_X                                              ;\
        slli TMP, TMP, PMPADDR1 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR2)                                       ;\
        li TMP, PMP_X                                              ;\
        slli TMP, TMP, PMPADDR2 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR3)                                       ;\
        li TMP, PMP_X                                              ;\
        slli TMP, TMP, PMPADDR3 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    CLEAR_REG(TMP)                                                 ;


#define SET_PMP_TOR(REG, TMP, PMPADDR)                             ;\
    .if(PMPADDR == PMPADDR0)                                       ;\
        ori REG, REG, PMP_TOR                                      ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR1)                                       ;\
        li TMP, PMP_TOR                                            ;\
        slli TMP, TMP, PMPADDR1 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR2)                                       ;\
        li TMP, PMP_TOR                                            ;\
        slli TMP, TMP, PMPADDR2 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    .if(PMPADDR == PMPADDR3)                                       ;\
        li TMP, PMP_TOR                                            ;\
        slli TMP, TMP, PMPADDR3 << PMPADDR3                        ;\
        or REG, REG, TMP                                           ;\
    .endif                                                         ;\
    CLEAR_REG(TMP)                                                 ;


#define SET_PMP_TOR_RWX(REG, TMP, PMPADDR)                         ;\
    SET_PMP_X(REG, TMP, PMPADDR)                                   ;\
    SET_PMP_R(REG, TMP, PMPADDR)                                   ;\
    SET_PMP_W(REG, TMP, PMPADDR)                                   ;\
    SET_PMP_TOR(REG, TMP, PMPADDR)                                 ;
    
