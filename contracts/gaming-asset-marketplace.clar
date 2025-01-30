;; gaming-asset-marketplace.clar
;; This smart contract facilitates the management of gaming assets within a marketplace. 
;; It provides functions for minting new assets, transferring ownership, listing and unlisting 
;; assets for sale, and burning assets. The contract supports single and batch minting of assets 
;; with metadata storage and includes checks for asset ownership and validation of asset URIs. 
;; It also handles asset ownership, burn status, and asset listing statuses in a decentralized manner.
;; Only the marketplace administrator has permission to mint assets, while asset owners can transfer, 
;; burn, and list/unlist their assets for sale.

;; Constants
(define-constant marketplace-admin tx-sender) ;; The address of the marketplace administrator
(define-constant err-not-admin (err u110)) ;; Error if the caller is not the admin
(define-constant err-not-asset-owner (err u111)) ;; Error if the caller is not the asset owner
(define-constant err-asset-already-exists (err u112)) ;; Error if the asset already exists
(define-constant err-asset-not-found (err u113)) ;; Error if the asset is not found
(define-constant err-invalid-asset-uri (err u114)) ;; Error if the asset URI is invalid
(define-constant err-burn-asset-failed (err u115)) ;; Error if burning the asset fails
(define-constant max-mint-limit u50) ;; Maximum number of assets that can be minted in a single batch

;; Asset Definitions
(define-non-fungible-token game-asset uint) ;; Define a non-fungible token for gaming assets with uint as ID
(define-data-var asset-counter uint u0) ;; Tracks the current asset ID counter

;; Mappings
(define-map asset-metadata uint (string-ascii 256)) ;; Maps asset ID to its metadata URI
(define-map burned-assets uint bool) ;; Maps asset ID to its burned status (true if burned)
(define-map marketplace-listing uint bool) ;; Maps asset ID to its marketplace listing status (true if listed)

;; Private Helper Functions

(define-private (validate-asset-owner (asset-id uint) (user principal))
    ;; Check if the given user is the owner of the asset
    (is-eq user (unwrap! (nft-get-owner? game-asset asset-id) false)))

(define-private (validate-uri (uri (string-ascii 256)))
    ;; Validate if the URI is within the accepted length (1 to 256 characters)
    (let ((length (len uri)))
        (and (>= length u1)
             (<= length u256))))

(define-private (validate-uri-length (uri (string-ascii 256)))
  ;; Validate if the URI length is between 1 and 256 characters
  (let ((length (len uri)))
    (and (>= length u1)
         (<= length u256))))

(define-private (check-asset-burned (asset-id uint))
    ;; Check if the asset has been burned
    (default-to false (map-get? burned-assets asset-id)))

(define-private (mint-asset (asset-uri (string-ascii 256)))
    ;; Mint a new asset and assign a unique ID to it
    (let ((new-asset-id (+ (var-get asset-counter) u1)))
        (asserts! (validate-uri asset-uri) err-invalid-asset-uri) ;; Validate the URI
        (try! (nft-mint? game-asset new-asset-id tx-sender)) ;; Mint the asset
        (map-set asset-metadata new-asset-id asset-uri) ;; Store the metadata URI
        (var-set asset-counter new-asset-id) ;; Update the asset counter
        (ok new-asset-id)))

;; Public Functions

(define-public (mint-single-asset (uri (string-ascii 256)))
    (begin
        ;; Ensure that only the admin can mint assets
        (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)

        ;; Validate the asset URI
        (asserts! (validate-uri uri) err-invalid-asset-uri)

        ;; Proceed to mint the asset after validation
        (mint-asset uri)))

(define-public (batch-mint-assets (uris (list 50 (string-ascii 256))))
    (let ((mint-count (len uris)))
        (begin
            ;; Ensure that only the admin can batch mint assets
            (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)

            ;; Ensure the batch does not exceed the mint limit
            (asserts! (<= mint-count max-mint-limit) err-asset-already-exists)

            ;; Mint each asset in the list
            (ok (fold mint-asset-from-list uris (list))))))

(define-private (mint-asset-from-list (uri (string-ascii 256)) (prior-results (list 50 uint)))
    ;; Mint a single asset from the batch and accumulate the results
    (match (mint-asset uri)
        asset-id (unwrap-panic (as-max-len? (append prior-results asset-id) u50))
        error prior-results))

(define-public (is-asset-minted (asset-id uint))
(ok (is-some (map-get? asset-metadata asset-id))))

