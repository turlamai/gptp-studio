#lang info

(define collection "gptp-studio")
(define pkg-desc "gPTP Studio - gPTP / IEEE 802.1AS debugging workstation (Racket + Rivet)")
(define version "0.4.0")
(define pkg-authors '("turlamai"))
(define license 'Apache-2.0)

(define deps
  '("base"
    "rackunit-lib"))

(define build-deps '())

(define categories '(devtools net))
