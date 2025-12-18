; ==============================================================================
; La LED 0 est connectée à RC0
; ==============================================================================
PROCESSOR 18F25K40
#include <xc.inc>

; Configuration ================================================================
config FEXTOSC = OFF           ; Pas de source d'horloge externe
config RSTOSC = HFINTOSC_64MHZ ; Horloge interne de 64 MHz
config WDTE = OFF              ; Desactiver le watchdog timer
	
PSECT   code, abs
   
msb equ 0x20
lsb equ 0x21
leds equ 0x22
 
; Vecteur de reset =============================================================
org     0x000
goto init 
   
; Vecteur d'interruption haute priorite ========================================
org     0x008
goto High_ISR 

; Vecteur d'interruption basse priorite ========================================
org     0x018
goto Low_ISR 

; Programme principal ==========================================================
org 0x100

init:
    clrf TRISC       ; PORTC en sortie
    movlw 0x01       ; LED0
    movwf LATC       ; Allumer LED0
    
loop:
    goto loop               ; Boucle infinie

; Routines d'interruption ======================================================    
High_ISR:
    retfie
    
Low_ISR:  
    retfie
     
end