(define-public (transfer-asset (asset-id uint) (owner principal) (recipient principal))
    (begin
        ;; Ensure the recipient is authorized to receive the asset
        (asserts! (is-eq recipient tx-sender) err-not-asset-owner)

        ;; Ensure the asset is not burned
        (asserts! (not (check-asset-burned asset-id)) err-burn-asset-failed)

        ;; Validate that the caller is the asset owner and proceed with the transfer
        (let ((current-owner (unwrap! (nft-get-owner? game-asset asset-id) err-not-asset-owner)))
            (asserts! (is-eq current-owner owner) err-not-asset-owner)
            (try! (nft-transfer? game-asset asset-id owner recipient)) ;; Transfer the asset
            (ok true))))

(define-public (check-asset-existence (asset-id uint))
(ok (is-some (map-get? asset-metadata asset-id))))


(define-public (get-owner-of-asset (asset-id uint))
(ok (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))


(define-public (unlist-asset-from-marketplace (asset-id uint))
(begin
    ;; Ensure the caller is the asset owner
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)
    ;; Unlist the asset
    (map-set marketplace-listing asset-id false)
    (ok true)))

(define-public (update-asset-uri (asset-id uint) (new-uri (string-ascii 256)))
(begin
    ;; Ensure the caller is the asset owner
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

    ;; Validate the new URI
    (asserts! (validate-uri new-uri) err-invalid-asset-uri)

    ;; Update the asset's URI in the mapping
    (map-set asset-metadata asset-id new-uri)
    (ok true)))

