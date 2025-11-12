(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-rented (err u103))
(define-constant err-not-rented (err u104))
(define-constant err-insufficient-payment (err u105))
(define-constant err-rental-expired (err u106))
(define-constant err-device-exists (err u107))

(define-constant err-invalid-rating (err u108))
(define-constant err-already-rated (err u109))
(define-constant err-no-completed-rental (err u110))

(define-constant err-dispute-exists (err u111))
(define-constant err-dispute-not-found (err u112))
(define-constant err-dispute-window-closed (err u113))
(define-constant err-dispute-already-resolved (err u114))
(define-constant err-no-rental-history (err u115))

(define-constant dispute-window-blocks u288)
(define-constant dispute-response-window u720)
(define-constant renter-partial-refund-percent u70)

(define-map devices
    { device-id: uint }
    {
        owner: principal,
        name: (string-ascii 64),
        daily-rate: uint,
        deposit: uint,
        available: bool
    }
)

(define-map rentals
    { device-id: uint }
    {
        renter: principal,
        start-block: uint,
        end-block: uint,
        deposit-paid: uint,
        rate-paid: uint
    }
)

(define-data-var device-counter uint u0)

(define-public (register-device (name (string-ascii 64)) (daily-rate uint) (deposit uint))
    (let ((device-id (+ (var-get device-counter) u1)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? devices { device-id: device-id })) err-device-exists)
        (map-set devices
            { device-id: device-id }
            {
                owner: tx-sender,
                name: name,
                daily-rate: daily-rate,
                deposit: deposit,
                available: true
            }
        )
        (var-set device-counter device-id)
        (ok device-id)
    )
)

(define-public (rent-device (device-id uint) (rental-days uint))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (total-cost (+ (get deposit device) (* (get daily-rate device) rental-days)))
        (end-block (+ stacks-block-height (* rental-days u144)))
    )
        (asserts! (get available device) err-already-rented)
        (asserts! (>= (stx-get-balance tx-sender) total-cost) err-insufficient-payment)
        (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
        (map-set devices
            { device-id: device-id }
            (merge device { available: false })
        )
        (map-set rentals
            { device-id: device-id }
            {
                renter: tx-sender,
                start-block: stacks-block-height,
                end-block: end-block,
                deposit-paid: (get deposit device),
                rate-paid: (* (get daily-rate device) rental-days)
            }
        )
        (ok true)
    )
)

(define-public (return-device (device-id uint))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (rental (unwrap! (map-get? rentals { device-id: device-id }) err-not-rented))
        (is-on-time (<= stacks-block-height (get end-block rental)))
        (penalty (if is-on-time u0 (/ (get deposit-paid rental) u2)))
        (refund-amount (- (get deposit-paid rental) penalty))
    )
        (asserts! (is-eq tx-sender (get renter rental)) err-unauthorized)
        (asserts! (not (get available device)) err-not-rented)
        (try! (as-contract (stx-transfer? refund-amount tx-sender (get renter rental))))
        (map-set devices
            { device-id: device-id }
            (merge device { available: true })
        )
        (map-delete rentals { device-id: device-id })
        (ok refund-amount)
    )
)

(define-public (extend-rental (device-id uint) (additional-days uint))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (rental (unwrap! (map-get? rentals { device-id: device-id }) err-not-rented))
        (extension-cost (* (get daily-rate device) additional-days))
        (new-end-block (+ (get end-block rental) (* additional-days u144)))
    )
        (asserts! (is-eq tx-sender (get renter rental)) err-unauthorized)
        (asserts! (>= stacks-block-height (get end-block rental)) err-rental-expired)
        (asserts! (>= (stx-get-balance tx-sender) extension-cost) err-insufficient-payment)
        (try! (stx-transfer? extension-cost tx-sender (as-contract tx-sender)))
        (map-set rentals
            { device-id: device-id }
            (merge rental {
                end-block: new-end-block,
                rate-paid: (+ (get rate-paid rental) extension-cost)
            })
        )
        (ok new-end-block)
    )
)

(define-public (claim-overdue-device (device-id uint))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (rental (unwrap! (map-get? rentals { device-id: device-id }) err-not-rented))
        (overdue-blocks (- stacks-block-height (get end-block rental)))
    )
        (asserts! (is-eq tx-sender (get owner device)) err-unauthorized)
        (asserts! (> stacks-block-height (+ (get end-block rental) u1008)) err-not-rented)
        (try! (as-contract (stx-transfer? (get deposit-paid rental) tx-sender (get owner device))))
        (map-set devices
            { device-id: device-id }
            (merge device { available: true })
        )
        (map-delete rentals { device-id: device-id })
        (ok overdue-blocks)
    )
)

