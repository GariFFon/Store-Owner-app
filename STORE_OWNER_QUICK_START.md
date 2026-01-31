# Store Owner App - Quick Start Guide

## 🎯 What Was Created

I've built a comprehensive Point of Sale (POS) system for store owners with the following features:

### ✨ Key Features

1. **Store Selection Screen** (`store_selection_screen.dart`)
   - Lists all stores owned by the user
   - Caches the selected store (one-time selection)
   - Auto-selects if only one store exists

2. **POS Screen** (`store_owner_pos_screen.dart`)
   - **Left Sidebar**: Categories with icons
   - **Main Area**: Product grid
   - **Search Bar**: Text search with real-time debouncing
   - **QR Scanner**: Scan product barcodes
   - **Voice Search**: Speech-to-text product search

3. **API Service** (`store_owner_api_service.dart`)
   - Methods to fetch categories
   - Methods to fetch products by category
   - Product search functionality
   - QR code search

4. **Category Model** (`category_model.dart`)
   - Structured data model for categories

## 🚀 How to Use

### Step 1: Navigate to Store Selection
```dart
Navigator.pushNamed(context, '/store-selection');
```

### Step 2: Backend API Requirements

You need to implement these endpoints on your backend:

#### 1. Get Owner's Stores (New)
```
GET /get-owner-stores/
```
Returns all stores owned by the authenticated user.

**Expected Response:**
```json
{
  "status": 200,
  "response": [
    {
      "id": "store-uuid",
      "name": "Store Name",
      "store_name": "Store Name",
      "address": "123 Main St",
      "type": "Retail"
    }
  ]
}
```

#### 2. Get Categories (Already Provided)
```
POST /get-linked-product-categories/
Body: { "store_id": "uuid" }
```
✅ This endpoint schema is already implemented exactly as you provided.

#### 3. Get Products by Category (New)
```
POST /get-products-by-category/
Body: { "store_id": "uuid", "category_id": "uuid" }
```

**Expected Response:**
```json
{
  "status": 200,
  "response": [
    {
      "id": "product-uuid",
      "name": "Product Name",
      "product_name": "Product Name",
      "price": 99.99,
      "selling_price": 99.99,
      "image": "https://...",
      "product_image": "https://...",
      "description": "Product description"
    }
  ]
}
```

#### 4. Search Products (New)
```
POST /search-products/
Body: { "store_id": "uuid", "query": "search text" }
```
Returns products matching the search query (same format as above).

#### 5. Search by QR Code (New)
```
POST /search-product-by-code/
Body: { "store_id": "uuid", "code": "scanned_code" }
```
Returns a single product matching the scanned code.

## 📱 Permissions Required

### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan product QR codes</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice product search</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>We need speech recognition for voice search</string>
```

## 🎨 UI Layout

```
┌─────────────────────────────────────────────┐
│  [Store Name] - Point of Sale      [Logout] │
├─────────────────────────────────────────────┤
│  [QR] [Search................] [Mic]        │
├────┬────────────────────────────────────────┤
│Dry │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │
│Frt │  │Panch-│ │Whole │ │Mexican│ │AMAYU │ │
│    │  │meva  │ │Farm..│ │Peri..│ │Trail │ │
├────┤  │₹346  │ │₹73   │ │₹34   │ │₹749  │ │
│Snk │  └──────┘ └──────┘ └──────┘ └──────┘ │
│    │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │
├────┤  │...   │ │...   │ │...   │ │...   │ │
│Crl │  └──────┘ └──────┘ └──────┘ └──────┘ │
│    │                                        │
├────┤                                        │
│... │                                        │
└────┴────────────────────────────────────────┘
```

## 🔧 Customization

### Change Grid Columns
In `store_owner_pos_screen.dart`, line ~588:
```dart
gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 200,  // Change to adjust card width
  childAspectRatio: 0.75,   // Change to adjust card height
),
```

### Change Category Sidebar Width
In `_buildCategoriesSidebar` method, line ~428:
```dart
final sidebarWidth = isLandscape ? 100.0 : 80.0;
```

### Change Search Debounce Delay
In `_onSearchChanged` method, line ~221:
```dart
_searchDebounce = Timer(const Duration(milliseconds: 500), () {
  // Change 500 to desired delay in milliseconds
});
```

## 🐛 Troubleshooting

### Issue: Categories not loading
**Solution:** Ensure the `/get-linked-product-categories/` endpoint returns the exact format shown in your example.

### Issue: QR scanner not opening
**Solution:** Check camera permissions in AndroidManifest.xml and Info.plist.

### Issue: Voice search not working
**Solution:** 
1. Check microphone permissions
2. Test on a physical device (may not work on emulator)
3. Ensure internet connection (speech recognition requires network)

### Issue: Store selection not persisting
**Solution:** The app uses SharedPreferences. Ensure it's properly initialized in your app.

## 📁 Files Created

```
lib/
├── screens/
│   ├── store_selection_screen.dart      (310 lines)
│   └── store_owner_pos_screen.dart      (736 lines)
├── services/
│   └── store_owner_api_service.dart     (168 lines)
├── models/
│   └── category_model.dart              (44 lines)
└── main.dart                             (updated with routes)

Documentation:
├── STORE_OWNER_APP_DOCUMENTATION.md     (full documentation)
└── STORE_OWNER_QUICK_START.md          (this file)
```

## 🎯 Next Steps

1. **Implement Backend Endpoints**
   - Start with `/get-owner-stores/`
   - Implement `/get-products-by-category/`
   - Implement `/search-products/`
   - Implement `/search-product-by-code/`

2. **Add Permissions**
   - Update AndroidManifest.xml
   - Update Info.plist

3. **Test the Flow**
   ```dart
   // In your app, navigate to:
   Navigator.pushNamed(context, '/store-selection');
   ```

4. **Optional Enhancements**
   - Add cart functionality
   - Add order creation
   - Add product inventory management
   - Add sales analytics

## 💡 Tips

- The voice search uses `speech_to_text` which requires internet connectivity
- QR scanner uses `mobile_scanner` which is fast and reliable
- Search has 500ms debouncing to avoid excessive API calls
- Categories auto-load when screen opens
- First category is auto-selected
- Product images use cached_network_image for better performance

## 📞 Support

For more detailed information, see `STORE_OWNER_APP_DOCUMENTATION.md`

---

**Created with ❤️ by Antigravity AI**
