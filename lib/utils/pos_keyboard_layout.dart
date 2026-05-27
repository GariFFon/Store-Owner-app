import 'package:flutter/material.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';

/// Action key name constants (matching the package's internal ActionKeyType).
/// We inline them here to avoid importing from `package:…/src/…` which is
/// considered a private API.
abstract class _AK {
  static const backspace = 'backspace';
  static const tab = 'tab';
  static const capslock = 'capslock';
  static const enter = 'enter';
  static const shift = 'shift';
}

/// A POS-optimised keyboard layout with two modes:
///
/// * **`default`** — Full QWERTY (desktop-style), for general text entry.
/// * **`numeric`** — Compact number pad (0-9, decimal, backspace, enter),
///   for quantity / phone / price inputs.
///
/// The wrapper widget [OnscreenKeyboardAwareField] automatically selects the
/// right mode based on the field's [TextInputType].
class PosKeyboardLayout extends KeyboardLayout {
  const PosKeyboardLayout();

  @override
  double get aspectRatio => 5 / 2;

  @override
  Map<String, KeyboardMode> get modes => {
        'default': KeyboardMode(rows: _qwertyRows),
        'numeric': KeyboardMode(rows: _numericRows),
      };

  // ─── QWERTY (same as DesktopKeyboardLayout) ────────────────────────────

  List<KeyboardRow> get _qwertyRows => [
        const KeyboardRow(
          keys: [
            OnscreenKeyboardKey.text(primary: '`', secondary: '~'),
            OnscreenKeyboardKey.text(primary: '1', secondary: '!'),
            OnscreenKeyboardKey.text(primary: '2', secondary: '@'),
            OnscreenKeyboardKey.text(primary: '3', secondary: '#'),
            OnscreenKeyboardKey.text(primary: '4', secondary: r'$'),
            OnscreenKeyboardKey.text(primary: '5', secondary: '%'),
            OnscreenKeyboardKey.text(primary: '6', secondary: '^'),
            OnscreenKeyboardKey.text(primary: '7', secondary: '&'),
            OnscreenKeyboardKey.text(primary: '8', secondary: '*'),
            OnscreenKeyboardKey.text(primary: '9', secondary: '('),
            OnscreenKeyboardKey.text(primary: '0', secondary: ')'),
            OnscreenKeyboardKey.text(primary: '-', secondary: '_'),
            OnscreenKeyboardKey.text(primary: '=', secondary: '+'),
            OnscreenKeyboardKey.action(
              name: _AK.backspace,
              child: Icon(Icons.backspace_outlined),
              flex: 25,
            ),
          ],
        ),
        KeyboardRow(
          keys: [
            const OnscreenKeyboardKey.action(
              name: _AK.tab,
              child: Icon(Icons.keyboard_tab_rounded),
              flex: 25,
            ),
            for (final c in [
              'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'
            ])
              OnscreenKeyboardKey.text(primary: c),
            const OnscreenKeyboardKey.text(primary: '[', secondary: '{'),
            const OnscreenKeyboardKey.text(primary: ']', secondary: '}'),
            const OnscreenKeyboardKey.text(primary: r'\', secondary: '|'),
          ],
        ),
        KeyboardRow(
          keys: [
            const OnscreenKeyboardKey.action(
              name: _AK.capslock,
              child: Icon(Icons.keyboard_capslock_rounded),
              flex: 30,
              canHold: true,
            ),
            for (final c in ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'])
              OnscreenKeyboardKey.text(primary: c),
            const OnscreenKeyboardKey.text(primary: ';', secondary: ':'),
            const OnscreenKeyboardKey.text(primary: "'", secondary: '"'),
            const OnscreenKeyboardKey.action(
              name: _AK.enter,
              child: Icon(Icons.keyboard_return_rounded),
              flex: 30,
            ),
          ],
        ),
        KeyboardRow(
          keys: [
            const OnscreenKeyboardKey.action(
              name: _AK.shift,
              child: Icon(Icons.arrow_upward_rounded),
              flex: 35,
            ),
            for (final c in ['z', 'x', 'c', 'v', 'b', 'n', 'm'])
              OnscreenKeyboardKey.text(primary: c),
            const OnscreenKeyboardKey.text(primary: ',', secondary: '<'),
            const OnscreenKeyboardKey.text(primary: '.', secondary: '>'),
            const OnscreenKeyboardKey.text(primary: '/', secondary: '?'),
            const OnscreenKeyboardKey.action(
              name: _AK.shift,
              child: Icon(Icons.arrow_upward_rounded),
              flex: 35,
            ),
          ],
        ),
        KeyboardRow(
          keys: [
            // Mode switch — jump to numeric
            OnscreenKeyboardKey.action(
              name: 'mode_switch',
              child: const Text(
                '123',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onTap: (ctx) =>
                  OnscreenKeyboard.of(ctx).setModeNamed('numeric'),
              flex: 25,
            ),
            const OnscreenKeyboardKey.text(
              primary: ' ',
              child: Icon(Icons.space_bar_rounded),
            ),
          ],
        ),
      ];

  // ─── Numeric pad ───────────────────────────────────────────────────────

  List<KeyboardRow> get _numericRows => [
        const KeyboardRow(keys: [
          OnscreenKeyboardKey.text(primary: '7'),
          OnscreenKeyboardKey.text(primary: '8'),
          OnscreenKeyboardKey.text(primary: '9'),
        ]),
        const KeyboardRow(keys: [
          OnscreenKeyboardKey.text(primary: '4'),
          OnscreenKeyboardKey.text(primary: '5'),
          OnscreenKeyboardKey.text(primary: '6'),
        ]),
        const KeyboardRow(keys: [
          OnscreenKeyboardKey.text(primary: '1'),
          OnscreenKeyboardKey.text(primary: '2'),
          OnscreenKeyboardKey.text(primary: '3'),
        ]),
        KeyboardRow(keys: [
          const OnscreenKeyboardKey.text(primary: '.'),
          const OnscreenKeyboardKey.text(primary: '0', flex: 20),
          const OnscreenKeyboardKey.action(
            name: _AK.backspace,
            child: Icon(Icons.backspace_outlined),
          ),
        ]),
        KeyboardRow(keys: [
          // Mode switch — jump back to QWERTY
          OnscreenKeyboardKey.action(
            name: 'mode_switch',
            child: const Text(
              'ABC',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onTap: (ctx) =>
                OnscreenKeyboard.of(ctx).setModeNamed('default'),
            flex: 25,
          ),
          const OnscreenKeyboardKey.text(primary: '+'),
          const OnscreenKeyboardKey.text(primary: '-'),
          const OnscreenKeyboardKey.action(
            name: _AK.enter,
            child: Icon(Icons.keyboard_return_rounded),
            flex: 25,
          ),
        ]),
      ];
}
