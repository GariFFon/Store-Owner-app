import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/utils/platform_helper.dart';

/// Controller that enables the dashboard to trigger actions on child screens
/// (e.g., POS search, refresh) via keyboard shortcuts.
class DesktopActionController {
  VoidCallback? focusSearch;
  VoidCallback? refreshProducts;
  VoidCallback? restoreFocus;
}

/// Desktop keyboard shortcuts for the store app.
/// Only active on desktop platforms (Windows, macOS, Linux).
///
/// Shortcut Reference:
///   Ctrl+S  → Focus search bar
///   Ctrl+F  → Focus search bar (alias)
///   Ctrl+O  → Show recent orders carousel
///   Ctrl+P  → Print last receipt
///   Ctrl+1  → Switch to POS tab
///   Ctrl+2  → Switch to Orders tab
///   Ctrl+3  → Switch to Purchases tab
///   Ctrl+4  → Switch to Receipts tab
///   Ctrl+5  → Open AI Assistant
///   Ctrl+R  → Refresh current view
///   Ctrl+N  → New order / Add product
///   Ctrl+M  → Open sidebar menu
///   Ctrl+,  → Open settings
///   Escape  → Close dialog / Go back
///   F5      → Refresh current view
///   F11     → Toggle fullscreen (future)

/// Callback signatures for shortcut actions
class ShortcutCallbacks {
  final VoidCallback? onSearch;
  final VoidCallback? onPrint;
  final VoidCallback? onRefresh;
  final VoidCallback? onNewOrder;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onSettings;
  final VoidCallback? onGoBack;
  final void Function(int tabIndex)? onSwitchTab;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onEscape;
  final VoidCallback? onShowOrdersCarousel;

  const ShortcutCallbacks({
    this.onSearch,
    this.onPrint,
    this.onRefresh,
    this.onNewOrder,
    this.onOpenMenu,
    this.onSettings,
    this.onGoBack,
    this.onSwitchTab,
    this.onOpenAssistant,
    this.onEscape,
    this.onShowOrdersCarousel,
  });
}

/// Widget that wraps its child with desktop keyboard shortcuts.
/// On mobile, it passes through without any shortcut handling.
class DesktopShortcutWrapper extends StatelessWidget {
  final Widget child;
  final ShortcutCallbacks callbacks;
  final FocusNode? focusNode;

  const DesktopShortcutWrapper({
    super.key,
    required this.child,
    required this.callbacks,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // Skip shortcuts on mobile
    if (!PlatformHelper.isDesktop) {
      return child;
    }

    return CallbackShortcuts(
      bindings: _buildBindings(),
      child: Focus(autofocus: true, focusNode: focusNode, child: child),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildBindings() {
    final Map<ShortcutActivator, VoidCallback> bindings = {};

    // Ctrl+S → Search
    if (callbacks.onSearch != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyS, control: true)] =
          callbacks.onSearch!;
    }

    // Ctrl+F → Search (alias)
    if (callbacks.onSearch != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyF, control: true)] =
          callbacks.onSearch!;
    }

    // Ctrl+O → Show Orders Carousel
    if (callbacks.onShowOrdersCarousel != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyO, control: true)] =
          callbacks.onShowOrdersCarousel!;
    }

    // Ctrl+P → Print
    if (callbacks.onPrint != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyP, control: true)] =
          callbacks.onPrint!;
    }

    // Ctrl+R → Refresh
    if (callbacks.onRefresh != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyR, control: true)] =
          callbacks.onRefresh!;
    }

    // F5 → Refresh (alias)
    if (callbacks.onRefresh != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.f5)] =
          callbacks.onRefresh!;
    }

    // Ctrl+N → New order
    if (callbacks.onNewOrder != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyN, control: true)] =
          callbacks.onNewOrder!;
    }

    // Ctrl+M → Open menu/drawer
    if (callbacks.onOpenMenu != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyM, control: true)] =
          callbacks.onOpenMenu!;
    }

    // Ctrl+, → Settings
    if (callbacks.onSettings != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.comma, control: true)] =
          callbacks.onSettings!;
    }

    // Escape → Close/Go back
    if (callbacks.onEscape != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.escape)] =
          callbacks.onEscape!;
    }

    // Tab switching: Ctrl+1 through Ctrl+5
    if (callbacks.onSwitchTab != null) {
      bindings[const SingleActivator(
        LogicalKeyboardKey.digit1,
        control: true,
      )] = () =>
          callbacks.onSwitchTab!(0);
      bindings[const SingleActivator(
        LogicalKeyboardKey.digit2,
        control: true,
      )] = () =>
          callbacks.onSwitchTab!(1);
      bindings[const SingleActivator(
        LogicalKeyboardKey.digit3,
        control: true,
      )] = () =>
          callbacks.onSwitchTab!(2);
      bindings[const SingleActivator(
        LogicalKeyboardKey.digit4,
        control: true,
      )] = () =>
          callbacks.onSwitchTab!(3);
    }

    // Ctrl+5 → Open Assistant
    if (callbacks.onOpenAssistant != null) {
      bindings[const SingleActivator(
            LogicalKeyboardKey.digit5,
            control: true,
          )] =
          callbacks.onOpenAssistant!;
    }

    return bindings;
  }
}

/// A helper widget that shows a tooltip with the keyboard shortcut hint.
/// Use this to annotate buttons and icons so desktop users know the shortcut.
class ShortcutTooltip extends StatelessWidget {
  final Widget child;
  final String label;
  final String shortcut;

  const ShortcutTooltip({
    super.key,
    required this.child,
    required this.label,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformHelper.isDesktop) {
      return Tooltip(message: label, child: child);
    }

    return Tooltip(message: '$label ($shortcut)', child: child);
  }
}

/// Overlay widget that shows all available shortcuts when triggered.
/// Displayed with Ctrl+/ or F1.
class KeyboardShortcutsOverlay extends StatelessWidget {
  final VoidCallback onClose;

  const KeyboardShortcutsOverlay({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping the card
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.keyboard_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Keyboard Shortcuts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // Shortcut list
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Navigation', isDark),
                          _shortcutRow('Switch to POS', 'Ctrl + 1', isDark),
                          _shortcutRow('Switch to Orders', 'Ctrl + 2', isDark),
                          _shortcutRow(
                            'Switch to Purchases',
                            'Ctrl + 3',
                            isDark,
                          ),
                          _shortcutRow(
                            'Switch to Receipts',
                            'Ctrl + 4',
                            isDark,
                          ),
                          _shortcutRow('Open AI Assistant', 'Ctrl + 5', isDark),
                          _shortcutRow('Open Sidebar Menu', 'Ctrl + M', isDark),
                          const SizedBox(height: 12),
                          _sectionHeader('Actions', isDark),
                          _shortcutRow('Search Products', 'Ctrl + S', isDark),
                          _shortcutRow('Find (alias)', 'Ctrl + F', isDark),
                          _shortcutRow('Show Orders', 'Ctrl + O', isDark),
                          _shortcutRow('Print Receipt', 'Ctrl + P', isDark),
                          _shortcutRow('Refresh', 'Ctrl + R / F5', isDark),
                          _shortcutRow('New Order', 'Ctrl + N', isDark),
                          const SizedBox(height: 12),
                          _sectionHeader('General', isDark),
                          _shortcutRow('Settings', 'Ctrl + ,', isDark),
                          _shortcutRow('Close / Go Back', 'Escape', isDark),
                          _shortcutRow('Show Shortcuts', 'Ctrl + /', isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _shortcutRow(String action, String shortcut, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            action,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
