PROCESSOR 18F25K40
#include <xc.inc>
   
; Configuration ================================================================
config FEXTOSC = OFF
config RSTOSC = HFINTOSC_64MHZ
config WDTE = OFF
   
; Variables RAM ================================================================
PSECT udata_acs
    step_counter: DS 1          ; Étape actuelle (0-99)
    ms_counter: DS 1            ; Compteur pour 20 ms
    direction: DS 1             ; 0=montée, 1=descente
 
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
    retfie
   
; Programme principal ==========================================================
org 0x100
   
; Initialisation ===============================================================
init:
    ; Initialiser les variables
    banksel step_counter
    clrf step_counter, 1        ; Commencer à l'étape 0
    clrf ms_counter, 1          ; Compteur à 0
    clrf direction, 1           ; Direction = montée
    
    ; ========================================================================
    ; Configuration de RD0 (LD0) en sortie
    ; ========================================================================
    banksel ANSELD
    bcf ANSELD, 0, 1            ; RD0 en mode digital
    
    banksel TRISD
    bcf TRISD, 0, 1             ; RD0 en sortie
    
    banksel LATD
    bcf LATD, 0, 1              ; RD0 à 0 initialement
    
    ; ========================================================================
    ; Configuration du Timer 2 pour PWM à 1 kHz
    ; ========================================================================
    ; Fréquence PWM = 1 kHz => Période = 1 ms
    ; 1 ms = 1000 µs / 0.0625 µs = 16000 cycles
    ; Avec Prescaler 1:16 => 16000 / 16 = 1000 cycles
    ; PR2 = 1000 - 1 = 999 = 0x3E7
    
    banksel T2CON
    clrf T2CON, 1               ; Arrêter Timer 2
    
    banksel T2CLKCON
    movlw 0x01                  ; Clock source = FOSC/4
    movwf T2CLKCON, 1
    
    banksel T2HLT
    clrf T2HLT, 1               ; Mode free-running
    
    banksel PR2
    movlw 0xE7                  ; PR2 = 0x3E7 (partie basse)
    movwf PR2, 1
    
    banksel TMR2
    clrf TMR2, 1                ; TMR2 = 0
    
    banksel PIR3
    bcf PIR3, 1, 1              ; Effacer TMR2IF
    
    ; Démarrer Timer 2 avec Prescaler 1:16
    banksel T2CON
    movlw b'10010000'           ; TMR2ON=1, Prescaler=100 (1:16), Post=0000
    movwf T2CON, 1
    
    ; ========================================================================
    ; Configuration du module PWM3 - Duty cycle initial 0%
    ; ========================================================================
    banksel PWM3CON
    clrf PWM3CON, 1             ; Désactiver PWM3
    
    ; Duty cycle initial = 0%
    banksel PWM3DCH
    clrf PWM3DCH, 1
    banksel PWM3DCL
    clrf PWM3DCL, 1
    
    ; Activer PWM3
    banksel PWM3CON
    movlw b'10000000'           ; EN=1, POL=0 (active high)
    movwf PWM3CON, 1
    
    ; ========================================================================
    ; Configuration du PPS - Router PWM3 vers RD0
    ; ========================================================================
    ; Déverrouiller PPS
    banksel PPSLOCK
    movlw 0x55
    movwf PPSLOCK, 1
    movlw 0xAA
    movwf PPSLOCK, 1
    bcf PPSLOCK, 0, 1           ; UNLOCK
    
    ; Router PWM3 vers RD0
    banksel RD0PPS
    movlw 0x0D                  ; 0x0D = PWM3OUT
    movwf RD0PPS, 1
    
    ; Reverrouiller PPS
    banksel PPSLOCK
    movlw 0x55
    movwf PPSLOCK, 1
    movlw 0xAA
    movwf PPSLOCK, 1
    bsf PPSLOCK, 0, 1           ; LOCK
    
    ; ========================================================================
    ; Configuration des interruptions Timer 2
    ; ========================================================================
    banksel PIE3
    bsf PIE3, 1, 1              ; TMR2IE = 1
    
    banksel IPR3
    bsf IPR3, 1, 1              ; TMR2IP = 1 (haute priorité)
    
    banksel INTCON
    bsf INTCON, 7, 1            ; GIE = 1
    bsf INTCON, 6, 1            ; PEIE = 1
    
    banksel 0
   
