
.data

writeFlag: .asciz "w"
readFlag: .asciz "r"


.text 

/*
    BITMAP LIBRARY - contains functions used to encode / decode a message to / from a BMP file.
*/

/*

    Encodes given message using RLE-8

    Takes 4 parameters: a message pointer, a free memory pointer, a pattern pointer and the pattern length.
    Returns a pointer to the encoded string (which btw. is %rsi). 
    Encoded string looks like this: <pattern><msg><pattern>

    %rdi - msg ptr
    %rsi - free mem ptr
    %rdx - pattern ptr
    %rcx - pattern length

*/
encode:
    pushq %rbp
    movq %rsp, %rbp

    pushq %rsi  # [rsp + 24]: start of the encoded msg
    pushq $0    # [rsp + 16]: pattern counter
    pushq %rdx  # [rsp + 8]: pattern ptr
    pushq %rcx  # [rsp + 0]: pattern length

encode_pattern_loop:
    # encode the lead / trail
    movb (%rdx), %r8b
    movb %r8b, (%rsi)
    incq %rdx
    incq %rsi
    decq %rcx
    jnz encode_pattern_loop
    incq 16(%rsp)
    cmpq $2, 16(%rsp)
    jz encode_pattern_end   # leave the function if we used the loop twice (for lead and trail)

    # encode the message
encode_msg_loop:
    movq $0, %rcx
    movb (%rdi), %r8b
    cmpb $0, %r8b           # check for the end of string
    jz encode_pattern_preloop  # if it is the end, add the trail

encode_msg_nextCharLoop:
    incq %rcx
    incq %rdi
    cmpb (%rdi), %r8b
    je encode_msg_nextCharLoop
    # rdi contains a different char, save r8b char with the counter
    movb %cl, (%rsi)
    incq %rsi
    movb %r8b, (%rsi)
    incq %rsi
    #decq %rdi   # decrement to keep it correct
    jmp encode_msg_loop

encode_pattern_preloop:
    movq (%rsp), %rcx
    movq 8(%rsp), %rdx 
    jmp encode_pattern_loop

encode_pattern_end:
    movq $0, (%rsi) # add the null terminator
    movq 24(%rsp), %rax
    movq %rbp, %rsp
    popq %rbp
    ret



/*
    Decodes the message encoded with RLE-8 and prints the result.

    Takes 2 parameters: a pointer to an encoded message and a pattern (lead and trail) length.

    Params:
    %rdi - msg ptr
    %rsi - pattern length
*/

decode: 
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %rdx
    pushq %rdx
    call cutLeadAndTrail  # get rid of the lead and trail
    popq %rdi

decode_loop1:
    cmpb $0, (%rdi)
    je decode_end      # end of the msg

    xorq %rcx, %rcx
    xorq %r8, %r8
    movb (%rdi), %cl    # %rcx times to print the char
    movb 1(%rdi), %r8b  # r8b - char to print

    addq $2, %rdi       # point to the next [rcx,r8] pair
decode_loop2:
    cmpq $0, %rcx
    je decode_loop1     # no need to print more

    pushq %rdi
    pushq %rcx
    pushq %r8
    movq %rsp, %rdi
    movq $1, %rsi
    call myprintf_output
    popq %rcx
    popq %rcx
    popq %rdi
    
    decq %rcx
    jmp decode_loop2

decode_end:

    movq %rbp, %rsp
    popq %rbp
    ret


/*
    Encodes an RLE-8 encoded message into a pixel array.

    Takes 2 parameters: a pointer to an encoded message and a pointer to a pixels buffer array, where the
    modified pixels will be stored. Note that the pixels buffer array is a KEY. Therefore, you need the same
    buffer later on to decode the message.

    %rdi - encoded msg ptr
    %rsi - pixels buffer ptr

*/
xorencode:
    pushq %rbp
    movq %rsp, %rbp

    xorq %r8, %r8
    xorq %r9, %r9
xorencode_loop1:
    movb (%rdi), %r8b
    cmpb $0, %r8b
    je xorencode_end    # we reached the end of msg
    # get a pixel, xor it with msg char and put it back to the buffer
    movb (%rsi), %r9b
    xorb %r9b, %r8b
    movb %r8b, (%rsi)
    # increment pointers
    incq %rsi
    incq %rdi
    jmp xorencode_loop1
xorencode_end:
    movq %rbp, %rsp
    popq %rbp
    ret



/*
    Decodes the message encoded in a pixel array.

    Takes 3 parameters: a pointer to a key (an array of default pixels), a pointer to an array of pixels with encoded message
    and a pointer to a free memory where the decoded message will be placed.

    %rdi - key ptr
    %rsi - pixels buffer ptr
    %rdx - free memory ptr

*/
xordecode:
    pushq %rbp
    movq %rsp, %rbp
    xorq %r8, %r8
    xorq %r9, %r9
