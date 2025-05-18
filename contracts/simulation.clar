;; Simulation Contract
;; Purpose: Manages digital replicas of physical manufacturing systems

(define-data-var admin principal tx-sender)

;; Simulation model data structure
(define-map simulation-models
  { model-id: uint }
  {
    equipment-id: uint,
    model-version: (string-utf8 20),
    created-at: uint,
    parameters: (string-utf8 1000),
    accuracy-score: uint,
    is-active: bool
  }
)

;; Simulation run data
(define-map simulation-runs
  { run-id: uint }
  {
    model-id: uint,
    equipment-id: uint,
    timestamp: uint,
    input-parameters: (string-utf8 1000),
    results: (string-utf8 1000),
    validation-score: uint
  }
)

;; Counter for simulation run IDs
(define-data-var next-run-id uint u1)

;; Authorized simulators
(define-map authorized-simulators
  { simulator: principal }
  { is-authorized: bool }
)

;; Initialize admin as authorized simulator
(map-set authorized-simulators
  { simulator: tx-sender }
  { is-authorized: true }
)

;; Add authorized simulator
(define-public (add-simulator (simulator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (map-set authorized-simulators
      { simulator: simulator }
      { is-authorized: true }
    )
    (ok true)
  )
)

;; Remove authorized simulator
(define-public (remove-simulator (simulator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (map-set authorized-simulators
      { simulator: simulator }
      { is-authorized: false }
    )
    (ok true)
  )
)

;; Register a simulation model
(define-public (register-simulation-model
    (model-id uint)
    (equipment-id uint)
    (model-version (string-utf8 20))
    (parameters (string-utf8 1000))
    (accuracy-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (asserts! (is-none (map-get? simulation-models { model-id: model-id })) (err u2))

    (map-set simulation-models
      { model-id: model-id }
      {
        equipment-id: equipment-id,
        model-version: model-version,
        created-at: block-height,
        parameters: parameters,
        accuracy-score: accuracy-score,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Update model status
(define-public (update-model-status (model-id uint) (is-active bool))
  (let ((model-data (unwrap! (map-get? simulation-models { model-id: model-id }) (err u3))))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1))

      (map-set simulation-models
        { model-id: model-id }
        (merge model-data {
          is-active: is-active
        })
      )
      (ok true)
    )
  )
)

;; Record a simulation run
(define-public (record-simulation-run
    (model-id uint)
    (input-parameters (string-utf8 1000))
    (results (string-utf8 1000))
    (validation-score uint))
  (let ((model-data (unwrap! (map-get? simulation-models { model-id: model-id }) (err u3)))
        (simulator-data (default-to { is-authorized: false } (map-get? authorized-simulators { simulator: tx-sender })))
        (run-id (var-get next-run-id)))
    (begin
      (asserts! (get is-authorized simulator-data) (err u4))
      (asserts! (get is-active model-data) (err u5))

      (map-set simulation-runs
        { run-id: run-id }
        {
          model-id: model-id,
          equipment-id: (get equipment-id model-data),
          timestamp: block-height,
          input-parameters: input-parameters,
          results: results,
          validation-score: validation-score
        }
      )

      (var-set next-run-id (+ run-id u1))
      (ok run-id)
    )
  )
)

;; Get simulation model details
(define-read-only (get-simulation-model (model-id uint))
  (map-get? simulation-models { model-id: model-id })
)

;; Get simulation run details
(define-read-only (get-simulation-run (run-id uint))
  (map-get? simulation-runs { run-id: run-id })
)

;; Check if a simulator is authorized
(define-read-only (is-authorized-simulator (simulator principal))
  (let ((simulator-data (default-to { is-authorized: false } (map-get? authorized-simulators { simulator: simulator }))))
    (get is-authorized simulator-data)
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
