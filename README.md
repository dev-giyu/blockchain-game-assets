# Gaming Asset Marketplace Smart Contract

## Overview

The `gaming-asset-marketplace.clar` smart contract facilitates the management of gaming assets in a decentralized marketplace. It enables the minting, transferring, listing, unlisting, and burning of gaming assets. The contract supports both single and batch minting, asset ownership management, and validation of asset metadata URIs. Only the marketplace administrator has permission to mint assets, while individual asset owners can transfer, burn, and list/unlist their assets for sale.

## Features

- **Minting**: Admin can mint new gaming assets individually or in batches.
- **Asset Management**: Asset owners can transfer assets, burn assets, and list/unlist assets for sale.
- **Metadata**: Each asset has associated metadata, stored as a URI.
- **Decentralized Ownership**: Asset ownership and marketplace listing status are decentralized and tracked by the contract.
- **Asset Status**: Tracks burn status and whether an asset is listed for sale on the marketplace.

## Contract Functions

### Constants

- `marketplace-admin`: The address of the marketplace administrator.
- `err-not-admin`: Error if the caller is not the admin.
- `err-not-asset-owner`: Error if the caller is not the asset owner.
- `err-asset-already-exists`: Error if the asset already exists.
- `err-asset-not-found`: Error if the asset is not found.
- `err-invalid-asset-uri`: Error if the asset URI is invalid.
- `err-burn-asset-failed`: Error if burning the asset fails.
- `max-mint-limit`: Maximum number of assets that can be minted in a single batch.

### Asset Definitions

- **Non-fungible token (`game-asset`)**: A unique identifier for each gaming asset.
- **Asset Counter**: Tracks the current asset ID counter.

### Mappings

- `asset-metadata`: Maps each asset ID to its metadata URI.
- `burned-assets`: Maps each asset ID to its burn status (true if burned).
- `marketplace-listing`: Maps each asset ID to its marketplace listing status (true if listed).

## Private Helper Functions

- `validate-asset-owner`: Ensures the caller is the owner of the asset.
- `validate-uri`: Validates the asset URI (length between 1 and 256 characters).
- `check-asset-burned`: Checks if the asset has been burned.

### Minting Functions

- **`mint-asset`**: Mints a new asset and assigns a unique ID to it.
- **`mint-single-asset`**: Mints a single asset. Only the admin can mint assets.
- **`batch-mint-assets`**: Mints multiple assets in a batch, ensuring the batch size does not exceed the mint limit.

### Transfer and Burn Functions

- **`transfer-asset`**: Transfers ownership of an asset to another user.
- **`burn-asset`**: Burns an asset, removing it from circulation.

### Listing Functions

- **`list-asset`**: Lists an asset for sale on the marketplace.
- **`unlist-asset`**: Removes an asset from the marketplace listing.

### Read-Only Functions

- **`get-asset-uri`**: Retrieves the URI (metadata) associated with an asset.
- **`get-asset-owner`**: Retrieves the owner of a specific asset.
- **`get-asset-metadata`**: Retrieves the metadata of a specific asset.
- **`is-asset-listed`**: Checks if an asset is currently listed on the marketplace.
- **`get-total-assets`**: Retrieves the total number of minted assets.
- **`get-marketplace-admin`**: Retrieves the address of the marketplace administrator.

## Usage

### Minting Assets

#### Single Asset Minting
Only the marketplace admin can mint new assets. To mint a single asset, provide a URI for the asset's metadata.

```clarity
(mint-single-asset "https://example.com/asset-metadata")
```

#### Batch Minting
The admin can mint up to 50 assets in a single batch. Provide a list of URIs for the assets' metadata.

```clarity
(batch-mint-assets ["https://example.com/asset1" "https://example.com/asset2" ...])
```

### Transferring Assets

Asset owners can transfer assets to other users. To transfer an asset, specify the asset ID, owner, and recipient.

```clarity
(transfer-asset asset-id owner recipient)
```

### Burning Assets

Asset owners can burn their assets, removing them from circulation. Specify the asset ID.

```clarity
(burn-asset asset-id)
```

### Listing Assets

To list an asset for sale on the marketplace, the owner can execute the following command:

```clarity
(list-asset asset-id)
```

To unlist an asset, use:

```clarity
(unlist-asset asset-id)
```

### Retrieving Asset Information

To retrieve various details about an asset, use the following read-only functions:

- Get the URI of an asset:

```clarity
(get-asset-uri asset-id)
```

- Get the owner of an asset:

```clarity
(get-asset-owner asset-id)
```

- Check if an asset is listed on the marketplace:

```clarity
(is-asset-listed asset-id)
```

- Check if an asset has been burned:

```clarity
(is-asset-burned asset-id)
```

- Get the total number of minted assets:

```clarity
(get-total-assets)
```

## Contract Initialization

Upon contract deployment, the asset counter is initialized to `0`, ensuring that asset IDs start from `1` for the first minted asset.

```clarity
(begin
    (var-set asset-counter u0))
```

## Error Handling

The contract includes various error conditions:

- **Not Admin**: Only the marketplace admin can mint assets (`err-not-admin`).
- **Not Asset Owner**: Only the owner can transfer, burn, list, or unlist their assets (`err-not-asset-owner`).
- **Asset Already Exists**: Prevents duplicate assets from being minted (`err-asset-already-exists`).
- **Asset Not Found**: Used when trying to access a non-existent asset (`err-asset-not-found`).
- **Invalid URI**: Ensures the asset URI is valid (`err-invalid-asset-uri`).
- **Burn Failed**: Prevents burning assets that are already burned (`err-burn-asset-failed`).

## Conclusion

This smart contract provides a decentralized solution for managing gaming assets in a marketplace. It allows for minting, listing, transferring, and burning assets, all while ensuring secure ownership and marketplace listing. The contract also provides several read-only functions to query asset information and status.
```