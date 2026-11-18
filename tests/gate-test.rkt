#lang racket/base

;; Development-preview regression: commercial rights, trial clocks and
;; purchase credentials must never block user-visible engineering workflows.
(require rackunit "../app/gate.rkt")

(check-equal? (gate-init!) 'development)
(check-equal? (gate-tier) 'development)
(check-true (gate-pro?) "legacy host capability bool must allow functionality")
(for ([action '(engine report reference unknown)])
  (check-true (gate-check action)
              "the preview must not deny product functionality"))
(check-false (gate-updates-through))
(for ([published-at (list #f "2026-01-01T00:00:00Z" "2099-01-01T00:00:00Z")])
  (check-true (gate-update-window-open?
               #:release-published-at published-at)
              "commercial update windows are retired"))
(check-equal? (gate-trial-start!) 'development)
(define-values (activation-ok? activation-message)
  (gate-activate! "no-such-file.permit.json"))
(check-false activation-ok? "paid activation cannot be enabled")
(check-true (string? activation-message))
(check-equal? (gate-deactivate!) 'development)
(define info (gate-info))
(check-equal? (hash-ref info 'tier) "development")
(check-equal? (hash-ref info 'trial_days) 0)
(check-true (hash-ref info 'pro))
(check-equal? (gate-installation-id) "")