(define-read-only (get-device (device-id uint))
    (map-get? devices { device-id: device-id })
)

(define-read-only (get-rental (device-id uint))
    (map-get? rentals { device-id: device-id })
)

(define-read-only (get-device-count)
    (var-get device-counter)
)

(define-read-only (is-device-available (device-id uint))
    (match (map-get? devices { device-id: device-id })
        device (get available device)
        false
    )
)

(define-read-only (get-rental-status (device-id uint))
    (match (map-get? rentals { device-id: device-id })
        rental (some {
            renter: (get renter rental),
            blocks-remaining: (if (> (get end-block rental) stacks-block-height)
                (- (get end-block rental) stacks-block-height)
                u0
            ),
            is-overdue: (> stacks-block-height (get end-block rental))
        })
        none
    )
)

(define-read-only (calculate-rental-cost (device-id uint) (rental-days uint))
    (match (map-get? devices { device-id: device-id })
        device (some (+ (get deposit device) (* (get daily-rate device) rental-days)))
        none
    )
)


(define-map device-ratings
    { device-id: uint, renter: principal }
    { rating: uint, review: (string-ascii 256), block-height: uint }
)

(define-map device-rating-summary
    { device-id: uint }
    { total-rating: uint, rating-count: uint, average-rating: uint }
)

(define-public (rate-device (device-id uint) (rating uint) (review (string-ascii 256)))
    (let (
        (rating-key { device-id: device-id, renter: tx-sender })
        (summary-key { device-id: device-id })
        (current-summary (default-to { total-rating: u0, rating-count: u0, average-rating: u0 }
            (map-get? device-rating-summary summary-key)))
    )
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        (asserts! (is-none (map-get? device-ratings rating-key)) err-already-rated)
        
        (map-set device-ratings rating-key {
            rating: rating,
            review: review,
            block-height: stacks-block-height
        })
        
        (let (
            (new-total (+ (get total-rating current-summary) rating))
            (new-count (+ (get rating-count current-summary) u1))
            (new-average (/ new-total new-count))
        )
            (map-set device-rating-summary summary-key {
                total-rating: new-total,
                rating-count: new-count,
                average-rating: new-average
            })
        )
        (ok true)
    )
)

(define-read-only (get-device-rating (device-id uint) (renter principal))
    (map-get? device-ratings { device-id: device-id, renter: renter })
)

(define-read-only (get-device-rating-summary (device-id uint))
    (map-get? device-rating-summary { device-id: device-id })
)

(define-read-only (get-device-average-rating (device-id uint))
    (match (map-get? device-rating-summary { device-id: device-id })
        summary (some (get average-rating summary))
        none
    )
)

(define-read-only (has-user-rated-device (device-id uint) (user principal))
    (is-some (map-get? device-ratings { device-id: device-id, renter: user }))
)


(define-map device-pricing-strategy
    { device-id: uint }
    {
        base-rate: uint,
        peak-multiplier: uint,
        off-peak-multiplier: uint,
        enabled: bool
    }
)

(define-map time-based-rates
    { device-id: uint, period-start: uint }
    { rate-multiplier: uint }
)

(define-constant price-scale u100)

