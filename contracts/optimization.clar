;; Optimization Contract
;; Purpose: Generates optimized parameters based on simulation results

(define-data-var admin principal tx-sender)

;; Optimization model data structure
(define-map optimization-models
  { model-id: uint }
  {
    name: (string-utf8 100),
    objective: (string-utf8 100),
    constraints: (string-utf8 500),
    created-at: uint,
    is-active: bool
  }
)

;; Optimization run data
(define-map optimization-runs
  { run-id: uint }
  {
    model-id: uint,
    equipment-id: uint,
    simulation-run-id: uint,
    timestamp: uint,
    input-state: (string-utf8 1000),
    optimized-parameters: (string-utf8 1000),
    improvement-score: int,
    is-applied: bool
  }
)

;; Counter for optimization run IDs
(define-data-var next-run-id uint u1)

;; Authorized optimizers
(define-map authorized-optimizers
  { optimizer: principal }
  { is-authorized: bool }
)

;; Initialize admin as authorized optimizer
(map-set authorized-optimizers
  { optimizer: tx-sender }
  { is-authorized: true }
)

;; Add authorized optimizer
(define-public (add-optimizer (optimizer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (map-set authorized-optimizers
      { optimizer: optimizer }
      { is-authorized: true }
    )
    (ok true)
  )
)

;; Remove authorized optimizer
(define-public (remove-optimizer (optimizer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (map-set authorized-optimizers
      { optimizer: optimizer }
      { is-authorized: false }
    )
    (ok true)
  )
)

;; Register an optimization model
(define-public (register-optimization-model
    (model-id uint)
    (name (string-utf8 100))
    (objective (string-utf8 100))
    (constraints (string-utf8 500)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (asserts! (is-none (map-get? optimization-models { model-id: model-id })) (err u2))

    (map-set optimization-models
      { model-id: model-id }
      {
        name: name,
        objective: objective,
        constraints: constraints,
        created-at: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Update model status
(define-public (update-model-status (model-id uint) (is-active bool))
  (let ((model-data (unwrap! (map-get? optimization-models { model-id: model-id }) (err u3))))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1))

      (map-set optimization-models
        { model-id: model-id }
        (merge model-data {
          is-active: is-active
        })
      )
      (ok true)
    )
  )
)

;; Record an optimization run
(define-public (record-optimization-run
    (model-id uint)
    (equipment-id uint)
    (simulation-run-id uint)
    (input-state (string-utf8 1000))
    (optimized-parameters (string-utf8 1000))
    (improvement-score int))
  (let ((model-data (unwrap! (map-get? optimization-models { model-id: model-id }) (err u3)))
        (optimizer-data (default-to { is-authorized: false } (map-get? authorized-optimizers { optimizer: tx-sender })))
        (run-id (var-get next-run-id)))
    (begin
      (asserts! (get is-authorized optimizer-data) (err u4))
      (asserts! (get is-active model-data) (err u5))

      (map-set optimization-runs
        { run-id: run-id }
        {
          model-id: model-id,
          equipment-id: equipment-id,
          simulation-run-id: simulation-run-id,
          timestamp: block-height,
          input-state: input-state,
          optimized-parameters: optimized-parameters,
          improvement-score: improvement-score,
          is-applied: false
        }
      )

      (var-set next-run-id (+ run-id u1))
      (ok run-id)
    )
  )
)

;; Mark optimization as applied to physical system
(define-public (mark-optimization-applied (run-id uint))
  (let ((run-data (unwrap! (map-get? optimization-runs { run-id: run-id }) (err u6))))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1))

      (map-set optimization-runs
        { run-id: run-id }
        (merge run-data {
          is-applied: true
        })
      )
      (ok true)
    )
  )
)

;; Get optimization model details
(define-read-only (get-optimization-model (model-id uint))
  (map-get? optimization-models { model-id: model-id })
)

;; Get optimization run details
(define-read-only (get-optimization-run (run-id uint))
  (map-get? optimization-runs { run-id: run-id })
)

;; Check if an optimizer is authorized
(define-read-only (is-authorized-optimizer (optimizer principal))
  (let ((optimizer-data (default-to { is-authorized: false } (map-get? authorized-optimizers { optimizer: optimizer }))))
    (get is-authorized optimizer-data)
  )
)

;; Allow transferring admin role
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (var-set admin new-admin)
    (ok true)
  )
)
