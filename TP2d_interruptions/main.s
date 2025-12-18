; ==============================================================================
; Nous observons sur l'oscilloscope un signal rectangulaire d'amplitude 5V, et
; avec une période de 19,90 µs, soit une période de 0,1 µs de moins par rapport
; au signal précédent (cf: TP2b_timer2_scrutation)
; ==============================================================================
    
PROCESSOR 18F25K40
#include <xc.inc>
   
; Configuration ================================================================
config FEXTOSC = OFF
config RSTOSC = HFINTOSC_64MHZ
config WDTE = OFF
   
; Variables RAM ================================================================
PSECT udata_acs
    ; Compteurs pour démultiplication logicielle
    timer2_count: DS 2      ; Compteur 16-bit pour Timer 2 (0-500)
    timer0_count: DS 1      ; Compteur 8-bit pour Timer 0 (0-125)
    
    ; Position du chenillard (0-7)
    chenillard_pos: DS 1
    
    ; Sauvegarde du contexte pour ISR basse priorité
    WREG_TEMP_LOW: DS 1
    STATUS_TEMP_LOW: DS 1
    BSR_TEMP_LOW: DS 1
 
; Code programme ===============================================================
PSECT code, abs
 
; Vecteur de reset =============================================================
org 0x000
    goto init
   
; Vecteur d'interruption haute priorité ========================================
org 0x008
    goto High_ISR
   
; Vecteur d'interruption basse priorité ========================================
org 0x018
    goto Low_ISR
   
; Programme principal ==========================================================
org 0x100
   
; Initialisation ===============================================================
init:
    ; Initialisation des variables
    banksel timer2_count
    clrf timer2_count, 1        ; timer2_count = 0
    clrf timer2_count+1, 1
    clrf timer0_count, 1        ; timer0_count = 0
    clrf chenillard_pos, 1      ; chenillard_pos = 0
    ; LDM1 sur RB4
    banksel ANSELB
    clrf ANSELB, 1              ; PORTB en mode digital
    banksel TRISB
    bcf TRISB, 4, 1             ; RB4 en sortie
    banksel LATB
    bcf LATB, 4, 1              ; LDM1 éteinte initialement
    ; LD0-LD7 sur RD0-RD7
    banksel ANSELD
    clrf ANSELD, 1              ; PORTD en mode digital
    banksel TRISD
    clrf TRISD, 1               ; RD0-RD7 en sortie
    banksel LATD
    movlw 0x01                  ; Chenillard démarre sur LD0
    movwf LATD, 1
    
    ; Configuration Timer 2 - Base de temps 1.28 ms
    ; 1.28 ms = 1280 µs
    ; 1280 µs / 0.0625 µs = 20480 cycles
    ; Avec Prescaler 1:64 => 20480 / 64 = 320 cycles
    ; PR2 = 319 = 0x13F
    
    banksel T2CON
    clrf T2CON, 1               ; Arrêter Timer 2
    banksel T2CLKCON
    movlw 0x01                  ; Clock source = FOSC/4
    movwf T2CLKCON, 1
    banksel PR2
    movlw 0x3F                  ; PR2 = 319 (partie basse)
    movwf PR2, 1
    banksel T2HLT
    clrf T2HLT, 1               ; Mode free-running 
    banksel TMR2
    clrf TMR2, 1                ; TMR2 = 0
    banksel PIR3
    bcf PIR3, 1, 1              ; Effacer TMR2IF
    
    ; Démarrer Timer 2 avec Prescaler 1:64, Postscaler 1:1
    banksel T2CON
    movlw b'11110000'           ; TMR2ON=1, Prescaler=111 (1:64), Post=0000 (1:1)
    movwf T2CON, 1
    banksel T0CON1
    movlw b'01001000'           ; T0CS=FOSC/4, T0ASYNC=sync, Prescaler=1:16 (0100)
    movwf T0CON1, 1
    banksel T0CON0
    movlw b'10010000'           ; T0EN=1, 16-bit mode
    movwf T0CON0, 1
    
    ; Charger la valeur initiale
    banksel TMR0H
    movlw HIGH(64536)
    movwf TMR0H, 1
    movlw LOW(64536)
    movwf TMR0L, 1
    banksel PIR0
    bcf PIR0, 5, 1              ; Effacer TMR0IF
    
    ; Configuration des interruptions avec priorités
    
    ; Activer le système de priorités
    banksel INTCON0
    bsf INTCON0, 5, 1           ; IPEN = 1 (Interrupt Priority Enable)
    ; Timer 2 en HAUTE priorité
    banksel PIE3
    bsf PIE3, 1, 1              ; TMR2IE = 1
    banksel IPR3
    bsf IPR3, 1, 1              ; TMR2IP = 1 (haute priorité)
    ; Timer 0 en BASSE priorité
    banksel PIE0
    bsf PIE0, 5, 1              ; TMR0IE = 1
    banksel IPR0
    bcf IPR0, 5, 1              ; TMR0IP = 0 (basse priorité)
    ; Activer les interruptions globales
    banksel INTCON
    bsf INTCON, 7, 1            ; GIE = 1 (Global Interrupt Enable)
    bsf INTCON, 6, 1            ; PEIE = 1 (Peripheral Interrupt Enable)
    bsf INTCON, 1, 1            ; INT0IE = 1 (pour basse priorité)
    
    banksel 0
   