(define-public (configure-dynamic-pricing 
    (device-id uint) 
    (base-rate uint) 
    (peak-multiplier uint) 
    (off-peak-multiplier uint))
    (let ((device (unwrap! (map-get? devices { device-id: device-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get owner device)) err-unauthorized)
        (asserts! (and (>= peak-multiplier u100) (<= peak-multiplier u300)) err-invalid-rating)
        (asserts! (and (>= off-peak-multiplier u50) (<= off-peak-multiplier u100)) err-invalid-rating)
        (map-set device-pricing-strategy
            { device-id: device-id }
            {
                base-rate: base-rate,
                peak-multiplier: peak-multiplier,
                off-peak-multiplier: off-peak-multiplier,
                enabled: true
            }
        )
        (ok true)
    )
)

(define-public (toggle-dynamic-pricing (device-id uint) (enabled bool))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (strategy (unwrap! (map-get? device-pricing-strategy { device-id: device-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender (get owner device)) err-unauthorized)
        (map-set device-pricing-strategy
            { device-id: device-id }
            (merge strategy { enabled: enabled })
        )
        (ok enabled)
    )
)

(define-read-only (calculate-dynamic-rate (device-id uint) (rental-days uint))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (strategy-opt (map-get? device-pricing-strategy { device-id: device-id }))
    )
        (match strategy-opt
            strategy (if (get enabled strategy)
                (let (
                    (current-day-of-week (mod (/ stacks-block-height u144) u7))
                    (is-weekend (or (is-eq current-day-of-week u5) (is-eq current-day-of-week u6)))
                    (multiplier (if is-weekend (get peak-multiplier strategy) (get off-peak-multiplier strategy)))
                    (adjusted-rate (/ (* (get base-rate strategy) multiplier) price-scale))
                )
                    (ok (* adjusted-rate rental-days))
                )
                (ok (* (get daily-rate device) rental-days))
            )
            (ok (* (get daily-rate device) rental-days))
        )
    )
)

(define-read-only (get-current-rate-multiplier (device-id uint))
    (match (map-get? device-pricing-strategy { device-id: device-id })
        strategy (if (get enabled strategy)
            (let (
                (current-day-of-week (mod (/ stacks-block-height u144) u7))
                (is-weekend (or (is-eq current-day-of-week u5) (is-eq current-day-of-week u6)))
            )
                (some (if is-weekend (get peak-multiplier strategy) (get off-peak-multiplier strategy)))
            )
            (some price-scale)
        )
        none
    )
)

(define-read-only (get-pricing-strategy (device-id uint))
    (map-get? device-pricing-strategy { device-id: device-id })
)


(define-map device-disputes
    { device-id: uint, renter: principal }
    {
        reason: (string-ascii 256),
        filed-at-block: uint,
        status: (string-ascii 24),
        refund-amount: uint,
        owner-responded: bool
    }
)

(define-map rental-history
    { device-id: uint, renter: principal }
    { returned-at-block: uint, deposit-amount: uint }
)

(define-public (record-rental-completion (device-id uint) (renter principal) (deposit uint))
    (let ((device (unwrap! (map-get? devices { device-id: device-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get owner device)) err-unauthorized)
        (map-set rental-history
            { device-id: device-id, renter: renter }
            { returned-at-block: stacks-block-height, deposit-amount: deposit }
        )
        (ok true)
    )
)

(define-public (file-dispute (device-id uint) (reason (string-ascii 256)))
    (let (
        (dispute-key { device-id: device-id, renter: tx-sender })
        (history (unwrap! (map-get? rental-history dispute-key) err-no-rental-history))
        (blocks-since-return (- stacks-block-height (get returned-at-block history)))
    )
        (asserts! (is-none (map-get? device-disputes dispute-key)) err-dispute-exists)
        (asserts! (<= blocks-since-return dispute-window-blocks) err-dispute-window-closed)
        (map-set device-disputes dispute-key {
            reason: reason,
            filed-at-block: stacks-block-height,
            status: "pending",
            refund-amount: u0,
            owner-responded: false
        })
        (ok true)
    )
)

(define-public (resolve-dispute (device-id uint) (renter principal) (in-favor-of-renter bool))
    (let (
        (device (unwrap! (map-get? devices { device-id: device-id }) err-not-found))
        (dispute-key { device-id: device-id, renter: renter })
        (dispute (unwrap! (map-get? device-disputes dispute-key) err-dispute-not-found))
        (history (unwrap! (map-get? rental-history dispute-key) err-no-rental-history))
        (refund (if in-favor-of-renter (/ (* (get deposit-amount history) renter-partial-refund-percent) u100) u0))
    )
        (asserts! (is-eq tx-sender (get owner device)) err-unauthorized)
        (asserts! (is-eq (get status dispute) "pending") err-dispute-already-resolved)
        (if in-favor-of-renter
            (try! (as-contract (stx-transfer? refund tx-sender renter)))
            true
        )
        (map-set device-disputes dispute-key
            (merge dispute {
                status: (if in-favor-of-renter "resolved-favor-renter" "resolved-favor-owner"),
                refund-amount: refund,
                owner-responded: true
            })
        )
        (ok refund)
    )
)

(define-read-only (get-dispute (device-id uint) (renter principal))
    (map-get? device-disputes { device-id: device-id, renter: renter })
)

(define-read-only (check-auto-resolve-eligible (device-id uint) (renter principal))
    (match (map-get? device-disputes { device-id: device-id, renter: renter })
        dispute (and
            (is-eq (get status dispute) "pending")
            (> (- stacks-block-height (get filed-at-block dispute)) dispute-response-window)
        )
        false
    )
)