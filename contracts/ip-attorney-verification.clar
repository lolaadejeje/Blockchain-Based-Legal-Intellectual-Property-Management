;; IP Attorney Verification Contract
;; Manages verification and registration of intellectual property attorneys

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ATTORNEY_EXISTS (err u101))
(define-constant ERR_ATTORNEY_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Attorney verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Attorney data structure
(define-map attorneys
  { attorney-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    jurisdiction: (string-ascii 50),
    status: uint,
    verified-at: uint,
    verified-by: principal
  }
)

;; Authorized verifiers
(define-map authorized-verifiers principal bool)

;; Initialize contract owner as authorized verifier
(map-set authorized-verifiers CONTRACT_OWNER true)

;; Register a new attorney (pending verification)
(define-public (register-attorney (name (string-ascii 100)) (license-number (string-ascii 50)) (jurisdiction (string-ascii 50)))
  (let ((attorney-id tx-sender))
    (asserts! (is-none (map-get? attorneys { attorney-id: attorney-id })) ERR_ATTORNEY_EXISTS)
    (ok (map-set attorneys
      { attorney-id: attorney-id }
      {
        name: name,
        license-number: license-number,
        jurisdiction: jurisdiction,
        status: STATUS_PENDING,
        verified-at: u0,
        verified-by: tx-sender
      }
    ))
  )
)

;; Verify an attorney (only authorized verifiers)
(define-public (verify-attorney (attorney-id principal))
  (let ((attorney-data (unwrap! (map-get? attorneys { attorney-id: attorney-id }) ERR_ATTORNEY_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (ok (map-set attorneys
      { attorney-id: attorney-id }
      (merge attorney-data {
        status: STATUS_VERIFIED,
        verified-at: block-height,
        verified-by: tx-sender
      })
    ))
  )
)

;; Get attorney information
(define-read-only (get-attorney (attorney-id principal))
  (map-get? attorneys { attorney-id: attorney-id })
)

;; Check if attorney is verified
(define-read-only (is-attorney-verified (attorney-id principal))
  (match (map-get? attorneys { attorney-id: attorney-id })
    attorney-data (is-eq (get status attorney-data) STATUS_VERIFIED)
    false
  )
)

;; Add authorized verifier (only contract owner)
(define-public (add-authorized-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-verifiers verifier true))
  )
)
