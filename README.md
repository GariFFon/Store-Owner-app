# Exanor Store App

A comprehensive Point of Sale (POS) application built with Flutter, designed for store owners to manage their products, sales, and store operations efficiently.

## 🚀 Overview

The Exanor Store App provides a modern, responsive interface for store owners. It features a streamlined workflow for selecting stores, navigating product categories, and performing sales operations. The app is optimized for both tablet and mobile usage with a focus on ease of use and speed.

## ✨ Features

*   **Multi-Store Management**:
    *   Seamlessly switch between multiple stores owned by the user.
    *   Automatic caching of the selected store for quick access.
*   **Intuitive POS Interface**:
    *   **Category Navigation**: Vertical sidebar for quick access to product categories.
    *   **Product Grid**: Responsive grid layout displaying product images, names, and prices.
*   **Advanced Search Capabilities**:
    *   **Text Search**: Real-time product search with debouncing.
    *   **Voice Search**: Integrated speech-to-text for hands-free product lookup.
    *   **QR/Barcode Scanner**: Instant product retrieval via camera scanning.
*   **Sales & Order Management**:
    *   Cart functionality for creating orders.
    *   (In Development) Payment processing and receipt generation.
*   **Staff Management**:
    *   Add and manage store staff with specific permissions.
*   **Financial Tools**:
    *   Ledger screen for tracking GST and financial records.
    *   Payouts overview with fiscal year filtering.

## 📚 Documentation

For more detailed information, please refer to the following guides:

*   [Store Owner App Documentation](STORE_OWNER_APP_DOCUMENTATION.md): Comprehensive guide on features and usage.
*   [Quick Start Guide](STORE_OWNER_QUICK_START.md): Get up and running quickly.
*   [Clean Up Guide](CLEANUP_GUIDE.md): Instructions for maintaining code quality.

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/)
*   **Language**: Dart
*   **State Management**: (Implicit/Not explicitly enforced, uses standard Flutter state management)
*   **Key Packages**:
    *   `http`: API communication
    *   `mobile_scanner`: QR code scanning
    *   `speech_to_text`: Voice command integration
    *   `cached_network_image`: Efficient image loading
    *   `shared_preferences`: Local data persistence
    *   `firebase_core` & related packages: Backend integration

## 📱 Screenshots

*(Add screenshots of the specific screens here, e.g., Store Selection, POS Interface, etc.)*

## 🏁 Getting Started

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.8.1 or higher recommended)
*   Dart SDK
*   Android Studio / Xcode (for mobile emulators/simulators)

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/cybroxide-technologies/exanor-store-app-new.git
    cd exanor-store-app-new
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the application**:
    ```bash
    flutter run
    ```

## 📂 Project Structure

```
lib/
├── screens/
│   ├── store_selection_screen.dart      # Initial screen to select store
│   └── store_owner_pos_screen.dart      # Main POS screen
├── services/
│   └── store_owner_api_service.dart     # API service for store operations
├── models/
│   └── category_model.dart              # Category data model
├── main.dart                            # Entry point of the application
└── ...
```

## ⚙️ Configuration

### Permissions

The app requires the following permissions for full functionality:

*   **Camera**: For QR/Barcode scanning.
*   **Microphone**: For voice search commands.
*   **Speech Recognition**: For processing voice inputs.

**Android**: Permissions are handled in `android/app/src/main/AndroidManifest.xml`.
**iOS**: specific keys are added to `ios/Runner/Info.plist`.

## 🤝 Contributing

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## 📄 License

[MIT License](LICENSE) (or appropriate license)
