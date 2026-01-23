# Place Order Implementation

## Summary
Implemented the `/place-order` API endpoint integration in the CartScreen to enable users to place orders with all required parameters.

## Changes Made

### 1. Added `_placeOrder()` Method
**Location:** `lib/screens/cart_screen.dart` (lines 801-904)

This method handles the complete order placement flow:

#### Request Parameters:
- `coupon_code`: Empty string (can be extended for coupon support)
- `lat`: User's current latitude from `_currentLat`
- `lng`: User's current longitude from `_currentLng`
- `order_method_id`: Selected order method from `_selectedOrderMethodId`
- `payment_method_id`: Selected payment method's ID from `_selectedPaymentMethod['id']`
- `store_id`: Store ID passed via widget parameter
- `user_address_id`: Selected address ID from `_currentAddressId`

#### Features:
- **Validation**: Checks that all required fields are present before making the API call
- **Loading State**: Shows loading indicator during the API call
- **Error Handling**: Displays user-friendly error messages via SnackBar
- **Success Handling**: Shows success message and navigates back to the previous screen
- **Debug Logging**: Comprehensive console logging for debugging

### 2. Connected to "Place Order" Button
**Location:** `lib/screens/cart_screen.dart` (line 1602)

Updated the button's `onPressed` callback to call `_placeOrder` when:
- Order is placeable (`_isOrderPlaceable == true`)
- Not currently initializing (`_isInitializingOrder == false`)

## How It Works

1. **User fills cart** with products from the store
2. **Selects order method** (e.g., Delivery, Pickup) via the order method selector in the app bar
3. **Selects payment method** via the payment method selector
4. **Verifies address** is selected (already tracked in `_currentAddressId`)
5. **Order is initialized** via `/order-init/` endpoint (existing functionality)
   - If successful, `_isOrderPlaceable` is set to `true`
6. **User taps "Place Order"** button
7. **`_placeOrder()` executes**:
   - Validates all required parameters
   - Shows loading indicator
   - Makes POST request to `/place-order/`
   - Handles response (success or error)
   - Shows appropriate feedback to user

## Button States

The "Place Order" button has four distinct states:

### 1. **Disabled (Greyscale)**
The button is shown in greyscale and cannot be clicked when:
- Order method is not yet fetched or selected
- Payment method is not yet fetched or selected
- Address is not yet fetched or empty
- Order initialization has failed validation

**Visual Indicators:**
- Background: Grey (`Colors.grey[400]`)
- Text: Light grey/white (`Colors.white70`)
- Message above button: Red text (if error message exists)
- Button is not clickable (`onPressed: null`)

### 2. **Countdown (Active - 5 seconds)**
**NEW:** When the user taps the Place Order button, a 5-second countdown begins:
- Countdown timer displays with circular progress indicator
- Text shows: "Placing order in X s..."
- Progress indicator fills as countdown decreases
- **Red CANCEL button** appears on the right side of the button
- User can tap CANCEL to abort the order placement

**Visual Indicators:**
- Background: Primary theme color
- Progress bar: White circular indicator showing remaining time
- Countdown text: "Placing order in 5 s..." (counting down)
- Cancel button: Red background with white text overlay

**User Actions:**
- **Wait**: Order places automatically after 5 seconds
- **Cancel**: Tap the CANCEL button to abort order placement

### 3. **Loading**
The button shows a loading spinner when:
- Order is being initialized (`_isInitializingOrder == true`)
- Order is being placed (API call in progress)

**Visual Indicators:**
- White circular progress indicator
- Button remains in its current enabled/disabled color state

### 4. **Enabled (Active)**
The button is fully enabled and clickable when:
- All required data is fetched (payment method, order method, address)
- Order initialization validates successfully (status "All OK.")
- Not currently processing
- Not in countdown state

**Visual Indicators:**
- Background: Primary theme color
- Text: White "Place Order"
- Message above button: Green text showing success message
- Button is clickable and calls `_startOrderCountdown()`

## State Variables Used

- `_selectedOrderMethodId`: String? - ID of the selected order method
- `_selectedPaymentMethod`: Map<String, dynamic>? - Selected payment method object
- `_currentAddressId`: String - Currently selected address ID
- `_currentLat`: double - Current latitude
- `_currentLng`: double - Current longitude
- `_isOrderPlaceable`: bool - Whether order can be placed (set by `/order-init/`)
- `_isInitializingOrder`: bool - Loading state for order operations
- `_orderInitMessage`: String - Message to display above the button (success or error)
- **`_isCountingDown`**: bool - **NEW:** Whether countdown timer is active
- **`_countdownSeconds`**: int - **NEW:** Remaining seconds in countdown (15 to 0)
- **`_countdownTimer`**: Timer? - **NEW:** Timer instance for countdown

## Countdown Feature Details

### How It Works

1. **User Taps "Place Order"**
   - Calls `_startOrderCountdown()`
   - Validates all required parameters
   - Sets `_isCountingDown = true`
   - Initializes `_countdownSeconds = 5`

2. **Countdown Begins**
   - `Timer.periodic` runs every 1 second
   - Decrements `_countdownSeconds` each second
   - Updates circular progress indicator (value = remaining/5)
   - Shows text: "Placing order in X s..."

3. **User Can Cancel**
   - Red "CANCEL" button appears on right side
   - Tapping calls `_cancelOrderCountdown()`
   - Stops timer
   - Resets countdown state
   - Returns button to normal "Place Order" state

