#include "../env/encoding.h"

#define LEVEL0 0x00
#define LEVEL1 0x01

#define CHANGE_T0_S_MODE(MEPC_ADDR)                                ;\
    li        t0, MSTATUS_MPP                                      ;\
    csrc mstatus, t0                                               ;\
    li  t1, MSTATUS_MPP & ( MSTATUS_MPP >> 1)                      ;\
    csrs mstatus, t1                                               ;\
    csrw mepc, MEPC_ADDR                                           ;\
    mret                                                           ;

#define CHANGE_T0_U_MODE(MEPC_ADDR)                                ;\
    li        t0, MSTATUS_MPP                                      ;\
    csrc mstatus, t0                                               ;\
    csrw mepc, MEPC_ADDR                                           ;\
    mret                                                           ;


#define ALL_MEM_PMP                                                ;\
    li t2, -1                                                      ;\
    csrw pmpaddr0, t2                                              ;\
    li t2, 0x0F	                                               ;\
    csrw pmpcfg0, t2                                               ;\
    sfence.vma                                                     ;
