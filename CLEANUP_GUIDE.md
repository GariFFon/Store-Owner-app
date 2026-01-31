# Store Owner App - Cleanup Guide

## ✅ Changes Made for Store Owner App

Since this is now a **store owner-only app** (not a customer app), I've updated the core flow:

### Updated Files:
1. **`SplashScreen.dart`** - Now navigates to `StoreSelectionScreen` instead of `HomeScreen`

## 📋 Optional Files to Remove (Customer-Facing Features)

Since this is a store owner app, you may want to remove these customer-facing files:

### Screens You DON'T Need:
```
lib/screens/
├── HomeScreen.dart                    ❌ Customer home screen
├── store_screen.dart                  ❌ Customer shopping screen
├── global_search_screen.dart          ❌ Customer search
├── qr_scanner_screen.dart             ❌ Customer QR scanner (different from POS)
├── cart_screen.dart                   ❌ Customer cart
├── orders_list_screen.dart            ❌ Customer orders view
├── order_details_screen.dart          ❌ Customer order details
└── saved_addresses_screen.dart        ❌ Customer addresses
```

### Screens You NEED (Store Owner):
```
lib/screens/
├── SplashScreen.dart                  ✅ App startup
├── onboarding_screen.dart             ✅ First-time setup
├── phone_registration_screen.dart     ✅ Login/signup
├── otp_verification_screen.dart       ✅ OTP verification
├── simple_phone_registration_screen.dart  ✅ Alternative login
├── simple_otp_verification_screen.dart    ✅ Alternative OTP
├── store_selection_screen.dart        ✅ NEW - Select store
├── store_owner_pos_screen.dart        ✅ NEW - POS interface
└── location_selection_screen.dart     ✅ Store location (if needed)
```

## 🔧 How to Clean Up (Optional)

### Step 1: Remove Customer Screens (Optional)

If you want to remove customer-facing screens:

```bash
cd /Users/gouravdash/Documents/Xanor\ All/exanor-store-app-new/lib/screens

# Remove customer screens
rm HomeScreen.dart
rm store_screen.dart
rm global_search_screen.dart
rm qr_scanner_screen.dart
rm cart_screen.dart
rm orders_list_screen.dart
rm order_details_screen.dart
rm saved_addresses_screen.dart
```

### Step 2: Update Routes in main.dart

Remove these routes from `lib/main.dart`:
```dart
// REMOVE THESE:
'/home': (context) => const HomeScreen(),
'/location_selection': (context) => const LocationSelectionScreen(),
'/saved_addresses': (context) => const SavedAddressesScreen(),
'/orders': (context) => const OrdersListScreen(),
```

### Step 3: Clean Up Models (Optional)

You might not need some customer-specific models. Check:
```
lib/models/
├── product_model.dart    ✅ KEEP - Used for products
├── store_model.dart      ✅ KEEP - Used for stores
└── category_model.dart   ✅ KEEP - Used for categories
```

## 🚀 Current App Flow (After Updates)

```
App Launch
    ↓
SplashScreen (3 seconds)
    ↓
Check if logged in?
    ├── NO → OnboardingScreen → PhoneRegistration → OTP → StoreSelection
    └── YES → StoreSelectionScreen
                ↓
         Check if store selected?
            ├── NO → Show store list → User selects
            └── YES → StoreOwnerPOSScreen (Main POS interface)
```

## ⚠️ Important Notes

### Keep These Even Though They Seem Customer-Related:

1. **`location_selection_screen.dart`** - Might be useful for setting store location
2. **Product/Store Models** - Needed for data structure

### Don't Remove Yet:

If you're unsure, **DON'T remove anything yet**. Keep all files and just update the navigation flow. You can always remove files later after testing.

## ✅ What's Already Done

1. ✅ Splash screen now navigates to Store Selection
2. ✅ Store selection caches chosen store
3. ✅ POS screen is the main interface
4. ✅ Categories API integrated
5. ✅ QR scanner in POS screen
6. ✅ Voice search in POS screen
7. ✅ Text search in POS screen

## 🎯 Recommended Approach

### Conservative (Recommended):
**Keep all files, just update navigation flow** (already done!)
- Pros: Nothing breaks, easy to revert
- Cons: Extra unused code

### Aggressive (Optional):
**Remove all customer-facing screens**
- Pros: Cleaner codebase
- Cons: Need to be careful with dependencies

## 📝 Summary

**What Changed:**
- ✅ `SplashScreen.dart` now goes to `StoreSelectionScreen` after login
- ✅ Store owner flow is now the default

**What You Can Do (Optional):**
1. Remove customer-facing screens (list above)
2. Clean up routes in `main.dart`
3. Remove unused dependencies

**What You Should Keep:**
- All authentication screens
- Store selection screen
- Store owner POS screen
- API services
- Models

---

**Your app is now a store owner-only POS system! 🎉**