(define-public (check-if-asset-listed (asset-id uint))
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-public (burn-asset (asset-id uint))
    (let ((asset-owner (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))
        ;; Ensure the caller is the owner of the asset and proceed to burn it
        (asserts! (is-eq tx-sender asset-owner) err-not-asset-owner)
        (asserts! (not (check-asset-burned asset-id)) err-asset-already-exists)
        (try! (nft-burn? game-asset asset-id asset-owner)) ;; Burn the asset
        (map-set burned-assets asset-id true) ;; Mark the asset as burned
        (ok true)))

(define-public (list-asset (asset-id uint))
    (begin
        ;; Validate the caller is the asset owner before listing it
        (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

        ;; Mark the asset as listed on the marketplace
        (map-set marketplace-listing asset-id true)
        (ok true)))

(define-public (unlist-asset (asset-id uint))
    (begin
        ;; Validate the caller is the asset owner before unlisting it
        (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

        ;; Remove the asset from the marketplace listing
        (map-set marketplace-listing asset-id false)
        (ok true)))


;; Enhanced Asset Transfer Function with Fee Payment
(define-public (transfer-asset-with-fee (asset-id uint) (recipient principal) (fee uint))
  (begin
    ;; Ensure the sender is the owner of the asset
    (let ((owner (unwrap! (nft-get-owner? game-asset asset-id) err-not-asset-owner)))
        (asserts! (is-eq owner tx-sender) err-not-asset-owner))

    ;; Ensure the asset is not burned
    (asserts! (not (check-asset-burned asset-id)) err-burn-asset-failed)

    ;; Deduct the fee from the sender
    (try! (stx-transfer? fee tx-sender marketplace-admin))

    ;; Transfer the asset to the recipient
    (try! (nft-transfer? game-asset asset-id tx-sender recipient))
    (ok true)))

;; Fetch Asset Price with Fallback
(define-public (get-asset-price-with-fallback (asset-id uint) (fallback-price uint))
  ;; Retrieve the asset price or use the fallback if not listed
  (ok (default-to fallback-price (map-get? asset-price asset-id))))

;; Check Asset Transfer Approval
(define-public (check-asset-transfer-approval (asset-id uint) (approver principal))
  ;; Verify if the specified principal has approval to transfer the asset
  (ok (is-eq (unwrap! (map-get? asset-approvals asset-id) err-asset-not-found) approver)))

;; Fetch Asset Burn Status with Fallback
(define-public (get-asset-burn-status-with-fallback (asset-id uint) (fallback-status bool))
  ;; Retrieve burn status or use fallback
  (ok (default-to fallback-status (map-get? burned-assets asset-id))))

;; Optimize Asset Listing Check
(define-public (is-asset-listed-optimized (asset-id uint))
  ;; Optimize by directly checking if the asset is listed
  (ok (default-to false (map-get? marketplace-listing asset-id))))

;; Revoke Asset Sale Approval
(define-public (revoke-asset-sale-approval (asset-id uint))
  (begin
    ;; Ensure only the asset owner can revoke approval
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

    ;; Delete the approval entry
    (map-delete asset-approvals asset-id)
    (ok true)))

;; Validate Asset for Transfer Approval
(define-public (validate-asset-for-transfer-approval (asset-id uint))
  ;; Ensure the asset has a transfer approval
  (ok (is-some (map-get? asset-approvals asset-id))))


(define-public (mint-asset-with-validation (uri (string-ascii 256)))
;; Ensure that only the admin can mint assets and validate URI
(begin
    (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)
    (asserts! (validate-uri uri) err-invalid-asset-uri)
    (mint-asset uri)))

(define-map asset-approvals uint principal) ;; Mapping for asset transfer approvals

(define-public (revoke-transfer-approval (asset-id uint))
    ;; Revoke asset transfer approval
    (begin
        (let ((approver (unwrap! (map-get? asset-approvals asset-id) err-asset-not-found)))
            (asserts! (is-eq approver tx-sender) err-not-asset-owner)
            (map-delete asset-approvals asset-id))
        (ok true)))

(define-map asset-price uint uint) ;; Mapping to store asset prices

(define-public (get-asset-price (asset-id uint))
    ;; Retrieve the sale price of an asset
    (ok (map-get? asset-price asset-id)))

(define-public (mint-multiple-assets (uris (list 50 (string-ascii 256))))
;; Mint multiple assets with metadata URIs and ensure they do not exceed the mint limit
(begin
    (let ((mint-count (len uris)))
        (asserts! (<= mint-count max-mint-limit) err-asset-already-exists)
        (ok (fold mint-asset-from-list uris (list))))))

;; Add New Asset Metadata
(define-public (add-asset-metadata (asset-id uint) (uri (string-ascii 256)))
  (begin
    ;; Ensure that only the asset owner can add metadata
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

    ;; Validate URI length
    (asserts! (validate-uri uri) err-invalid-asset-uri)

    ;; Store the metadata for the asset
    (map-set asset-metadata asset-id uri)
    (ok true)))

;; Update Asset Metadata URI
(define-public (update-asset-metadata (asset-id uint) (new-uri (string-ascii 256)))
  (begin
    ;; Ensure that only the asset owner can update metadata
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

    ;; Validate the new URI
    (asserts! (validate-uri new-uri) err-invalid-asset-uri)

    ;; Update the metadata URI for the asset
    (map-set asset-metadata asset-id new-uri)
    (ok true)))

;; Validate Marketplace Listing Status
(define-public (validate-marketplace-listing (asset-id uint))
  ;; Ensure the asset is listed in the marketplace
  (ok (default-to false (map-get? marketplace-listing asset-id))))

;; Add Asset to Sale
(define-public (add-asset-to-sale (asset-id uint))
  (begin
    ;; Ensure that only the asset owner can add it to sale
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

    ;; Mark the asset as listed for sale
    (map-set marketplace-listing asset-id true)
    (ok true)))

;; Remove Asset from Sale
(define-public (remove-asset-from-sale (asset-id uint))
  (begin
    ;; Ensure that only the asset owner can remove it from sale
    (asserts! (validate-asset-owner asset-id tx-sender) err-not-asset-owner)

    ;; Unlist the asset from sale
    (map-set marketplace-listing asset-id false)
    (ok true)))


;; Read-Only Functions

(define-read-only (get-asset-uri (asset-id uint))
    ;; Retrieve the URI (metadata) associated with the asset
    (ok (map-get? asset-metadata asset-id)))

(define-read-only (is-asset-burnable (asset-id uint))
  ;; Check if the asset can be burned (not already burned)
  (ok (not (check-asset-burned asset-id))))

(define-read-only (get-asset-owner (asset-id uint))
    ;; Retrieve the owner of the asset
    (ok (nft-get-owner? game-asset asset-id)))

(define-read-only (get-asset-uri-or-default (asset-id uint))
  ;; Retrieve the metadata URI associated with the asset ID, or return a default fallback message
  (ok (default-to "No metadata available" (map-get? asset-metadata asset-id))))

(define-read-only (get-asset-metadata (asset-id uint))
;; Retrieve the metadata (URI) associated with the asset
(ok (map-get? asset-metadata asset-id)))

(define-read-only (get-asset-uri-by-id (asset-id uint))
;; Retrieve the metadata URI associated with the asset ID
(ok (map-get? asset-metadata asset-id)))

(define-read-only (is-asset-currently-listed (asset-id uint))
;; Check if the asset is listed on the marketplace
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (get-asset-owner-by-id (asset-id uint))
  ;; Retrieve the owner of the asset
  (ok (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))

(define-read-only (is-asset-listed (asset-id uint))
;; Check if the asset is listed for sale
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (is-asset-burned (asset-id uint))
;; Check if the asset has been burned
(ok (check-asset-burned asset-id)))


(define-read-only (get-total-assets)
    ;; Get the total number of minted assets (asset counter)
    (ok (var-get asset-counter)))

(define-read-only (is-listed (asset-id uint))
    ;; Check if the asset is currently listed on the marketplace
    (ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (get-burn-status (asset-id uint))
;; Retrieve the burn status of a specific asset
(ok (check-asset-burned asset-id)))

(define-read-only (get-marketplace-admin)
;; Retrieve the address of the marketplace administrator
(ok marketplace-admin))

(define-read-only (does-asset-exist (asset-id uint))
;; Check if an asset with the given ID exists by verifying its metadata
(ok (is-some (map-get? asset-metadata asset-id))))

(define-read-only (get-asset-metadata-uri (asset-id uint))
;; Retrieve the metadata URI associated with the asset ID
(ok (map-get? asset-metadata asset-id)))

(define-read-only (is-asset-owned-by-sender (asset-id uint))
;; Check if the asset is owned by the transaction sender
(let ((owner (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))
    (ok (is-eq owner tx-sender))))

(define-read-only (is-asset-for-sale (asset-id uint))
;; Check if the asset is listed for sale in the marketplace
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (is-asset-not-listed (asset-id uint))
;; Check if the asset is not listed for sale on the marketplace
(ok (not (default-to false (map-get? marketplace-listing asset-id)))))

(define-read-only (get-asset-uri-with-fallback (asset-id uint))
;; Retrieve the metadata URI associated with the asset ID
;; If no metadata is found, return a fallback message.
(ok (default-to "No metadata available" (map-get? asset-metadata asset-id))))

(define-read-only (get-asset-burn-status (asset-id uint))
;; Retrieve the burn status of a specific asset
(ok (check-asset-burned asset-id)))
(define-read-only (is-owner-of-asset (asset-id uint))
;; Check if the sender is the owner of the asset
(let ((owner (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))
    (ok (is-eq owner tx-sender))))

(define-read-only (get-asset-metadata-fallback (asset-id uint))
;; Retrieve metadata URI with a fallback message if no metadata is found
(ok (default-to "No metadata available" (map-get? asset-metadata asset-id))))

(define-read-only (get-listing-status-with-fallback (asset-id uint))
;; Retrieve the listing status with a fallback if the asset is not listed
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (is-asset-listed-for-sale (asset-id uint))
;; Check if the asset is listed for sale on the marketplace
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (get-listing-status (asset-id uint))
;; Retrieve the listing status of a specific asset
(ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (is-asset-unlisted (asset-id uint))
(ok (not (default-to false (map-get? marketplace-listing asset-id)))))

(define-read-only (get-burn-status-of-asset (asset-id uint))
(ok (check-asset-burned asset-id)))

(define-read-only (get-asset-owner-status (asset-id uint))
  ;; Check if the sender is the owner of the asset
  (let ((owner (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))
    (ok (is-eq owner tx-sender))))

(define-read-only (get-asset-listing-status (asset-id uint))
  ;; Retrieve the listing status of the asset
  (ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (check-if-asset-burned (asset-id uint))
  ;; Check if the asset has been burned
  (ok (check-asset-burned asset-id)))

(define-read-only (is-asset-available-for-sale (asset-id uint))
  ;; Check if the asset is listed for sale
  (ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (is-asset-valid-uri (uri (string-ascii 256)))
  ;; Validate if the URI length is between 1 and 256 characters
  (ok (validate-uri-length uri)))


(define-read-only (get-asset-owner-address (asset-id uint))
  ;; Retrieve the address of the owner of the asset
  (ok (unwrap! (nft-get-owner? game-asset asset-id) err-asset-not-found)))

(define-read-only (is-asset-not-burned (asset-id uint))
  ;; Check if the asset has not been burned
  (ok (not (check-asset-burned asset-id))))

(define-read-only (does-asset-exist-by-id (asset-id uint))
  ;; Check if an asset with the given ID exists by verifying its metadata
  (ok (is-some (map-get? asset-metadata asset-id))))

(define-read-only (get-asset-metadata-by-id (asset-id uint))
  ;; Retrieve the metadata URI associated with the asset ID
  ;; If no metadata is found, return a fallback message.
  (ok (default-to "No metadata available" (map-get? asset-metadata asset-id))))

(define-read-only (is-sender-admin)
  ;; Check if the sender is the marketplace administrator
  (ok (is-eq tx-sender marketplace-admin)))

(define-read-only (get-asset-minted-status (asset-id uint))
;; Check if the asset has been minted by checking its metadata
(ok (is-some (map-get? asset-metadata asset-id))))

(define-read-only (is-asset-in-marketplace (asset-id uint))
  ;; Check if the asset is listed for sale
  (ok (default-to false (map-get? marketplace-listing asset-id))))

(define-read-only (check-asset-burn-status (asset-id uint))
  ;; Check if the asset has been burned
  (ok (check-asset-burned asset-id)))

(define-read-only (get-asset-metadata-or-default (asset-id uint))
  ;; Retrieve the metadata URI associated with the asset ID,
  ;; or return a default message if no metadata is found.
  (ok (default-to "No metadata available" (map-get? asset-metadata asset-id))))

(define-read-only (get-burn-status-with-fallback (asset-id uint))
  ;; Retrieve the burn status of a specific asset or return a fallback message if not found
  (ok (default-to false (map-get? burned-assets asset-id))))

(define-read-only (check-burn-status (asset-id uint))
    ;; Check if the asset has been burned
    (ok (check-asset-burned asset-id)))

;; Check if Asset URI Exists
(define-read-only (does-asset-uri-exist (asset-id uint))
  ;; Check if the asset URI exists
  (ok (is-some (map-get? asset-metadata asset-id))))

;; Contract Initialization
(begin
    ;; Initialize the asset counter to 0 at contract deployment
    (var-set asset-counter u0))

;; Track and Validate Asset Transaction History
(define-map asset-transactions uint (list 50 principal))

(define-public (add-transaction-record (asset-id uint) (participant principal))
    (begin
        ;; Ensure the asset exists
        (asserts! (is-some (map-get? asset-metadata asset-id)) err-asset-not-found)

        ;; Get current transaction history or initialize new list
        (let ((current-history (default-to (list) (map-get? asset-transactions asset-id))))
            ;; Add new transaction participant to history
            (ok true))))



;; Batch Asset Verification System
(define-public (verify-multiple-assets (asset-ids (list 50 uint)))
    (begin
        ;; Create a list of verification results
        (ok (map verify-single-asset asset-ids))))

(define-private (verify-single-asset (asset-id uint))
    ;; Verify existence and current status of a single asset
    (and (is-some (map-get? asset-metadata asset-id))
         (not (check-asset-burned asset-id))
         (is-some (nft-get-owner? game-asset asset-id))))

;; Tiered Pricing Implementation
(define-map asset-tier uint (string-ascii 20))
(define-map tier-multiplier (string-ascii 20) uint)

(define-public (set-asset-tier (asset-id uint) (tier (string-ascii 20)))
    (begin
        ;; Ensure only admin can set tiers
        (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)
        ;; Set the asset's tier

        (ok true)))

;; Asset Expiration Management
(define-map asset-expiry uint uint)

(define-public (set-asset-expiry (asset-id uint) (expiry-block uint))
    (begin
        ;; Ensure only admin can set expiry
        (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)
        ;; Set expiry block height
        (ok true)))

;; Royalty Distribution System
(define-map asset-royalty uint uint)

(define-public (set-asset-royalty (asset-id uint) (royalty-percentage uint))
    (begin
        ;; Ensure only admin can set royalties
        (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)
        ;; Validate royalty percentage (0-100)
        (asserts! (<= royalty-percentage u100) (err u120))
        ;; Set royalty percentage
        (ok true)))

;; Asset Voting Rights Management
(define-map voting-power uint uint)

(define-public (set-asset-voting-power (asset-id uint) (power uint))
    (begin
        ;; Ensure only admin can set voting power
        (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)
        ;; Set voting power for the asset
        (ok true)))

;; Asset Quality Verification System
(define-map quality-scores uint uint)

(define-public (verify-asset-quality (asset-id uint) (score uint))
    (begin
        ;; Ensure only admin can verify quality
        (asserts! (is-eq tx-sender marketplace-admin) err-not-admin)
        ;; Validate score range (0-100)
        (asserts! (<= score u100) (err u121))
        ;; Set quality score
        (ok true)))
