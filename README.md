# 📱 Device Rental Smart Contract

A Clarity smart contract for renting IoT devices and electronics with time-locked return conditions on the Stacks blockchain.

## 🚀 Features

- 📋 **Device Registration**: Register devices for rent with custom rates and deposits
- 💰 **Secure Rentals**: Rent devices with automatic deposit handling and time locks  
- ⏰ **Time-Based Returns**: Automatic penalty system for late returns
- 🔄 **Rental Extensions**: Extend rental periods with additional payments
- 🏆 **Owner Claims**: Device owners can reclaim overdue devices after grace period

## 🏗️ Contract Structure

### Core Functions

#### 🔐 Owner Functions
- `register-device` - Register a new device for rental

#### 👤 User Functions  
- `rent-device` - Rent an available device with deposit and daily rate
- `return-device` - Return rented device and receive deposit refund
- `extend-rental` - Extend current rental period
- `claim-overdue-device` - Owner can claim overdue devices (7+ days late)

#### 📖 Read-Only Functions
- `get-device` - Get device information
- `get-rental` - Get active rental details
- `get-device-count` - Total registered devices
- `is-device-available` - Check device availability
- `get-rental-status` - Get rental status with time remaining
- `calculate-rental-cost` - Calculate total rental cost

## 💡 Usage Examples

### Register a Device
```clarity
(contract-call? .device-rental register-device "iPhone 14" u1000000 u5000000)
```

### Rent a Device
```clarity
(contract-call? .device-rental rent-device u1 u7)
```

### Return a Device  
```clarity
(contract-call? .device-rental return-device u1)
```

### Check Device Status
```clarity
(contract-call? .device-rental get-rental-status u1)
```

## ⚙️ Configuration

- **Daily Rate**: Set in microSTX (1 STX = 1,000,000 microSTX)
- **Deposit**: Required upfront deposit in microSTX  
- **Block Time**: ~144 blocks per day (10 minute average)
- **Grace Period**: 7 days (1008 blocks) before owner can reclaim
- **Late Penalty**: 50% of deposit for late returns

## 🛡️ Security Features

- Owner-only device registration
- Deposit-based rental system
- Time-locked returns with penalties
- Automatic refund calculations
- Protection against double rentals

## 📋 Error Codes

- `u100` - Owner only operation
- `u101` - Device not found  
- `u102` - Unauthorized access
- `u103` - Device already rented
- `u104` - Device not currently rented
- `u105` - Insufficient payment
- `u106` - Rental period expired
- `u107` - Device already exists

## 🚀 Getting Started

1. Deploy the contract to Stacks blockchain
2. Register devices using `register-device`
3. Users can browse and rent available devices
4. Handle returns and extensions as needed

## 📊 Rental Flow

```
Device Registration → Available for Rent → Rented → Returned/Extended → Available Again
```

Built with ❤️ using Clarity and Clarinet
