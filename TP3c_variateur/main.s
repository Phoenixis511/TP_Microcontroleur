PROCESSOR 18F25K40
#include <xc.inc>
   
; Configuration ================================================================
config FEXTOSC = OFF
config RSTOSC = HFINTOSC_64MHZ
config WDTE = OFF
   
; Variables RAM ================================================================
PSECT udata_acs
    palier_actuel: DS 1         ; Palier actuel (0-4)
    palier_cible: DS 1          ; Palier cible (0-4)
    pwm_actuel_H: DS 1          ; PWM actuel (16-bit, partie haute)
    pwm_actuel_L: DS 1          ; PWM actuel (partie basse)
    pwm_cible_H: DS 1           ; PWM cible (partie haute)
    pwm_cible_L: DS 1           ; PWM cible (partie basse)
    transition_step: DS 1       ; Compteur d'étapes de transition (0-50)
    debounce_counter: DS 1      ; Compteur anti-rebond (0-10)
    timer_10ms: DS 1            ; Compteur pour 10 ms
    pending_presses: DS 1       ; Nombre d'appuis en attente
 
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
    ; Initialiser les variables
    banksel palier_actuel
    clrf palier_actuel, 1       ; Palier 0 (0%)
    clrf palier_cible, 1
    clrf pwm_actuel_H, 1        ; PWM = 0
    clrf pwm_actuel_L, 1
    clrf pwm_cible_H, 1
    clrf pwm_cible_L, 1
    clrf transition_step, 1
    clrf debounce_counter, 1
    clrf timer_10ms, 1
    clrf pending_presses, 1
    
    ; LDM1 sur RB4
    banksel ANSELB
    clrf ANSELB, 1
    banksel TRISB
    bcf TRISB, 4, 1             ; RB4 en sortie
    banksel LATB
    bcf LATB, 4, 1
    
    ; LD0-7 sur RD0-7
    banksel ANSELD
    clrf ANSELD, 1
    banksel TRISD
    clrf TRISD, 1               ; RD0-7 en sortie
    banksel LATD
    clrf LATD, 1                ; Toutes éteintes
 
    banksel ANSELC
    bcf ANSELC, 4, 1            ; RC4 digital
    bcf ANSELC, 5, 1            ; RC5 digital
    
    banksel TRISC
    bsf TRISC, 4, 1             ; RC4 en entrée (BP0)
    bsf TRISC, 5, 1             ; RC5 en entrée (BP1)
    
    banksel WPUC
    bsf WPUC, 4, 1              ; Pull-up sur RC4
    bsf WPUC, 5, 1              ; Pull-up sur RC5
    
    ; Configuration IOC (Interrupt On Change) pour les boutons
    banksel IOCC
    bsf IOCC, 4, 1              ; IOC sur RC4 (BP0)
    bsf IOCC, 5, 1              ; IOC sur RC5 (BP1)
    
    banksel IOCCN
    bsf IOCCN, 4, 1             ; IOC sur front descendant RC4
    bsf IOCCN, 5, 1             ; IOC sur front descendant RC5
    
    banksel IOCCF
    clrf IOCCF, 1               ; Effacer les flags
    
    ; 1 ms = 1000 µs / 0.0625 µs = 16000 cycles
    ; Prescaler 1:16 => 16000 / 16 = 1000
    ; PR2 = 999 = 0x3E7
    
    banksel T2CON
    clrf T2CON, 1
    
    banksel T2CLKCON
    movlw 0x01
    movwf T2CLKCON, 1
    
    banksel T2HLT
    clrf T2HLT, 1
    
    banksel PR2
    movlw 0xE7                  ; PR2 = 0x3E7
    movwf PR2, 1
    
    banksel TMR2
    clrf TMR2, 1
    
    banksel PIR3
    bcf PIR3, 1, 1
    
    banksel T2CON
    movlw b'10010000'           ; Prescaler 1:16
    movwf T2CON, 1
    
    banksel PWM3CON
    clrf PWM3CON, 1
    
    banksel PWM3DCH
    clrf PWM3DCH, 1
    banksel PWM3DCL
    clrf PWM3DCL, 1
    
    banksel PWM3CON
    movlw b'10000000'
    movwf PWM3CON, 1
    
    banksel PPSLOCK
    movlw 0x55
    movwf PPSLOCK, 1
    movlw 0xAA
    movwf PPSLOCK, 1
    bcf PPSLOCK, 0, 1
    
    banksel RB4PPS
    movlw 0x0D                  ; PWM3OUT
    movwf RB4PPS, 1
    
    banksel PPSLOCK
    movlw 0x55
    movwf PPSLOCK, 1
    movlw 0xAA
    movwf PPSLOCK, 1
    bsf PPSLOCK, 0, 1
    
    ; ========================================================================
    ; Configuration des interruptions
    ; ========================================================================
    
    ; Timer 2 en haute priorité
    banksel PIE3
    bsf PIE3, 1, 1              ; TMR2IE
    banksel IPR3
    bsf IPR3, 1, 1              ; Haute priorité
    
    ; IOC en basse priorité
    banksel PIE0
    bsf PIE0, 4, 1              ; IOCIE
    banksel IPR0
    bcf IPR0, 4, 1              ; Basse priorité
    
    ; Activer les interruptions
    banksel INTCON0
    bsf INTCON0, 5, 1           ; IPEN = 1
    
    banksel INTCON
    bsf INTCON, 7, 1            ; GIE
    bsf INTCON, 6, 1            ; PEIE
    
    banksel 0
   
