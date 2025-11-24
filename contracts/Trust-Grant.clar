;; GrantFlow.clar
;; GrantFlow: Smart NGO Grant Disbursement System
;; Version: 1.0
;; Author: (your name)
;;
;; Notes:
;; - Deployer becomes initial admin.
;; - Donors send STX to the contract; funds are credited to NGO balances.
;; - Admin approves NGOs and verifies milestones.
;; - Funds are released from the contract to the NGO owner only after verification.

(define-data-var admin principal tx-sender)

;; ----------------------------
;; Events (define-event not supported in this compiler; use printed tuples)
;; ----------------------------
(define-constant event-ngo-registered "ngo-registered")
(define-constant event-ngo-approved "ngo-approved")
(define-constant event-milestone-created "milestone-created")
(define-constant event-milestone-verified "milestone-verified")
(define-constant event-funds-donated "funds-donated")
(define-constant event-funds-released "funds-released")

;; ----------------------------
;; Data structures
;; ----------------------------

;; NGO registry: id -> { owner: principal, approved: bool }
(define-map ngos
  { id: uint }
  { owner: principal, approved: bool }
)

;; Contract-held balances per NGO (credited when donors send funds)
(define-map ngo-balances
  { ngo-id: uint }
  { balance: uint }
)

;; Milestones map: (ngo-id, milestone-id) -> milestone struct
(define-map milestones
  { ngo-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    amount: uint,
    verified: bool,
    released: bool
  }
)

;; ----------------------------
;; Helpers / Read-only utilities
;; ----------------------------

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (is-admin (sender principal))
  (is-eq sender (var-get admin))
)

(define-read-only (ngo-exists (ngo-id uint))
  (is-some (map-get? ngos { id: ngo-id }))
)

(define-read-only (get-ngo (ngo-id uint))
  (map-get? ngos { id: ngo-id })
)

(define-read-only (get-ngo-balance (ngo-id uint))
  (default-to u0 (get balance (map-get? ngo-balances { ngo-id: ngo-id })))
)

(define-read-only (get-milestone (ngo-id uint) (milestone-id uint))
  (map-get? milestones { ngo-id: ngo-id, milestone-id: milestone-id })
)

;; ----------------------------
;; Admin management
;; ----------------------------

;; Change admin (only current admin)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) (err u100)) ;; error code u100 = not-admin
    (var-set admin new-admin)
    (ok true)
  )
)

;; ----------------------------
;; NGO registration & approval
;; ----------------------------

;; Register a new NGO (any address can register an NGO id; id must be unique)
(define-public (register-ngo (ngo-id uint))
  (begin
    (asserts! (is-none (map-get? ngos { id: ngo-id })) (err u101)) ;; u101 = ngo-id-exists
    (map-set ngos { id: ngo-id } { owner: tx-sender, approved: false })
    (print { event: event-ngo-registered, ngo-id: ngo-id, owner: tx-sender })
    (ok true)
  )
)

;; Approve an NGO (admin only)
(define-public (approve-ngo (ngo-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err u100))
    (match (map-get? ngos { id: ngo-id })
      ngo
      (begin
        (map-set ngos { id: ngo-id } { owner: (get owner ngo), approved: true })
        (print { event: event-ngo-approved, ngo-id: ngo-id })
        (ok true)
      )
      (err u102) ;; u102 = ngo-not-found
    )
  )
)

;; ----------------------------
;; Donor actions
;; ----------------------------

;; Donate STX to a registered & approved NGO.
;; Donor must provide the donation amount and the contract will transfer STX from the donor to itself.
(define-public (donate (ngo-id uint) (amount uint))
  (begin
    (asserts! (> amount u0) (err u103)) ;; u103 = invalid-amount
    ;; NGO must exist and be approved
    (match (map-get? ngos { id: ngo-id })
      ngo
      (begin
        (asserts! (get approved ngo) (err u104)) ;; u104 = ngo-not-approved
        ;; transfer STX from donor (tx-sender) to this contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        ;; credit the ngo balance
        (let ((existing (default-to u0 (get balance (map-get? ngo-balances { ngo-id: ngo-id })))))
          (map-set ngo-balances { ngo-id: ngo-id } { balance: (+ existing amount) })
        )
        (print { event: event-funds-donated, ngo-id: ngo-id, donor: tx-sender, amount: amount })
        (ok true)
      )
      (err u102)
    )
  )
)