xordecode_loop1:  
    movb (%rdi), %r8b
    movb (%rsi), %r9b
    incq %rdi
    incq %rsi

    xorb %r8b, %r9b 
    cmpb $0, %r9b   # if equal it means that the message is not in the beginning of the pixel array
    je xordecode_loop1
    # we found the message!
xordecode_loop2:
    movb %r9b, (%rdx)
    incq %rdx

    movb (%rdi), %r8b
    movb (%rsi), %r9b
    incq %rdi
    incq %rsi
    xorb %r8b, %r9b

    cmpb $0, %r9b 
    jne xordecode_loop2
    # we have arrived at the end of the message, we are done

    movq %rbp, %rsp
    popq %rbp
    ret     


/*

    Retrieves bytes that encodes a BMP file and puts them in a buffer.
    Takes 2 parameters: a file name (the file must exist!) and a ptr to a buffer

    %rdi - file name
    %rsi - buffer ptr

*/

retrBytesFromBmp: 
    pushq %rbp
    movq %rsp, %rbp

    pushq %rsi

    movq $readFlag, %rsi
    call fopen

    pushq %rax

    movq 8(%rsp), %rdi
    movq filesize, %rsi
    movq $1, %rdx
    movq %rax, %rcx
    call fread

    movq (%rsp), %rdi
    call fclose

    movq %rbp, %rsp
    popq %rbp
    ret 

/*

    Retrieves the message from between lead and trail.
    Takes 3 parameters: a buffer with a message, size of the lead and trail and a buffer to save the retrieved message to

    %rdi - msg buffer ptr
    %rsi - size of the lead and trail
    %rdx - retrieved msg buffer ptr

*/

cutLeadAndTrail:
    pushq %rbp
    movq %rsp, %rbp

    pushq %rdi      # [rsp + 16]
    pushq %rsi      # [rsp + 8] 
    pushq %rdx      # [rsp + 0]
    
    call myprintf_strlen
    movq %rax, %rcx
    subq 8(%rsp), %rcx
    subq 8(%rsp), %rcx
    
    # skip the lead
    movq 16(%rsp), %r8
    addq 8(%rsp), %r8
    # 
    movq (%rsp), %r9

cutLeadAndTrail_loop1:
    cmpq $0, %rcx
    je cutLeadAndTrail_end
    movb (%r8), %r10b
    movb %r10b, (%r9)

    incq %r8
    incq %r9
    decq %rcx
    jmp cutLeadAndTrail_loop1
cutLeadAndTrail_end:
    movb $0, (%r9)  # place a null terminator
    movq %rbp, %rsp
    popq %rbp
    ret 


/*

    Writes a buffer to a file.
    Takes 3 parameters: a desired name of the file, a buffer with bytes to write to that file and the size of the buffer.

    %rdi - filename ptr
    %rsi - buffer ptr
    %rdx - buffer size

*/

writeToFile:
    pushq %rbp
    movq %rsp, %rbp

    pushq %rsi
    pushq %rdx

    # %rdi already has the filename     
    movq $writeFlag, %rsi
    call fopen

    pushq %rax

    movq 16(%rsp), %rdi # buffer ptr
    movq 8(%rsp), %rsi  # buffer size
    movq $1, %rdx      
    movq (%rsp), %rcx   # file handle
    call fwrite

    movq (%rsp), %rdi 
    call fclose

    movq %rbp, %rsp
    popq %rbp
    ret 
/*
    Prints ths buffer of specified length to the console.

    Params:
    %rdi - buffer
    %rsi - buffer length
*/

myprintf_output:
    pushq %rbp
    movq %rsp, %rbp

    movq %rsi, %rdx
    movq %rdi, %rsi
    movq $1, %rax
    movq $1, %rdi
    syscall

    movq %rbp, %rsp
    popq %rbp
    ret 

/*
    Calculates the length of a buffer (null-terminated string).

    Params:
    %rdi - buffer
    Returns:
    %rax - buffer's length
*/

myprintf_strlen:
    pushq %rbp
    movq %rsp, %rbp

    xor %rcx, %rcx
myprintf_strlen_loopStart:

    cmpb $0, (%rdi)             # check if it is the end of the string
    je myprintf_strlen_end      # if so, end the loop
    incq %rcx                   # if not, increase the counter
    incq %rdi                   # and proceed to next character
    jmp myprintf_strlen_loopStart
myprintf_strlen_end:
    movq %rcx, %rax     
    movq %rbp, %rsp
    popq %rbp
    ret     