; Boucle principale ============================================================
loop:
    nop
    goto loop
   
; ==============================================================================
; Interruptions
; ==============================================================================

; Interruption HAUTE priorité - Timer 2 (1 ms) ================================
High_ISR:
    banksel PIR3
    btfss PIR3, 1, 1
    goto High_ISR_End
    
    bcf PIR3, 1, 1
    
    ; Incrémenter compteur 10 ms
    banksel timer_10ms
    incf timer_10ms, F, 1
    movf timer_10ms, W, 1
    sublw 10
    bnz High_ISR_debounce
    
    ; 10 ms écoulés
    clrf timer_10ms, 1
    
    ; Décrémenter anti-rebond
    movf debounce_counter, W, 1
    btfsc STATUS, 2, 0          ; Skip si non zero
    goto High_ISR_transition
    decf debounce_counter, F, 1
    
High_ISR_transition:
    ; Vérifier si transition en cours
    movf transition_step, W, 1
    btfsc STATUS, 2, 0          ; Z=1 si step=0
    goto High_ISR_End
    
    ; Transition en cours - mise à jour PWM
    call update_transition
    
High_ISR_debounce:
    banksel 0
    
High_ISR_End:
    retfie FAST

; Interruption BASSE priorité - Boutons (IOC) =================================
Low_ISR:
    ; Vérifier si c'est IOC
    banksel PIR0
    btfss PIR0, 4, 1            ; IOCIF
    goto Low_ISR_End
    
    ; Vérifier anti-rebond
    banksel debounce_counter
    movf debounce_counter, W, 1
    btfss STATUS, 2, 0          ; Skip si zero
    goto Low_ISR_Clear          ; Anti-rebond actif, ignorer
    
    ; Recharger anti-rebond (10 × 10ms = 100 ms)
    movlw 10
    movwf debounce_counter, 1
    
    ; Vérifier quel bouton
    banksel IOCCF
    btfsc IOCCF, 5, 1           ; BP1 (augmenter)
    call button_up
    
    btfsc IOCCF, 4, 1           ; BP0 (diminuer)
    call button_down
    
Low_ISR_Clear:
    ; Effacer les flags IOC
    banksel IOCCF
    clrf IOCCF, 1
    
    banksel PIR0
    bcf PIR0, 4, 1
    
Low_ISR_End:
    retfie

; ==============================================================================
; Routines
; ==============================================================================

; Bouton UP (BP1) - Augmenter luminosité ======================================
button_up:
    banksel palier_cible
    movf palier_cible, W, 1
    sublw 4                     ; W = 4 - palier_cible
    btfsc STATUS, 2, 0          ; Skip si non zero
    return                      ; Déjà au maximum
    
    incf palier_cible, F, 1     ; Augmenter palier cible
    call start_transition
    return

; Bouton DOWN (BP0) - Diminuer luminosité =====================================
button_down:
    banksel palier_cible
    movf palier_cible, W, 1
    btfsc STATUS, 2, 0          ; Z=1 si palier=0
    return                      ; Déjà au minimum
    
    decf palier_cible, F, 1     ; Diminuer palier cible
    call start_transition
    return