; Boucle principale ============================================================
; La boucle est VIDE : tout est géré par interruptions !
loop:
    nop                         ; CPU libre pour autres tâches
    goto loop
   
; Routines d'interruption

; Interruption HAUTE priorité - Timer 2 (LDM1 - 1.28 ms) ======================
High_ISR:
    ; Pas besoin de sauvegarder le contexte en haute priorité
    
    ; Vérifier que c'est bien Timer 2
    banksel PIR3
    btfss PIR3, 1, 1            ; TMR2IF ?
    goto High_ISR_End
    
    ; Effacer le flag
    bcf PIR3, 1, 1              ; Effacer TMR2IF
    
    ; Incrémenter le compteur logiciel
    banksel timer2_count
    incf timer2_count, F, 1     ; Incrémenter partie basse
    btfsc STATUS, 2, 0          ; Skip si pas de carry (Z=0)
    incf timer2_count+1, F, 1   ; Incrémenter partie haute si carry
    ; Vérifier si on a atteint 500 (0x01F4)
    movf timer2_count+1, W, 1
    sublw 0x01                  ; W = 0x01 - timer2_count+1
    bnz High_ISR_End            ; Si ≠ 0, pas encore 500
    movf timer2_count, W, 1
    sublw 0xF4                  ; W = 0xF4 - timer2_count
    bnz High_ISR_End            ; Si ≠ 0, pas encore 500
    ; On a atteint 500 => Toggle LDM1 et reset compteur
    clrf timer2_count, 1
    clrf timer2_count+1, 1
    banksel LATB
    btg LATB, 4, 1              ; Toggle RB4 (LDM1)
    
High_ISR_End:
    banksel 0
    retfie FAST                 ; Retour rapide

; Interruption BASSE priorité - Timer 0 (Chenillard - 1 ms) ===================
Low_ISR:
    ; Sauvegarder le contexte (nécessaire en basse priorité)
    movwf WREG_TEMP_LOW, 1
    movf STATUS, W, 0
    movwf STATUS_TEMP_LOW, 1
    movf BSR, W, 0
    movwf BSR_TEMP_LOW, 1
    ; Vérifier que c'est bien Timer 0
    banksel PIR0
    btfss PIR0, 5, 1            ; TMR0IF ?
    goto Low_ISR_End
    
    ; Effacer le flag
    bcf PIR0, 5, 1              ; Effacer TMR0IF
    
    ; Recharge Timer 0 pour 1 ms
    banksel TMR0H
    movlw HIGH(64536)
    movwf TMR0H, 1
    movlw LOW(64536)
    movwf TMR0L, 1
    
    banksel timer0_count
    incf timer0_count, F, 1
    
    movf timer0_count, W, 1
    sublw 125                   ; W = 125 - timer0_count
    bnz Low_ISR_End             ; Si ≠ 0, pas encore 125
    
    ; On a atteint 125 => Avancer le chenillard et reset compteur
    clrf timer0_count, 1
    
    ; Faire tourner le chenillard
    banksel LATD
    rlcf LATD, F, 1             ; Rotation à gauche avec carry
    btfsc STATUS, 0, 0          ; Si carry = 1
    bsf LATD, 0, 1              ; Réinjecter à droite
    
Low_ISR_End:
    ; Restaurer le contexte
    movf BSR_TEMP_LOW, W, 1
    movwf BSR, 0
    movf STATUS_TEMP_LOW, W, 1
    movwf STATUS, 0
    movf WREG_TEMP_LOW, W, 1
    
    retfie                      ; Retour d'interruption basse priorité

end
