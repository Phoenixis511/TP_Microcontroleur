PROCESSOR 18F25K40
#include <xc.inc>
   
; Configuration ================================================================
config FEXTOSC = OFF
config RSTOSC = HFINTOSC_64MHZ
config WDTE = OFF
   
; Variables RAM ================================================================
PSECT udata_acs
 
; Code programme ===============================================================
PSECT code, abs
 
; Vecteur de reset =============================================================
org 0x000
    goto init
   
; Vecteur d'interruption haute priorité ========================================
org 0x008
    goto High_ISR           ; Aller à la routine d'interruption
   
; Vecteur d'interruption basse priorité ========================================
org 0x018
    retfie
   
; Programme principal ==========================================================
org 0x100
   
; Initialisation ===============================================================
init:
    ; ========================================================================
    ; Configuration de RC2 (LED_MATRIX/CMD_MATRIX) en sortie numérique
    ; ========================================================================
    banksel ANSELC
    bcf ANSELC, 2, 1        ; RC2 en mode digital
   
    banksel TRISC
    bcf TRISC, 2, 1         ; RC2 en sortie
    
    banksel LATC
    bcf LATC, 2, 1          ; LED éteinte initialement
   
    ; ========================================================================
    ; Configuration du Timer 2 pour expiration toutes les 10 µs
    ; ========================================================================
    ; Fosc = 64 MHz => Fcy = 16 MHz (0.0625 µs par instruction)
    ; Pour 10 µs : 10 / 0.0625 = 160 cycles
    ; PR2 = 160 - 1 = 159 = 0x9F
    ; Prescaler = 1:1, Postscaler = 1:1
    ; ========================================================================
    
    ; Arrêter Timer 2 pendant la configuration
    banksel T2CON
    clrf T2CON, 1           ; Arrêter Timer 2
    
    ; Configurer la période PR2
    banksel PR2
    movlw 0x9F              ; PR2 = 159 pour 10 µs
    movwf PR2, 1
    
    ; Réinitialiser le compteur TMR2
    banksel TMR2
    clrf TMR2, 1            ; TMR2 = 0
    
    ; Effacer le flag TMR2IF (dans PIR3, bit 1)
    banksel PIR3
    bcf PIR3, 1, 1          ; Effacer TMR2IF
    
    ; ========================================================================
    ; Configuration des interruptions
    ; ========================================================================
    
    ; Activer l'interruption du Timer 2 (TMR2IE dans PIE3, bit 1)
    banksel PIE3
    bsf PIE3, 1, 1          ; TMR2IE = 1 (activer interruption Timer 2)
    
    ; Configurer la priorité haute pour Timer 2 (IPR3, bit 1)
    banksel IPR3
    bsf IPR3, 1, 1          ; TMR2IP = 1 (haute priorité)
    
    ; Activer le système d'interruptions avec priorités
    banksel INTCON
    bsf INTCON, 7, 1        ; GIE = 1 (Global Interrupt Enable)
    bsf INTCON, 6, 1        ; PEIE = 1 (Peripheral Interrupt Enable)
    
    ; Note : Pour activer les priorités sur PIC18F
    banksel INTCON0
    bsf INTCON0, 5, 1       ; IPEN = 1 (Interrupt Priority Enable)
    
    ; Démarrer Timer 2
    banksel T2CON
    movlw b'10000000'       ; TMR2ON=1, Prescaler=1:1, Postscaler=1:1
    movwf T2CON, 1
   
    banksel 0               ; Retour à bank 0
   
; Boucle principale ============================================================
; La boucle principale peut maintenant exécuter d'autres tâches
; Le Timer 2 génère des interruptions de manière autonome
loop:
    ; Le CPU peut faire d'autres choses ici
    ; Pour ce TP, on fait juste une boucle vide
    nop                     ; Instruction vide (pour déboguer)
    goto loop
   
; Routines d'interruption ======================================================

; Interruption haute priorité - Timer 2 =======================================
High_ISR:
    ; Sauvegarder le contexte (optionnel pour ce TP simple)
    ; Dans un vrai projet, sauvegarder WREG, STATUS, BSR
    
    ; Vérifier si c'est bien Timer 2 qui a déclenché l'interruption
    banksel PIR3
    btfss PIR3, 1, 1        ; Tester TMR2IF
    goto High_ISR_End       ; Si ce n'est pas Timer 2, sortir
    
    ; Effacer le flag TMR2IF
    bcf PIR3, 1, 1          ; Effacer TMR2IF
    
    ; Inverser l'état de LED_MATRIX (RC2)
    banksel LATC
    btg LATC, 2, 1          ; Toggle RC2
    
High_ISR_End:
    ; Restaurer le contexte (optionnel pour ce TP)
    
    banksel 0
    retfie                  ; Retour d'interruption (restaure PC et réactive GIE)

; Interruption basse priorité (non utilisée) ==================================   
Low_ISR:  
    retfie
   
end