; Démarrer une transition ======================================================
start_transition:
    ; Calculer PWM cible selon palier_cible
    banksel palier_cible
    movf palier_cible, W, 1
    call get_pwm_value          ; Retourne valeur 16-bit dans PRODH:PRODL
    
    banksel pwm_cible_H
    movf PRODH, W, 0
    movwf pwm_cible_H, 1
    movf PRODL, W, 0
    movwf pwm_cible_L, 1
    
    ; Initialiser compteur de transition (50 étapes)
    movlw 50
    movwf transition_step, 1
    
    ; Mettre à jour affichage LEDs
    call update_leds
    
    return

; Calculer la valeur PWM selon le palier (0-4) ================================
; Entrée : W = palier (0-4)
; Sortie : PRODH:PRODL = valeur PWM (0, 1000, 2000, 3000, 4000)
get_pwm_value:
    mullw 250                   ; W × 250 => PRODH:PRODL
    ; Palier × 250 × 4 = valeur PWM
    ; Décaler gauche de 2 bits (× 4)
    bcf STATUS, 0, 0            ; Clear carry
    rlcf PRODL, F, 0
    rlcf PRODH, F, 0
    rlcf PRODL, F, 0
    rlcf PRODH, F, 0
    return

; Mettre à jour LEDs indicatrices (LD0-7) =====================================
update_leds:
    banksel palier_cible
    movf palier_cible, W, 1
    
    ; Table : 0→0x00, 1→0x03, 2→0x0F, 3→0x3F, 4→0xFF
    call get_led_pattern
    
    banksel LATD
    movwf LATD, 1
    return

; Obtenir le motif LED selon le palier ========================================
get_led_pattern:
    addwf PCL, F, 0             ; Jump table
    retlw 0b00000000            ; Palier 0: 0 LED
    retlw 0b00000011            ; Palier 1: 2 LEDs
    retlw 0b00001111            ; Palier 2: 4 LEDs
    retlw 0b00111111            ; Palier 3: 6 LEDs
    retlw 0b11111111            ; Palier 4: 8 LEDs

; Mettre à jour la transition (appelé toutes les 10 ms) =======================
update_transition:
    ; Calculer l'incrément/décrément
    banksel pwm_actuel_L
    
    ; Delta = (cible - actuel) / step
    ; Approximation : ±20 unités par étape
    
    ; Comparer actuel vs cible
    movf pwm_cible_H, W, 1
    subwf pwm_actuel_H, W, 1    ; W = actuel_H - cible_H
    bnz update_transition_calc
    
    movf pwm_cible_L, W, 1
    subwf pwm_actuel_L, W, 1    ; W = actuel_L - cible_L
    btfsc STATUS, 2, 0          ; Z=1 si égal
    goto transition_complete
    
update_transition_calc:
    ; Si actuel < cible : incrémenter
    movf pwm_actuel_H, W, 1
    subwf pwm_cible_H, W, 1
    btfss STATUS, 0, 0          ; C=1 si cible >= actuel
    goto transition_decrement
    
transition_increment:
    ; Ajouter 20 à pwm_actuel
    movlw 20
    addwf pwm_actuel_L, F, 1
    btfsc STATUS, 0, 0          ; Carry
    incf pwm_actuel_H, F, 1
    goto transition_update_pwm
    
transition_decrement:
    ; Soustraire 20 de pwm_actuel
    movlw 20
    subwf pwm_actuel_L, F, 1
    btfss STATUS, 0, 0          ; Borrow?
    decf pwm_actuel_H, F, 1
    
transition_update_pwm:
    ; Écrire dans PWM3
    banksel PWM3DCH
    movf pwm_actuel_H, W, 1
    movwf PWM3DCH, 1
    movf pwm_actuel_L, W, 1
    movwf PWM3DCL, 1
    
    ; Décrémenter compteur
    banksel transition_step
    decf transition_step, F, 1
    return
    
transition_complete:
    ; Copier cible → actuel
    movf pwm_cible_H, W, 1
    movwf pwm_actuel_H, 1
    movf pwm_cible_L, W, 1
    movwf pwm_actuel_L, 1
    
    ; Mettre à jour palier actuel
    movf palier_cible, W, 1
    movwf palier_actuel, 1
    
    ; Transition terminée
    clrf transition_step, 1
    return
   
end
