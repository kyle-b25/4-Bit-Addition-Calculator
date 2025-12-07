#include "reg9s12.h"          ; include device register definitions

; LCD port definitions
lcd_dat  equ PortK            ; lcd data/control connected to port k
lcd_dir  equ DDRK             ; lcd direction register
lcd_E    equ $02              ; lcd enable bit mask
lcd_RS   equ $01              ; lcd register select bit mask

; Reserve RAM
        org   $1000

msg_name    dc.b "Kyle Basirico",0   ; top line message
msg_title   dc.b "SW1-4+SW5-8:",0    ; bottom line static label
temp_low    ds.b 1                   ; store lower nibble
temp_high   ds.b 1                   ; store upper nibble
temp_sum    ds.b 1                   ; store sum of both nibbles
temp_ones   ds.b 1                   ; store ones digit
temp_tens   ds.b 1                   ; store tens digit

; MAIN PROGRAM
        org   $2000
        lds   #$2000                 ; init stack pointer

; --- Setup DIP switches (PTH) ---
        movb  #$00, DDRH             ; set PTH as inputs for dip switches

; --- Setup LCD ---
        jsr   openLCD                ; initialize lcd in 4–bit mode

; WRITE TOP LINE
        ldaa  #$80                   ; lcd line 1 home position
        jsr   cmd2LCD                ; send cursor command
        ldx   #msg_name              ; pointer to top line text
        jsr   putsLCD                ; print name to lcd

; MAIN LOOP
mainLoop:

; ---- read lower DIP nibble (1-4) ----
        ldaa  PTH                    ; read entire dip port
        anda  #$0F                   ; mask to keep only low nibble
        staa  temp_low               ; store low nibble

; ---- read upper DIP nibble (5-8) ----
        ldaa  PTH                    ; read dip port again
        lsra                         ; shift high nibble down bit by bit
        lsra
        lsra
        lsra                         ; now original high nibble is in lower 4 bits
        anda  #$0F                   ; ensure only lower bits kept
        staa  temp_high              ; store high nibble

; ---- add them ----
        ldaa  temp_low               ; load lower nibble
        adda  temp_high              ; add upper nibble
        staa  temp_sum               ; store sum result

; ---- convert to decimal ----
        ldaa  temp_sum               ; load sum
        clrb                         ; clear b to count tens

convLoop2:
        cmpa  #10                    ; check if >= 10
        blt   convDone2              ; if < 10, conversion done
        suba  #10                    ; subtract 10 to count tens
        incb                         ; increment tens counter
        bra   convLoop2              ; loop until sum < 10

convDone2:
        staa  temp_ones              ; store ones digit
        stab  temp_tens              ; store tens digit

; Display on second LCD line: "SW1-4+SW5-8: XX"

        ldaa  #$C0                   ; lcd line 2 home position
        jsr   cmd2LCD                ; move lcd cursor

        ldx   #msg_title             ; pointer to bottom line label
        jsr   putsLCD                ; print label to lcd

        ; tens digit
        ldaa  temp_tens              ; load tens
        adda  #$30                   ; convert to ascii
        jsr   putcLCD                ; write character

        ; ones digit
        ldaa  temp_ones              ; load ones
        adda  #$30                   ; convert to ascii
        jsr   putcLCD                ; write character

        bra   mainLoop               ; repeat forever

; LCD ROUTINES

cmd2LCD:
        psha                         ; save a
        bclr   lcd_dat,lcd_RS        ; select instruction register
        bset   lcd_dat,lcd_E         ; set enable high
        anda   #$F0                  ; keep upper nibble
        lsra                         ; align bits for lcd transfer
        lsra
        oraa   #$02                  ; ensure proper control bits
        staa   lcd_dat               ; output nibble
        nop                          ; timing
        nop
        nop
        bclr   lcd_dat,lcd_E         ; latch falling edge

        pula                         ; restore a
        anda   #$0F                  ; keep lower nibble
        lsla                         ; move to upper nibble positions
        lsla
        bset   lcd_dat,lcd_E         ; enable high again
        oraa   #$02                  ; set control bits
        staa   lcd_dat               ; output second nibble
        nop
        nop
        nop
        bclr   lcd_dat,lcd_E         ; latch

        ldy    #1                    ; small delay
        jsr    delay50us
        rts

openLCD:
        movb   #$FF,lcd_dir          ; set lcd pins as outputs
        ldy    #2                    ; delay for lcd startup
        jsr    delay100ms
        ldaa   #$28                  ; function set (4–bit mode)
        jsr   cmd2LCD
        ldaa   #$0F                  ; display on, cursor on
        jsr   cmd2LCD
        ldaa   #$06                  ; entry mode increment
        jsr   cmd2LCD
        ldaa   #$01                  ; clear display
        jsr   cmd2LCD
        ldy    #2                    ; extra delay
        jsr    delay1ms
        rts

putcLCD:
        psha                         ; save a
        bset   lcd_dat,lcd_RS        ; select data register
        bset   lcd_dat,lcd_E         ; enable high
        anda   #$F0                  ; keep upper nibble
        lsra                         ; align bits
        lsra
        oraa   #$03                  ; set control bits for data
        staa   lcd_dat               ; output nibble
        nop
        nop
        nop
        bclr   lcd_dat,lcd_E         ; latch

        pula                         ; lower nibble
        anda   #$0F
        lsla
        lsla
        bset   lcd_dat,lcd_E         ; enable high
        oraa   #$03                  ; data bits
        staa   lcd_dat               ; output nibble
        nop
        nop
        nop
        bclr   lcd_dat,lcd_E         ; latch

        ldy    #1                    ; short delay
        jsr    delay50us
        rts

putsLCD:
        ldaa   1,X+                  ; load next char
        beq    donePS                ; stop at null
        jsr    putcLCD               ; print char
        bra    putsLCD               ; keep printing
donePS:
        rts

; Timing routines
delay1ms:
        movb   #$90,TSCR             ; enable timer system
        movb   #$06,TMSK2            ; prescaler
        bset   TIOS,$01              ; enable channel 0
        ldd    TCNT                  ; read counter

again0: addd   #375                  ; 1ms delay count
        std    TC0                   ; load compare
wait_lp0:
        brclr  TFLG1,$01,wait_lp0    ; wait for flag
        ldd    TC0                   ; reload
        dbne   y,again0              ; loop y times
        rts

delay100ms:
        movb   #$90,TSCR             ; enable timer
        movb   #$06,TMSK2            ; prescaler
        bset   TIOS,$01              ; output compare 0
        ldd    TCNT

again1: addd   #37500                ; 100ms delay count
        std    TC0
wait_lp1:
        brclr  TFLG1,$01,wait_lp1
        ldd    TC0
        dbne   y,again1
        rts

delay50us:
        movb   #$90,TSCR             ; enable timer
        movb   #$06,TMSK2            ; prescaler
        bset   TIOS,$01              ; output compare 0
        ldd    TCNT

again2: addd   #15                   ; 50us delay count
        std    TC0
wait_lp2:
        brclr  TFLG1,$01,wait_lp2
        ldd    TC0
        dbne   y,again2
        rts

        end                          ; end of program