;; ----------------------------
;; NGO: milestones
;; ----------------------------

;; Create a milestone request (only NGO owner)
(define-public (create-milestone (ngo-id uint) (milestone-id uint) (description (string-ascii 200)) (amount uint))
  (begin
    ;; verify NGO exists and caller is owner
    (match (map-get? ngos { id: ngo-id })
      ngo
      (begin
        (asserts! (is-eq (get owner ngo) tx-sender) (err u105)) ;; u105 = not-ngo-owner
        ;; milestone id must be unique for this ngo
        (asserts! (is-none (map-get? milestones { ngo-id: ngo-id, milestone-id: milestone-id })) (err u106)) ;; u106 = milestone-exists
        (map-set milestones { ngo-id: ngo-id, milestone-id: milestone-id }
          { description: description, amount: amount, verified: false, released: false })
        (print { event: event-milestone-created, ngo-id: ngo-id, milestone-id: milestone-id, amount: amount })
        (ok true)
      )
      (err u102)
    )
  )
)

;; ----------------------------
;; Admin: verify milestone
;; ----------------------------

(define-public (verify-milestone (ngo-id uint) (milestone-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err u100))
    (match (map-get? milestones { ngo-id: ngo-id, milestone-id: milestone-id })
      m
      (begin
        (asserts! (not (get verified m)) (err u107)) ;; u107 = milestone-already-verified
        ;; mark verified (released remains false)
        (map-set milestones { ngo-id: ngo-id, milestone-id: milestone-id }
          { description: (get description m),
            amount: (get amount m),
            verified: true,
            released: false })
        (print { event: event-milestone-verified, ngo-id: ngo-id, milestone-id: milestone-id })
        (ok true)
      )
      (err u108) ;; u108 = milestone-not-found
    )
  )
)

;; ----------------------------
;; Release funds for verified milestone
;; ----------------------------

(define-public (release-funds (ngo-id uint) (milestone-id uint))
  (begin
    ;; milestone must exist
    (match (map-get? milestones { ngo-id: ngo-id, milestone-id: milestone-id })
      m
      (let ((amount (get amount m)))
        (begin
          (asserts! (get verified m) (err u109))   ;; u109 = milestone-not-verified
          (asserts! (not (get released m)) (err u110)) ;; u110 = milestone-already-released

          ;; check contract holds enough balance for this NGO
          (let ((current (default-to u0 (get balance (map-get? ngo-balances { ngo-id: ngo-id })))))
            (asserts! (>= current amount) (err u111)) ;; u111 = insufficient-funds

            ;; get ngo owner
            (let ((ngo (unwrap-panic (map-get? ngos { id: ngo-id }))))
              (let ((owner (get owner ngo)))
                ;; transfer from contract to ngo owner
                (try! (stx-transfer? amount (as-contract tx-sender) owner))
                ;; debit ngo balance
                (map-set ngo-balances { ngo-id: ngo-id } { balance: (- current amount) })
                ;; mark milestone released
                (map-set milestones { ngo-id: ngo-id, milestone-id: milestone-id }
                  { description: (get description m), amount: amount, verified: true, released: true })
                (print { event: event-funds-released, ngo-id: ngo-id, milestone-id: milestone-id, amount: amount })
                (ok true)
              )
            )
          )
        )
      )
      (err u108)
    )
  )
)

;; ----------------------------
;; Read-only helpers for frontends
;; ----------------------------

(define-read-only (list-ngo (ngo-id uint))
  (map-get? ngos { id: ngo-id })
)

(define-read-only (list-milestone (ngo-id uint) (milestone-id uint))
  (map-get? milestones { ngo-id: ngo-id, milestone-id: milestone-id })
)

(define-read-only (contract-balance)
  ;; returns the contract's STX balance as a uint
  (ok (stx-get-balance (as-contract tx-sender)))
)
