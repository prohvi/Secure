# SecureMarket - NFT Trading Platform

A decentralized NFT marketplace smart contract built on the Stacks blockchain using Clarity.

## Overview

SecureMarket enables users to create time-bound auction entries for NFT assets, accept offers from bidders, and automatically handle asset and payment transfers upon auction completion.

## Features

- **Create Auction Entries**: Asset owners can list their NFTs with a floor price and duration
- **Submit Offers**: Users can place offers on active entries
- **Automatic Refunds**: Previous top bidders are automatically refunded when outbid
- **Secure Finalization**: Assets and funds are transferred atomically at auction end
- **Time Management**: Built-in clock system for auction expiration tracking

## Key Components

### Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Caller lacks required permissions
- `ERR-ENTRY-NOT-FOUND (u101)`: Entry ID does not exist
- `ERR-ENTRY-INACTIVE (u102)`: Entry is closed or expired
- `ERR-OFFER-TOO-LOW (u103)`: Offer doesn't meet minimum requirements
- `ERR-INVALID-INPUT (u104)`: Input parameters are invalid
- `ERR-ADDRESS-MISMATCH (u105)`: Asset contract address mismatch

### Configuration Variables

- `min-offer-amount`: Minimum offer amount (default: 1,000,000 microSTX)
- `max-entry-period`: Maximum auction duration (30 days in seconds)
- `entry-counter`: Tracks total number of entries created
- `system-clock`: Internal timestamp for auction management

## Public Functions

### `create-entry`

Creates a new auction entry for an NFT asset.

**Parameters:**
- `asset-address`: NFT contract implementing the asset-standard trait
- `asset-id`: Unique identifier of the NFT
- `floor-price`: Minimum acceptable offer
- `period`: Duration of the auction in seconds

**Returns:** Entry ID if successful

**Requirements:**
- Caller must own the NFT
- Floor price must meet minimum threshold
- Period must be within allowed duration

### `submit-offer`

Places an offer on an active entry.

**Parameters:**
- `entry-id`: ID of the auction entry
- `offer-amount`: Amount to offer in microSTX

**Returns:** Success boolean

**Requirements:**
- Entry must be active and not expired
- Offer must exceed floor price and current top offer
- Caller must have sufficient STX balance

### `finalize-entry`

Concludes an expired auction and transfers assets/funds.

**Parameters:**
- `entry-id`: ID of the auction entry
- `asset-address`: NFT contract (must match original entry)

**Returns:** Success boolean

**Requirements:**
- Entry must be expired
- Entry must be active (not already finalized)
- Asset contract must match original listing

### `update-clock`

Updates the internal system clock (admin only).

**Parameters:**
- `new-clock`: New timestamp value

**Returns:** Success boolean

## Read-Only Functions

### `fetch-entry-info`

Retrieves complete information about an entry.

**Parameters:**
- `entry-id`: ID of the entry

**Returns:** Entry data or none

### `fetch-system-clock`

Returns the current system clock value.

**Returns:** Current timestamp

## Data Structures

### Entry Schema

```clarity
{
    owner: principal,              // Original asset owner
    asset-address: principal,      // NFT contract address
    asset-id: uint,               // NFT token ID
    floor-price: uint,            // Minimum acceptable offer
    top-offer: uint,              // Current highest offer
    top-bidder: (optional principal), // Current top bidder
    deadline: uint,               // Expiration timestamp
    status: bool                  // Active/inactive flag
}
```

## Usage Example

```clarity
;; Create an auction entry
(contract-call? .secure-market create-entry 
    .my-nft-contract 
    u42           ;; asset ID
    u5000000      ;; floor price (5 STX)
    u86400        ;; 24 hours
)

;; Submit an offer
(contract-call? .secure-market submit-offer 
    u1            ;; entry ID
    u6000000      ;; offer amount (6 STX)
)

;; Finalize after expiration
(contract-call? .secure-market finalize-entry 
    u1 
    .my-nft-contract
)
```

## Security Considerations

- Assets are held in contract escrow during active auctions
- Automatic refund mechanism prevents fund lockup
- Input validation on all public functions
- Contract address verification prevents asset substitution
- Time-based expiration prevents indefinite listings
