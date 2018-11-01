
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
	push(R4)
	
	|; Insert your malloc implementation here ...
	LD(BP,-12,R1)
	
	CMOVE(NULL,R0)
	CMPEQC(BBP,bbp_init_val,R2)
	BF(R2,initialized)
	|; We initialize the last block of the heap ??
	ST(R31,BBP) |; marche ?
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
	
	LD(R4,R4)
	BR(loop_freed)
	
no_space_found:
	|; we compute the new address of BBP if we add the block needed
	|;store it in R3 and compare it to SP we don't want to corrupt 
	|;the pile
	
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
	ADDC(R4,8,R0)
	BR(malloc_end)

space_found_greater:
	LD(R4,R2)
	LD(R4,4,R3)
	PUSH(R3)
	PUSH(R2)
	ADDC(R1,2,R2)
	MULC(R2,4,R2)
	ADD(R4,R2,R2)
	ST(R2,R4)
	ST(R1,4,R4)
	MOVE(R4,R0)
	MOVE(R2,R4)
	POP(R3)
	SUBC(R3,2,R3)
	SUB(R3,R1,R3)
	ST(R4,4,R3)
	POP(R2)
	

malloc_end:

	

|; Free a dynamically allocated array starting at address p.
|; Args:
|;  - p: address of the dynamically allocated array
free: 
	PUSH(LP) PUSH(BP)
	MOVE(SP, BP)
	|; Insert your free implementation here ....