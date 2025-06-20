;; License Coordination Contract
;; Coordinates IP licensing agreements

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_LICENSE_EXISTS (err u401))
(define-constant ERR_LICENSE_NOT_FOUND (err u402))
(define-constant ERR_INVALID_TERMS (err u403))
(define-constant ERR_LICENSE_EXPIRED (err u404))

;; License status constants
(define-constant STATUS_PROPOSED u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_TERMINATED u3)
(define-constant STATUS_EXPIRED u4)

;; License agreements
(define-map licenses
  { license-id: (string-ascii 50) }
  {
    ip-id: (string-ascii 50),
    licensor: principal,
    licensee: principal,
    license-type: (string-ascii 50), ;; "exclusive", "non-exclusive", "sole"
    royalty-rate: uint, ;; percentage * 100 (e.g., 500 = 5%)
    start-date: uint,
    end-date: uint,
    status: uint,
    terms: (string-ascii 500)
  }
)

;; License payments tracking
(define-map license-payments
  { license-id: (string-ascii 50), payment-id: uint }
  {
    amount: uint,
    payment-date: uint,
    period-start: uint,
    period-end: uint
  }
)

;; Payment counter for each license
(define-map payment-counters
  { license-id: (string-ascii 50) }
  { counter: uint }
)

;; Create license agreement
(define-public (create-license
  (license-id (string-ascii 50))
  (ip-id (string-ascii 50))
  (licensee principal)
  (license-type (string-ascii 50))
  (royalty-rate uint)
  (duration uint)
  (terms (string-ascii 500))
)
  (begin
    (asserts! (is-none (map-get? licenses { license-id: license-id })) ERR_LICENSE_EXISTS)
    (asserts! (<= royalty-rate u10000) ERR_INVALID_TERMS) ;; Max 100%
    (ok (map-set licenses
      { license-id: license-id }
      {
        ip-id: ip-id,
        licensor: tx-sender,
        licensee: licensee,
        license-type: license-type,
        royalty-rate: royalty-rate,
        start-date: block-height,
        end-date: (+ block-height duration),
        status: STATUS_PROPOSED,
        terms: terms
      }
    ))
  )
)

;; Accept license agreement (by licensee)
(define-public (accept-license (license-id (string-ascii 50)))
  (let ((license-data (unwrap! (map-get? licenses { license-id: license-id }) ERR_LICENSE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get licensee license-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status license-data) STATUS_PROPOSED) ERR_INVALID_TERMS)
    (ok (map-set licenses
      { license-id: license-id }
      (merge license-data { status: STATUS_ACTIVE })
    ))
  )
)

;; Record license payment
(define-public (record-payment
  (license-id (string-ascii 50))
  (amount uint)
  (period-start uint)
  (period-end uint)
)
  (let (
    (license-data (unwrap! (map-get? licenses { license-id: license-id }) ERR_LICENSE_NOT_FOUND))
    (current-counter (default-to u0 (get counter (map-get? payment-counters { license-id: license-id }))))
    (new-counter (+ current-counter u1))
  )
    (asserts! (is-eq tx-sender (get licensee license-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status license-data) STATUS_ACTIVE) ERR_INVALID_TERMS)
    (map-set payment-counters { license-id: license-id } { counter: new-counter })
    (ok (map-set license-payments
      { license-id: license-id, payment-id: new-counter }
      {
        amount: amount,
        payment-date: block-height,
        period-start: period-start,
        period-end: period-end
      }
    ))
  )
)

;; Get license information
(define-read-only (get-license (license-id (string-ascii 50)))
  (map-get? licenses { license-id: license-id })
)

;; Check if license is active
(define-read-only (is-license-active (license-id (string-ascii 50)))
  (match (map-get? licenses { license-id: license-id })
    license-data (and
      (is-eq (get status license-data) STATUS_ACTIVE)
      (> (get end-date license-data) block-height)
    )
    false
  )
)

;; Terminate license
(define-public (terminate-license (license-id (string-ascii 50)))
  (let ((license-data (unwrap! (map-get? licenses { license-id: license-id }) ERR_LICENSE_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get licensor license-data))
                  (is-eq tx-sender (get licensee license-data))) ERR_UNAUTHORIZED)
    (ok (map-set licenses
      { license-id: license-id }
      (merge license-data { status: STATUS_TERMINATED })
    ))
  )
)
