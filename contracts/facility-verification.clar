;; Facility Verification Contract
;; Purpose: Validates manufacturing production sites

(define-data-var admin principal tx-sender)

;; Facility data structure
(define-map facilities
  { facility-id: uint }
  {
    name: (string-utf8 100),
    location: (string-utf8 200),
    certification-status: bool,
    last-audit-date: uint,
    certification-expiry: uint
  }
)

;; Event for facility registration
(define-public (register-facility (facility-id uint) (name (string-utf8 100)) (location (string-utf8 200)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can register
    (asserts! (is-none (map-get? facilities { facility-id: facility-id })) (err u2)) ;; Cannot overwrite

    (map-set facilities
      { facility-id: facility-id }
      {
        name: name,
        location: location,
        certification-status: false,
        last-audit-date: u0,
        certification-expiry: u0
      }
    )
    (ok true)
  )
)

;; Function to certify a facility after inspection
(define-public (certify-facility (facility-id uint) (certification-expiry uint))
  (let ((facility-data (unwrap! (map-get? facilities { facility-id: facility-id }) (err u3))))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can certify

      (map-set facilities
        { facility-id: facility-id }
        (merge facility-data {
          certification-status: true,
          last-audit-date: block-height,
          certification-expiry: certification-expiry
        })
      )
      (ok true)
    )
  )
)

;; Function to verify if a facility is currently certified
(define-read-only (is-certified (facility-id uint))
  (let ((facility-data (unwrap! (map-get? facilities { facility-id: facility-id }) (err u3))))
    (if (and
          (get certification-status facility-data)
          (<= block-height (get certification-expiry facility-data)))
      (ok true)
      (ok false)
    )
  )
)

;; Function to get facility details
(define-read-only (get-facility-details (facility-id uint))
  (map-get? facilities { facility-id: facility-id })
)

;; Allow transferring admin role
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (var-set admin new-admin)
    (ok true)
  )
)