; Boucle principale ============================================================
; Boucle vide - tout géré par interruptions
loop:
    nop
    goto loop
   
; ==============================================================================
; Routines d'interruption
; ==============================================================================

; Interruption haute priorité - Timer 2 (toutes les 1 ms) =====================
High_ISR:
    ; Vérifier TMR2IF
    banksel PIR3
    btfss PIR3, 1, 1
    goto High_ISR_End
    
    ; Effacer le flag
    bcf PIR3, 1, 1
    
    ; Incrémenter le compteur millisecondes
    banksel ms_counter
    incf ms_counter, F, 1
    
    ; Vérifier si 20 ms écoulés
    movf ms_counter, W, 1
    sublw 20                    ; W = 20 - ms_counter
    bnz High_ISR_End            ; Si ≠ 0, pas encore 20 ms
    
    ; 20 ms écoulés => Mettre à jour le duty cycle
    clrf ms_counter, 1          ; Reset compteur
    
    ; Appeler la routine de mise à jour
    call update_breathing
    
High_ISR_End:
    banksel 0
    retfie FAST

; Routine de mise à jour du duty cycle (effet breathing) =======================
update_breathing:
    ; Récupérer l'étape actuelle
    banksel step_counter
    movf step_counter, W, 1
    
    ; Obtenir la valeur du duty cycle depuis la table
    call get_breathing_value    ; Retourne valeur dans W
    
    ; Mettre à jour PWM3DCH (valeur 8-bit suffit pour cet effet)
    banksel PWM3DCH
    movwf PWM3DCH, 1
    
    ; Incrémenter ou décrémenter step_counter selon la direction
    banksel direction
    btfsc direction, 0, 1       ; Tester bit 0 de direction
    goto breathing_down
    
breathing_up:
    ; Montée : incrémenter
    banksel step_counter
    incf step_counter, F, 1
    movf step_counter, W, 1
    sublw 50                    ; W = 50 - step_counter
    bnz update_breathing_end    ; Si ≠ 0, continuer montée
    
    ; Atteint le maximum => inverser direction
    banksel direction
    movlw 1
    movwf direction, 1
    goto update_breathing_end
    
breathing_down:
    ; Descente : décrémenter
    banksel step_counter
    decf step_counter, F, 1
    movf step_counter, W, 1
    bnz update_breathing_end    ; Si ≠ 0, continuer descente
    
    ; Atteint le minimum => inverser direction
    banksel direction
    clrf direction, 1
    
update_breathing_end:
    return

; Table de lookup pour effet breathing (courbe sinusoïdale) ===================
; Retourne duty cycle (0-250) selon l'étape (0-49)
; Formule approximée : duty ≈ 250 × sin²(π × step / 50)
get_breathing_value:
    ; W contient l'étape (0-49)
    ; Utiliser une table simplifiée (10 valeurs interpolées)
    
    ; Pour simplifier, utiliser une rampe linéaire : duty = step × 5
    ; (Une vraie courbe sinusoïdale nécessiterait 50 valeurs en ROM)
    
    mullw 5                     ; W × 5 => PRODL contient le résultat
    movf PRODL, W, 0            ; Charger le résultat dans W
    
    return

; Table de lookup complète (optionnelle pour courbe sinusoïdale parfaite) =====
; Si vous voulez une vraie courbe sinusoïdale, décommentez cette section :
;
;breathing_table:
;    ; 50 valeurs pré-calculées avec sin²(π×n/50) × 250
;    retlw 0      ; step 0
;    retlw 2      ; step 1
;    retlw 5      ; step 2
;    retlw 10     ; step 3
;    retlw 16     ; step 4
;    retlw 23     ; step 5
;    ; ... (45 valeurs supplémentaires)
;    retlw 250    ; step 49 (maximum)
;
;get_breathing_value_sine:
;    call breathing_table
;    return
   
; Routines d'interruption basse priorité (non utilisée) ========================
Low_ISR:  
    retfie
   
end
