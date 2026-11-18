#lang racket/base

;; Quality-first development policy (2026-11-18).
;;
;; Legacy hosts and the typed RPC schema still call the historical gate API.
;; It is now a strictly local, inert compatibility boundary: every supported
;; operation is available for product validation, with no trial clock,
;; commercial credential, identity, activation, pricing or update window.
;;
;; Do NOT remove Ed25519 *update signature verification*; that remains in
;; racket/support/updates.rkt and the updater and is unrelated to billing.
;; Native "License/Pro" UI labels should be retired as the hosts are updated.

(provide gate-init!
         gate-tier
         gate-pro?
         gate-updates-through
         gate-update-window-open?
         gate-trial-start!
         gate-activate!
         gate-deactivate!
         gate-info
         gate-check
         gate-state-path
         gate-installation-id
         credential-path)

;; Legacy caller compatibility: #t unlocks all product capabilities and
;; applies the full local packet-store capacity. It is *not* a commercial tier.
(define (gate-init!) 'development)
(define (gate-tier) 'development)
(define (gate-pro?) #t)

(define (gate-updates-through) #f)
(define (gate-update-window-open? #:release-published-at published-at) #t)
(define (gate-check action) #t)

;; Compatibility RPCs do not create, read, copy or delete credentials or
;; trial state. Refuse a license import because no paid rights exist.
(define (gate-trial-start!) 'development)
(define (gate-activate! path)
  (values #f "License activation is retired in the development preview."))
(define (gate-deactivate!) 'development)

;; Retain old path accessor signatures for callers that still compile against
;; the interface. They do not imply files are created or consumed.
(define (gate-state-path)
  (build-path (find-system-path 'home-dir) ".gptp-studio" "gate-state.json"))
(define (credential-path)
  (build-path (find-system-path 'home-dir) ".gptp-studio" "entitlement.permit.json"))
(define (gate-installation-id) "")

;; The old wire schema has a boolean field named "pro". Keep it true so
;; existing hosts do not disable engineering controls, while identifying the
;; *actual* tier as a development preview. This is not a paid entitlement.
(define (gate-info)
  (hasheq 'tier "development"
          'pro #t
          'trial_days 0
          'installation_id ""
          'detail (hasheq 'commercial_access #f
                          'trial_enabled #f)))
