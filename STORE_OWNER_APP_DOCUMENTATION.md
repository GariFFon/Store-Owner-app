# Store Owner App Documentation

## Overview
This is a comprehensive Point of Sale (POS) application for store owners to manage their products and sales. The app features a modern UI with categories on the left sidebar and products displayed in a grid layout.

## Features

### 1. **Store Selection**
- When the app opens, store owners see a list of all stores they own
- Owners can select a store to manage
- The selected store is cached, so they don't need to select it again on subsequent app launches
- If only one store exists, it's automatically selected

### 2. **Category Navigation**
- Categories are displayed in a vertical sidebar on the left
- Each category shows:
  - Category icon (if available)
  - Category name
- Clicking a category loads all products in that category
- Selected category is highlighted with a different background color

### 3. **Product Display**
- Products are displayed in a responsive grid layout
- Each product card shows:
  - Product image
  - Product name
  - Product price
- Clicking on a product shows detailed information in a dialog

### 4. **Search Functionality**

#### Text Search
- Search bar at the top allows searching products by name
- Real-time search with 500ms debouncing to prevent excessive API calls
- Clear button (X) to reset search

#### Voice Search
- Click the microphone icon to activate voice search
- Speak the product name
- The app uses Speech-to-Text to convert voice to text
- Automatically searches for the spoken product name
- Microphone icon turns red while listening

#### QR Code Scanner
- Click the QR scanner icon to open the camera
- Scan product barcodes or QR codes
- Automatically searches for the product by scanned code
- Returns to main screen after successful scan

## Screen Structure

```
┌─────────────────────────────────────────────┐
│  Header (Store Name + POS Title)            │
│  [Logout Button]                             │
├─────────────────────────────────────────────┤
│  [QR] [Search Bar............] [Mic]        │
├──────┬──────────────────────────────────────┤
│ Cat1 │  ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│ Cat2 │  │Prod│ │Prod│ │Prod│ │Prod│        │
│ Cat3 │  └────┘ └────┘ └────┘ └────┘        │
│ Cat4 │  ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│ Cat5 │  │Prod│ │Prod│ │Prod│ │Prod│        │
│      │  └────┘ └────┘ └────┘ └────┘        │
└──────┴──────────────────────────────────────┘
```

## API Endpoints

### 1. Get Linked Product Categories
**Endpoint:** `POST /get-linked-product-categories/`

**Request Payload:**
```json
{
  "store_id": "d95069ca-839d-4469-8037-a5796633deb1"
}
```

**Response (Success):**
```json
{
  "status": 200,
  "response": [
    {
      "id": "658a4c43-b149-4c52-9da5-5c69e61aa0df",
      "category_name": "indian",
      "category_icon": "https://exanor-production-media.s3.ap-south-1.amazonaws.com/...",
      "is_enabled": true,
      "is_approved": true,
      "parent_of": null
    }
  ]
}
```

### 2. Get Products by Category
**Endpoint:** `POST /get-products-by-category/`

**Request Payload:**
```json
{
  "store_id": "d95069ca-839d-4469-8037-a5796633deb1",
  "category_id": "658a4c43-b149-4c52-9da5-5c69e61aa0df"
}
```

### 3. Search Products
**Endpoint:** `POST /search-products/`

**Request Payload:**
```json
{
  "store_id": "d95069ca-839d-4469-8037-a5796633deb1",
  "query": "search term"
}
```

### 4. Search Product by Code (QR/Barcode)
**Endpoint:** `POST /search-product-by-code/`

**Request Payload:**
```json
{
  "store_id": "d95069ca-839d-4469-8037-a5796633deb1",
  "code": "scanned_code_here"
}
```

### 5. Get Owner's Stores
**Endpoint:** `GET /get-owner-stores/`

**Note:** This endpoint needs to be implemented on the backend to return all stores owned by the authenticated user.

## File Structure

```
lib/
├── screens/
│   ├── store_selection_screen.dart      # Initial screen to select store
│   └── store_owner_pos_screen.dart      # Main POS screen
├── services/
│   └── store_owner_api_service.dart     # API service for store operations
└── models/
    └── category_model.dart              # Category data model
```

## Usage Flow

1. **App Launch**
   - App checks if a store is already selected (in SharedPreferences)
   - If yes: Navigate directly to POS screen
   - If no: Show store selection screen

2. **Store Selection**
   - Fetch all stores owned by the user
   - Display stores in a list
   - User selects a store
   - Store selection is saved to SharedPreferences
   - Navigate to POS screen

3. **POS Screen**
   - Fetch categories for the selected store
   - Auto-select first category
   - Fetch and display products for the selected category
   - User can:
     - Click different categories to view their products
     - Search products by text
     - Search products by voice
     - Scan QR codes to find products
     - Click products to view details

4. **Logout/Change Store**
   - Click logout button in header
   - Clears selected store from cache
   - Returns to store selection screen

## Dependencies Used

- `shared_preferences` - For caching selected store
- `mobile_scanner` - For QR code scanning
- `speech_to_text` - For voice search
- `cached_network_image` - For efficient image loading
- `http` - For API calls

## Customization

### Changing Grid Layout
In `store_owner_pos_screen.dart`, modify the `GridView.builder`:
```dart
gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 200,  // Change max width of cards
  childAspectRatio: 0.75,   // Change height/width ratio
  crossAxisSpacing: 16,      // Change horizontal spacing
  mainAxisSpacing: 16,       // Change vertical spacing
),
```

### Changing Sidebar Width
In `_buildCategoriesSidebar` method:
```dart
final sidebarWidth = isLandscape ? 100.0 : 80.0;  // Adjust these values
```

### Changing Search Debounce Time
In `_onSearchChanged` method:
```dart
_searchDebounce = Timer(const Duration(milliseconds: 500), () {  // Change delay
  _searchProducts(value);
});
```

## Backend Requirements

The backend needs to implement the following endpoints:

1. `/get-owner-stores/` - Returns all stores owned by authenticated user
2. `/get-linked-product-categories/` - Returns categories for a store (✓ Already implemented)
3. `/get-products-by-category/` - Returns products in a category
4. `/search-products/` - Returns products matching search query
5. `/search-product-by-code/` - Returns product matching barcode/QR code

Expected response format for all endpoints:
```json
{
  "status": 200,
  "response": [/* array of items */]
}
```

## Permissions Required

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice search</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app needs speech recognition for voice search</string>
```

## Error Handling

The app includes comprehensive error handling for:
- Network failures
- Empty responses
- Invalid data
- Permission denials
- API errors

Error messages are displayed in user-friendly formats with retry options.

## Future Enhancements

Potential features to add:
1. Cart functionality for creating orders
2. Product inventory management
3. Sales analytics dashboard
4. Customer management
5. Order history
6. Print receipt functionality
7. Offline mode with data sync
8. Multi-language support
9. Dark mode toggle
10. Customizable product grid/list view
