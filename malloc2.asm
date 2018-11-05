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

|; Try to merge two blocks.
|; Args:
|;  - curr : an address to the first block
|;  - next : an address to the second block
|;  Note: cur < next
|; Returns:
|;  - 1 if the merge succeed 
|;  - 0 if it doesn't succeed

try_merge:
	PUSH(LP) PUSH(BP)
	MOVE(SP,BP)
	
	PUSH(R1) |; curr
	PUSH(R2) |; next
	PUSH(R3) 
	PUSH(R4)
	
	LD(BP,-12,R1)
	LD(BP,-16,R2)
	|; We compute the adjacent block address and store it in R4
	|;R3 the size of the block
	
	LD(R1,4,R3) |; curr_size = *(block + 1);
	MULC(R3,4,R4)
	ADD(R1,R4,R4) |; block + curr_size*4
	ADDC(R4,8,R4) |; block + (curr_size + 2)*4
	CMPEQ(R4,R2,R4) |; block + (curr_size + 2)*4 == next
	CMOVE(0,R0)
	BF(R4,try_merge_end)
	
	|;If the adjacent block is free, we compute the size of
	|; the merged block.
	LD(R2,4,R4)|; next_size
	ADDC(R4,2,R4)	
	ADD(R3,R4,R4)|; *(block+1) = curr_size + 2 + *(next+1);
	ST(R4,4,R1)
	LD(R2,0,R2)
	
	ST(R2,0,R1)|; *block = *next
	CMOVE(1,R0)
	
try_merge_end:

	POP(R4)
	POP(R3)
	POP(R2)
	POP(R1)
	POP(BP)
	POP(LP)
	
	
	RTN()
	
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
	
	LDR(bbp_init_val,R2)
	CMPEQ(BBP,R2,R2)
	BF(R2,initialized)
	
	|; We initialize the last block of the heap i.e
	|; the memory contains  NULL at 0x3FFF8
	
	ST(R0,0,BBP)
	
initialized:

	MOVE(FP,R4)
	CMPEQC(R1,0,R2)
	BT(R2,malloc_end)

loop_freed:
	|; we travel the list free
	|; R4 = current address 
	|; R5 = previous address
	
	LD(R4,0,R3)
	CMPEQC(R3,NULL,R2)
	BT(R2,no_space_found)
	
	LD(R4,4,R3)
	CMPEQ(R3,R1,R2)
	BT(R2,space_found_equal)
	
	SUBC(R3,2,R3)
	CMPLT(R1,R3,R2)
	BT(R2,space_found_greater)
	
	MOVE(R4,R5)
	LD(R4,0,R4)
	BR(loop_freed)
	
no_space_found:
	|; we compute the new address that would take
	|; BBP if we add the block needed
	|;store it in R3 and compare it to SP preventing to corrupt 
	|;the pile (if it's the case we return NULL)
	
	MULC(R1,4,R3)
	ADDC(R3,8,R3)
	SUB(BBP,R3,R3)
	
	CMPLT(SP,R3,R2)
	BF(R2,malloc_end)
	MOVE(R3,BBP)
	
	ST(R0,0,BBP)
	ST(R1,4,BBP)
	ADDC(BBP,8,R0)
	BR(malloc_end)
	
space_found_equal:
	LD(R4,0,R2)
	
	CMPEQ(FP,R4,R3)
	BT(R3,R4_is_FP_1)
	ST(R2,0,R5)
	BR(continue_1)
	
R4_is_FP_1:

	MOVE(R2,FP)	
	
continue_1:

	ST(R0,0,R4)
	ST(R1,4,R4)
	
	ADDC(R4,8,R0)
	BR(malloc_end)

space_found_greater:
	
	LD(R4,0,R2)
	LD(R4,4,R3)
	
	PUSH(R2)
	PUSH(R3)
        
	ADDC(R1,2,R2)
	MULC(R2,4,R2)
	ADD(R4,R2,R2)
	
	CMPEQ(FP,R4,R3)
	BT(R3,R4_is_FP_2)
	ST(R2,0,R5)
	BR(continue_2)
	
R4_is_FP_2:
	MOVE(R2,FP)	
continue_2:
	ST(R0,0,R4)
	ST(R1,4,R4)
	
	ADDC(R4,8,R0)
	MOVE(R2,R4)
	
	POP(R3)
	SUBC(R3,2,R3)
	SUB(R3,R1,R3)
	ST(R3,4,R2)
	POP(R2)
	ST(R2,0,R4)
	
malloc_end:
	POP(R5)
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
	
	PUSH(R1) |; p
	PUSH(R2) |; int* prev
	PUSH(R3) |; int* curr
	LD(BP,-12,R1) |; p
	
	CMPLT(R1,BBP,R0) |; p < base
	BT(R0,free_end)
	
	LDR(bbp_init_val,R0)
	CMPLT(R1,R0,R0)
	BF(R0,free_end)

	CMOVE(NULL,R2) |; int *prev = NULL (pas sûr)
	MOVE(FP,R3) |; int *curr = freep (pas sûr)
	
free_loop:
	
	CMPLT(R3,R1,R0) |; curr < p
	 |; curr < p && curr |;SI R3 Null quoi faire ?
	BF(R0,free_continue)
	MOVE(R3,R2) |; prev = curr
	ST(R3,0,R3) |; curr = (*curr)
	BR(free_loop)
	
	
free_continue:

	SUBC(R1,8,R1) |; p = p -2
	
	|; we add R1 in the FP list
	
	
	ST(R3,0,R1)
	|; if the next block is the last element of the list 
	|; (R3 == bbp_init_val) we don't try to merge with it
	
	LDR(bbp_init_val,R0)
	CMPEQ(R3,R0,R0)
	BT(R0,merged_next)
	
	PUSH(R3)
	PUSH(R1)
	CALL(try_merge,2)
	
merged_next:

	BT(R2,free_if) |; if(prev)
	MOVE(R1,FP) |; freep = freed
	BR(free_end)
	
free_if:
	ST(R1,0,R2)
	
	PUSH(R1)
	PUSH(R2)
	CALL(try_merge,2)
	
free_end:
	POP(R3)
	POP(R2)
	POP(R1)
	POP(BP)
	POP(LP)
	RTN()
