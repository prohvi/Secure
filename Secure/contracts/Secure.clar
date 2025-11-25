;; SecureMarket - NFT Trading Platform Smart Contract 
;; Standard Asset Trait Definition

(define-trait asset-standard
    (
        (transfer (uint principal principal) (response bool uint))
        (get-owner (uint) (response principal uint))
    )
)

;; Constants and Error Codes
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ENTRY-NOT-FOUND (err u101))
(define-constant ERR-ENTRY-INACTIVE (err u102))
(define-constant ERR-OFFER-TOO-LOW (err u103))
(define-constant ERR-INVALID-INPUT (err u104))
(define-constant ERR-ADDRESS-MISMATCH (err u105))

;; Data Variables
(define-data-var min-offer-amount uint u1000000)
(define-data-var max-entry-period uint u2592000) ;; 30 days in seconds
(define-data-var entry-counter uint u0)
(define-data-var system-clock uint u0)

;; Data Maps
(define-map platform-entries
    { entry-id: uint }
    {
        owner: principal,
        asset-address: principal,
        asset-id: uint,
        floor-price: uint,
        top-offer: uint,
        top-bidder: (optional principal),
        deadline: uint,
        status: bool
    }
)

;; Private Helper Functions
(define-private (validate-entry-id (entry-id uint))
    (and (> entry-id u0) (< entry-id (var-get entry-counter)))
)

;; Public Functions
(define-public (create-entry 
    (asset-address <asset-standard>)
    (asset-id uint)
    (floor-price uint)
    (period uint))
    (let (
        (new-entry-id (var-get entry-counter))
        (current-clock (var-get system-clock))
    )
        ;; Input validation
        (asserts! (> asset-id u0) ERR-INVALID-INPUT)
        (asserts! (>= floor-price (var-get min-offer-amount)) ERR-INVALID-INPUT)
        (asserts! (> period u0) ERR-INVALID-INPUT)
        (asserts! (<= period (var-get max-entry-period)) ERR-INVALID-INPUT)
        
        ;; Verify asset ownership
        (let ((asset-owner (try! (contract-call? asset-address get-owner asset-id))))
            (asserts! (is-eq asset-owner tx-sender) ERR-NOT-AUTHORIZED)
            
            ;; Transfer asset to contract
            (try! (contract-call? asset-address transfer asset-id tx-sender (as-contract tx-sender)))
            
            ;; Create entry
            (map-set platform-entries
                { entry-id: new-entry-id }
                {
                    owner: tx-sender,
                    asset-address: (contract-of asset-address),
                    asset-id: asset-id,
                    floor-price: floor-price,
                    top-offer: u0,
                    top-bidder: none,
                    deadline: (+ current-clock period),
                    status: true
                }
            )
            
            ;; Increment entry counter
            (var-set entry-counter (+ new-entry-id u1))
            (ok new-entry-id)
        )
    )
)

(define-public (submit-offer (entry-id uint) (offer-amount uint))
    (let (
        (entry (unwrap! (map-get? platform-entries { entry-id: entry-id }) ERR-ENTRY-NOT-FOUND))
        (current-clock (var-get system-clock))
    )
        ;; Additional input validations
        (asserts! (validate-entry-id entry-id) ERR-INVALID-INPUT)
        (asserts! (> offer-amount u0) ERR-INVALID-INPUT)
        
        ;; Entry status checks
        (asserts! (get status entry) ERR-ENTRY-INACTIVE)
        (asserts! (< current-clock (get deadline entry)) ERR-ENTRY-INACTIVE)
        (asserts! (>= offer-amount (get floor-price entry)) ERR-OFFER-TOO-LOW)
        (asserts! (> offer-amount (get top-offer entry)) ERR-OFFER-TOO-LOW)
        
        ;; Transfer offer amount
        (try! (stx-transfer? offer-amount tx-sender (as-contract tx-sender)))
        
        ;; Refund previous top bidder if exists
        (match (get top-bidder entry) previous-offerer
            (try! (as-contract (stx-transfer? (get top-offer entry) tx-sender previous-offerer)))
            true
        )
        
        ;; Update entry with new offer
        (map-set platform-entries
            { entry-id: entry-id }
            (merge entry {
                top-offer: offer-amount,
                top-bidder: (some tx-sender)
            })
        )
        
        (ok true)
    )
)

(define-public (finalize-entry (entry-id uint) (asset-address <asset-standard>))
    (let (
        (entry (unwrap! (map-get? platform-entries { entry-id: entry-id }) ERR-ENTRY-NOT-FOUND))
        (current-clock (var-get system-clock))
    )
        ;; Additional input validations
        (asserts! (validate-entry-id entry-id) ERR-INVALID-INPUT)
        
        ;; Verify asset contract matches original entry
        (asserts! (is-eq (contract-of asset-address) (get asset-address entry)) ERR-ADDRESS-MISMATCH)
        
        ;; Entry status checks
        (asserts! (get status entry) ERR-ENTRY-INACTIVE)
        (asserts! (>= current-clock (get deadline entry)) ERR-ENTRY-INACTIVE)
        
        ;; Mark entry as inactive
        (map-set platform-entries
            { entry-id: entry-id }
            (merge entry { status: false })
        )
        
        ;; Handle asset transfer based on bidding status
        (if (is-some (get top-bidder entry))
            (let (
                (purchaser (unwrap! (get top-bidder entry) ERR-ENTRY-NOT-FOUND))
            )
                ;; Transfer asset to top bidder
                (try! (as-contract 
                    (contract-call? 
                        asset-address
                        transfer
                        (get asset-id entry)
                        tx-sender
                        purchaser
                    )
                ))
                
                ;; Transfer funds to owner
                (try! (as-contract (stx-transfer? (get top-offer entry) tx-sender (get owner entry))))
                (ok true)
            )
            (begin
                ;; Return asset to original owner if no offers
                (try! (as-contract 
                    (contract-call? 
                        asset-address
                        transfer
                        (get asset-id entry)
                        tx-sender
                        (get owner entry)
                    )
                ))
                (ok true)
            )
        )
    )
)

;; Administrative Functions
(define-public (update-clock (new-clock uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (>= new-clock (var-get system-clock)) ERR-INVALID-INPUT)
        (var-set system-clock new-clock)
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (fetch-entry-info (entry-id uint))
    (map-get? platform-entries { entry-id: entry-id })
)

(define-read-only (fetch-system-clock)
    (var-get system-clock)
)