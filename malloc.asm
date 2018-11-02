
|; Dynamic allocation registers:
|; - Base block pointer (BBP): points to the first block
|; - Free pointer (FP): points the first free block of the free list
|; - NULL: value of the null pointer (0)
BBP = R26
FP = R25 
NULL = 0

bbp_init_val:
	LONG(0x3FFF8)

|; reset the global memory registers
.macro beta_alloc_init() LDR(bbp_init_val, BBP) MOVE(BBP, FP)
|; call malloc to get an array of size Reg[Ra]
.macro MALLOC(Ra)        PUSH(Ra) CALL(malloc, 1)
|; call malloc to get an array of size CC
.macro CMALLOC(CC)	     CMOVE(CC, R0) PUSH(R0) CALL(malloc, 1)
|; call free on the array at address Reg[Ra]
.macro FREE(Ra)          PUSH(Ra) CALL(free, 1)


|; Dynamically allocates an array of size n.
|; Args:
|;  - n (>0): size of the array to allocate 
|; Returns:
|;  - the address of the allocated array
malloc: 
	PUSH(LP) PUSH(BP)
	MOVE(SP, BP)
	
	PUSH(R1)
	PUSH(R2)
	PUSH(R3)
	PUSH(R4)
	PUSH(R5)
	
	LD(BP,-12,R1)
	
	CMOVE(NULL,R0)
	CMPEQC(BBP,bbp_init_val,R2)
	BF(R2,initialized)
	|; We initialize the last block of the heap i.e
	|; the memory contains  0 at 0x3FFF8 and NULL at 0x3FFF4
	|; and the BPP and FP are both pointing to the address 0x3FFF4
	
	ST(R31,BBP) 
	ST(R0,-4,BBP)
	ADDC(BBP,-4,BBP)
	ADDC(FP,-4,FP)
	
initialized:

	MOVE(FP,R4)

loop_freed:
	
	LD(R4,R3)
	CMPEQC(R3,NULL,R2)
	BT(R2,no_space_found)
	
	LD(R4,4,R3)
	CMPEQ(R3,R1,R2)
	BT(R2,space_found_equal)
	
	SUBC(R3,2,R3)
	CMPLT(R1,R3,R2)
	BT(R2,space_found_greater)
	
	MOVE(R4,R5)
	LD(R4,R4)
	BR(loop_freed)
	
no_space_found:
	|; we compute the new address that would take
	|; BBP if we add the block needed
	|;store it in R3 and compare it to SP preventing to corrupt 
	|;the pile (if it's the case we return NULL)
	
	MULC(R1,4,R3)
	ADDC(R3,8,R3)
	ADD(BBP,R3,R3)
	
	CMPLT(SP,R3,R2)
	BF(R2,malloc_end)
	MOVE(R3,BBP)
	
	ST(R0,BBP)
	ST(R1,4,BBP)
	ADDC(BBP,8,R0)
	BR(malloc_end)
	
space_found_equal:
	LD(R4,R2)
	
	CMPEQ(FP,R4,R3)
	BT(R3,R4_is_FP_1)
	ST(R2,R5)
	BR(continue_1)
	
R4_is_FP_1:

	MOVE(R2,FP)	
	
continue_1:

	ST(R0,R4)
	ST(R1,4,R4)
	
	ADDC(R4,8,R0)
	BR(malloc_end)

space_found_greater:
	
	LD(R4,R2)
	LD(R4,4,R3)
	
	PUSH(R2)
	PUSH(R3)
        
	ADDC(R1,2,R2)
	MULC(R2,4,R2)
	ADD(R4,R2,R2)
	
	CMPEQ(FP,R4,R3)
	BT(R3,R4_is_FP_2)
	ST(R2,R5)
	BR(continue_2)
	
R4_is_FP_2:
	MOVE(R2,FP)	
continue_2:
	ST(R0,R4)
	ST(R1,4,R4)
	
	ADDC(R4,8,R0)
	MOVE(R2,R4)
	
	POP(R3)
	SUBC(R3,2,R3)
	SUB(R3,R1,R3)
	ST(R3,4,R2)
	POP(R2)
	ST(R2,R4)
	
malloc_end:
	POP(R4)
	POP(R3)
	POP(R2)
	POP(R1)
	POP(BP)
	POP(LP)
	RTN()

	

|; Free a dynamically allocated array starting at address p.
|; Args:
|;  - p: address of the dynamically allocated array
free: 
	PUSH(LP) PUSH(BP)
	MOVE(SP, BP)
	
	PUSH(R1)
	
	LD(BP,-12,R1) |; p
	
	CMPLT(R1,BBP,R0) |; p < base
	BT(R0,free_end)
	
	
free_end:
	POP(R1)
	POP(BP)
	POP(LP)
	RTN()