4. **Timer Reaches Zero**
   - Automatically calls `_placeOrderImmediate()`
   - Resets countdown state
   - Shows loading indicator
   - Makes API call to `/place-order/`
   - Navigates to Order Details screen on success

### Implementation Methods

- **`_startOrderCountdown()`**: Initiates the 15-second countdown timer
- **`_cancelOrderCountdown()`**: Cancels the countdown and resets state
- **`_placeOrderImmediate()`**: Executes the actual order placement API call

## Validation Flow

```
Cart Screen Loads
    ↓
Fetch Order Methods ────────→ _orderMethods loaded
    ↓                         _selectedOrderMethodId set
Fetch Payment Methods ──────→ _paymentMethods loaded
    ↓                         _selectedPaymentMethod set
Load Address Details ───────→ _currentAddressId loaded
    ↓
Call _initializeOrder() ────→ Validates all fields present
    ↓                         Calls /order-init/ API
    ↓
API Response ───────────────→ Sets _isOrderPlaceable
    ↓                         Sets _orderInitMessage
    ↓
Button State Updated ───────→ Enabled if _isOrderPlaceable == true
                              Disabled (greyscale) otherwise
```

## Example Request Body

The `/place-order` API is called with the following JSON structure:

```json
{
  "coupon_code": "",
  "lat": 31.246307822526543,
  "lng": 75.70968554945745,
  "order_method_id": "09f5e7aa-9f1c-408a-9035-98a81ab5d889",
  "payment_method_id": "0fbeb9b7-05a9-4834-80be-4e3ea7c0903d",
  "store_id": "d95069ca-839d-4469-8037-a5796633deb1",
  "user_address_id": "6068c242-8d0f-4513-aaf3-401fafdad596"
}
```

## Future Enhancements

1. **Coupon Support**: Add a coupon input field and pass the coupon code
2. **Order Tracking**: Implement real-time order tracking functionality
3. **Payment Gateway Integration**: If needed, integrate payment gateway before final order placement
4. **Retry Logic**: Add retry mechanism for failed orders
5. **Order History**: Add a complete order history screen accessible from user profile

## New: Order Details Screen

### Overview
After successful order placement, users are automatically redirected to a comprehensive Order Details screen that displays complete order information.

**File:** `lib/screens/order_details_screen.dart`

### Features

#### 1. **Success Banner**
- Prominent green success message
- Order number display
- Check circle icon with gradient background

#### 2. **Order Status Card**
- Current order status with color-coded badge
- Status subtitle/description
- Timestamp of order placement

#### 3. **Order Information Card**
- Store name
- Order method (Delivery, Pickup, Dine In)
- Total items in order

#### 4. **Products List**
- Each product with:
  - Quantity indicator
  - Product name
  - Individual item price
  - Line item total
- Fetched from `/orderdata-products/` API

#### 5. **Billing Address**
- Complete delivery/billing address
- State and pincode
- Location icon indicator

#### 6. **Payment Details**
- Payment method used
- Payment status (PAID/UNPAID)

#### 7. **Price Breakdown**
- Item subtotal
- Tax breakdown (CGST, SGST, IGST, CESS)
- Platform fees/discounts
- Grand total with prominent display

#### 8. **Invoice Download**
- Download button for invoice PDF
- Opens in external browser/PDF viewer
- Available in both app bar and bottom of screen

### API Calls

The screen makes two API calls on load:

#### 1. Get Order Details
**Endpoint:** `POST /orders/`
```json
{
  "page": 1,
  "query": {"id": "order_id_here"},
  "store_id": "store_id_here"
}
```

#### 2. Get Order Products
**Endpoint:** `POST /orderdata-products/`
```json
{
  "order_id": "order_id_here",
  "query": {}
}
```

### Updated Order Flow

```
User Places Order
    ↓
POST /place-order/ ──────→ Returns order data
    ↓
Extract order_id ────────→ From execute_order_data.order_id
    ↓
Navigate to OrderDetailsScreen
    ↓
Fetch Order Details ─────→ POST /orders/
    ↓
Fetch Order Products ────→ POST /orderdata-products/
    ↓
Display Complete Order Info
    ↓
User can download invoice or go back
```

### Response Structure

When an order is placed successfully, the response contains:
- `execute_order_data.order_id`: Used for navigation
- `execute_order_data.invoice_url`: Direct link to invoice PDF
- `execute_order_data.boolean_status`: Success indicator
- Full cart and pricing information

## Testing

To test the complete implementation:

1. Run the app
2. Add items to cart from a store
3. Ensure an address is selected
4. Select an order method (Delivery/Pickup/Dine In)
5. Select a payment method
6. Wait for order initialization to complete
7. Verify button is enabled (not greyscale)
8. Tap "Place Order" button
9. **NEW:** Automatically redirected to Order Details screen
10. Verify all order information is displayed correctly
11. Test invoice download functionality
12. Test pull-to-refresh to reload order data

## Notes

- All parameters are sourced from the existing CartScreen state
- The implementation follows the existing code patterns in the file
- Error handling includes both API errors and validation errors
- Loading states are properly managed to prevent duplicate submissions
- OrderDetailsScreen has shimmer loading states for better UX
- Invoice download uses url_launcher package (already in dependencies)
- Navigation uses pushReplacement to prevent going back to cart after order is placed

