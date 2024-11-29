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
