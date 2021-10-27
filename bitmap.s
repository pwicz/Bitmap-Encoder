.include "bitmap-pixels.s"
.include "bitmap-lib.s"

.data
usage_format: .asciz "usage: %s <mode: E/D> <string to encode / name of the file to decode>\n"
char_format: .asciz "%c"

buffer: .skip 1500
buffer2: .skip 1500
message: .skip 1500
filenameDecode: .skip 1500

pattern: .byte 8, 67, 4, 83, 2, 69, 4, 49, 4, 52, 8, 48

filename:.asciz "encoded.bmp"
filesize: .quad 3126

.text
.global main
main:
    pushq   %rbp
    movq    %rsp, %rbp

    # Make sure we got two arguments.
	cmp $3, %rdi
	jne wrong_argc
    
    # recognize which mode we are to use
    movq 8(%rsi), %r8
    xorq %r9, %r9
    movb (%r8), %r9b

    cmpb $69, %r9b   # is it 'E'?
    je encodeMode
    cmpb $101, %r9b  # is it 'e'?
    je encodeMode
    cmpb $68, %r9b   # is it 'D'?
    je decodeMode
    cmpb $100, %r9b  # is it 'd'?
    je decodeMode
    jmp wrong_argc   # default - wrong arg

main_end:
    movq    %rbp, %rsp
    popq    %rbp
    movq	$0, %rdi		# load program exit code
	call	exit			# exit the program
wrong_argc:
    movq $usage_format, %rdi
	movq (%rsi), %rsi # %rsi still hold argv up to this point
	call printf

    movq    %rbp, %rsp
    popq    %rbp
    movq	$0, %rdi		# load program exit code
	call	exit			# exit the program

encodeMode:
    movq 16(%rsi), %rdi      # retrieve address of the string to encode
    
    movq $buffer, %rsi       # we place the encoded msg in $buffer
    movq $pattern, %rdx
    movq $12, %rcx
    call encode

    movq $buffer, %rdi          # now we encode the msg into pixels stored
    movq $pixels_buffer, %rsi   # in $pixels_buffer
    call xorencode

    movq $filename, %rdi
    movq $pixels_header, %rsi
    movq filesize, %rdx
    call writeToFile

    jmp main_end
decodeMode:
    movq 16(%rsi), %rdi      # retrieve address of the filename

    # %rdi already has the filename
    movq $pixels_header, %rsi
    call retrBytesFromBmp   # first we read the file

    movq $pixels, %rdi      
    movq $pixels_buffer, %rsi
    movq $buffer, %rdx      # the decoded msg will be in $buffer
    call xordecode          # now we xordecode from pixels

    movq $buffer, %rdi
    movq $12, %rsi
    call decode             # finally read the encoded message

    # print a new line to make it more readable
    movq $char_format, %rdi
    movq $10, %rsi
	call printf

    jmp main_end