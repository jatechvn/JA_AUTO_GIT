# Window Theming and Customization Guide (Windows 10 & 11 Split Architecture)

This document describes how the window titlebar theme, transparency/blur effects (Aero Blur for Win10 & Acrylic for Win11), and Windows version-specific rendering adaptations are implemented in the application runner (C++) and theme manager (Dart).

---

## 1. Dynamic Platform Detection

Windows 11 supports native rounded corners and fluid design languages, whereas Windows 10 relies on sharp rectangular frames. Trying to clip a transparent window with rounded corners on Windows 10 causes black corner rendering artifacts.

To solve this, the application dynamically detects whether it is running on Windows 11 or an older version (Windows 10) in both the Dart and C++ layers.

### Dart Detection Logic (`lib/modules/app_config.dart`)
Windows 11 build numbers start at `22000`. The app reads `Platform.operatingSystemVersion` and parses the build number:
```dart
static bool _isWindows11OrNewer() {
  if (!Platform.isWindows) return false;
  try {
    final versionStr = Platform.operatingSystemVersion;
    final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
    if (match != null) {
      final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
      return buildNumber >= 22000;
    }
  } catch (_) {}
  return false;
}

static bool get isWindows11 => _isWindows11OrNewer();
```

---

## 2. C++ Runner Architecture (Windows Theming Modules)

To prevent code pollution and build conflicts, the native theme drawing logic is split into isolated physical files under `windows/runner/`:

```text
windows/runner/
├── theme_win10.h / theme_win10.cpp   # Windows 10 composition blur (Aero Blur)
├── theme_win11.h / theme_win11.cpp   # Windows 11 native Acrylic title bar
└── win32_window.h / win32_window.cpp # Version check dispatcher & title text controller
```

### 1. Windows 11 Theming (`windows/runner/theme_win11.cpp`)
Windows 11 uses the official DWM attributes to set the native system backdrop to transparent Acrylic without drawing blocking solid backgrounds over caption buttons:
```cpp
void ApplyThemeWin11(HWND hwnd, bool is_dark, bool is_startup) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  if (is_startup) {
    // Set backdrop type to DWMSBT_TRANSIENTWINDOW (Acrylic = 3)
    int backdrop_type = 3;
    DwmSetWindowAttribute(hwnd, 38, &backdrop_type, sizeof(backdrop_type));

    // Extend frame into client area
    MARGINS margins = { -1, -1, -1, -1 };
    DwmExtendFrameIntoClientArea(hwnd, &margins);
  }
}
```

### 2. Windows 10 Theming (`windows/runner/theme_win10.cpp`)
Windows 10 uses the undocumented `SetWindowCompositionAttribute` API from `user32.dll`. To maintain performance and visual excellence, the implementation applies three critical optimizations:
- **Aero Blur (`ACCENT_ENABLE_BLURBEHIND` = 3)**: Classic Aero blur is used instead of Acrylic. Aero Blur is fully hardware-accelerated, ensuring **100% lag-free dragging, movement, and resizing** of desktop windows.
- **Zero-Alpha Guard**: Acrylic/Blur composition fails (renders solid black) if the alpha channel is exactly `0`. We force alpha to `1` as a safety check.
- **Optimized Frame Extension margins `{0, 0, 1, 0}`**: Extending margins completely (`-1`) instructs DWM to draw duplicate window borders inside the client area. We extend only the top by `1px` to authorize transparent backdrop composition without rendering duplicate borders.

```cpp
void ApplyThemeWin10(HWND hwnd, bool is_dark) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 19, &enable_dark_mode, sizeof(enable_dark_mode));
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  HMODULE hUser = GetModuleHandleA("user32.dll");
  if (hUser) {
    pSetWindowCompositionAttribute setWindowCompAttr = 
        (pSetWindowCompositionAttribute)GetProcAddress(hUser, "SetWindowCompositionAttribute");
    if (setWindowCompAttr) {
      int alpha = 0x66; // ~40% opacity
      if (alpha == 0) alpha = 1; // Zero-alpha guard
      
      int r = is_dark ? 0x1B : 0xF3;
      int g = is_dark ? 0x15 : 0xF4;
      int b = is_dark ? 0x14 : 0xF6;
      int tint_color = (alpha << 24) | (b << 16) | (g << 8) | r; // ABGR format
      
      ACCENT_POLICY policy = { ACCENT_ENABLE_BLURBEHIND, 2, tint_color, 0 };
      WINDOWCOMPOSITIONATTRIBDATA data = { 19, &policy, sizeof(policy) };
      setWindowCompAttr(hwnd, &data);
    }
  }

  // Authorize composition with a 1px top margin to prevent duplicate border rendering
  MARGINS margins = { 0, 0, 1, 0 };
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  // Resize window 1px and back to force immediate non-client area recalculation
  RECT rect;
  GetWindowRect(hwnd, &rect);
  SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left) - 1, (rect.bottom - rect.top), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left), (rect.bottom - rect.top), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  SendMessage(hwnd, WM_NCACTIVATE, FALSE, 0);
  SendMessage(hwnd, WM_NCACTIVATE, TRUE, 0);
}
```

### 3. Dispatcher & Window Title Bounding Box Fix (`windows/runner/win32_window.cpp`)
- **The Issue**: GDI text rendering on transparent windows draws a fallback solid white/black box around the title text.
- **The Fix**: During window creation, if the OS is Windows 10, we pass an empty string `L""` as the window title. This completely hides the title bar text and removes the visual box. The taskbar entry remains identifiable because it automatically falls back to the executable name (`ja_route`).

```cpp
HWND window = CreateWindow(
    window_class, 
    IsWindows11OrGreater() ? title.c_str() : L"", // Hide text on Win10 to avoid GDI bounding box
    WS_OVERLAPPEDWINDOW,
    Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
    Scale(size.width, scale_factor), Scale(size.height, scale_factor),
    nullptr, nullptr, GetModuleHandle(nullptr), this);
```

---

## 3. Dart Styling Architecture (Split Modules)

To allow the native Windows backdrop blur to shine through, the Dart layer splits styling into OS-specific theme modules:

```text
lib/modules/ui/
├── styles.dart        # Platform coordinator / dispatcher
├── styles_win10.dart  # Translucent theme colors tailored for Windows 10
└── styles_win11.dart  # Transparent theme colors tailored for Windows 11
```

### 1. The Coordinator (`styles.dart`)
Dynamically resolves the correct styling configuration based on `isWindows11`:
```dart
void init() {
  if (Platform.isWindows && !AppConfig.isWindows11) {
    // Apply Windows 10 specific styles
    scaffoldBackgroundColor = StylesWin10.scaffoldBackgroundColor;
    cardBackground = StylesWin10.cardBackground;
    sidebarBackground = StylesWin10.sidebarBackground;
  } else {
    // Windows 11 & other platforms
    scaffoldBackgroundColor = StylesWin11.scaffoldBackgroundColor;
    cardBackground = StylesWin11.cardBackground;
    sidebarBackground = StylesWin11.sidebarBackground;
  }
}
```

### 2. Windows 10 Specific Styles (`styles_win10.dart`)
Ensures readability and high contrast over the Aero blur background by applying translucency:
- `scaffoldBackgroundColor` is set to `Colors.transparent`.
- Layout backgrounds are set to `50%` opacity (`0x80` hex alpha).
- Sidebars are set to `70%` opacity (`0xB3` hex alpha).
- Panels/Cards are set to `85%` opacity (`0xD9` hex alpha).

---

## 4. UI Best Practices for Glassmorphic Modal & Diagnostics Apps

To maintain visual excellence, responsiveness, and clean code in future apps, adhere to these structural design rules:

### 1. Glassmorphic Modal Backdrops (Popup Blurring)
When opening popup dialogs (alerts, details, settings, selectors) on top of a translucent or blurred window backdrop, wrap the builder's returned widget with a `BackdropFilter` using a blur intensity of `sigma: 5.0` to prevent visual overlapping and guide focus:
```dart
showDialog(
  context: context,
  builder: (context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
    child: AlertDialog(
      backgroundColor: themeProvider.cardBg,
      title: Text('Dialog Title'),
      content: Text('Dialog Content'),
      // ...
    ),
  ),
);
```

### 2. Multi-Language Quick Toggles (Lightweight i18n)
For desktop apps needing dynamic English, Vietnamese, and Chinese locales, implement a lightweight `LanguageProvider` extending `ChangeNotifier` and store state in `SharedPreferences`.
- Provide an extension on `BuildContext` (`context.tr('key')`) to translate keys inline.
- Place a language globe button (`Icons.language`) in the bottom actions bar that cycles through locales directly upon click for rapid switching.

### 3. Parsing Robustness for Remote Shell Responses
When parsing remote CLI command output (e.g. `nmcli` or `iwconfig` responses) via SSH, the response string might contain leading/trailing whitespaces or newlines (`\n`) caused by delimiters.
- **Rule**: Always run `.trim()` on the raw output string *before* calling check methods like `.startsWith('yes:')` or parsing ESSIDs. Otherwise, the prefix matches will fail and return `N/A`.

### 4. Codebase-Wide Version Syncing
Maintain version parity by syncing the user-facing version identifier with `pubspec.yaml` version tags and a central codebase constant (e.g., `appVersion` in `constants.dart`). Bump version variables together before packaging release binaries.

---

## 5. Applying Transparent Blur and Custom Title Bar (C++ & Dart Integration)

For a fully custom, modern glassmorphic look, follow this checklist to implement transparent blur and build a seamless custom title bar:

### 1. Transparent Native Window Setup (C++)
To prevent the Windows OS from drawing solid opaque colors in the window client area (which blocks transparent blur from showing through):
1. **Disable Background Brush**: Set `window_class.hbrBackground = 0;` when registering the window class in [win32_window.cpp](file:///a:/JA_PROJECT/Project%20_Dart/JA_SSH-PSREMOTE_Monitor/windows/runner/win32_window.cpp#L128). This prevents background repaints from filling the window with solid colors.
2. **Hide Title Text Bounding Box (Windows 10)**: Pass an empty string `L""` to `CreateWindow` on Windows 10. GDI text rendering on transparent windows draws solid colored bounding boxes behind the text. Setting title text to empty prevents this, while the taskbar remains labeled via the executable name.

### 2. Native Composition Blur APIs (C++)
- **Windows 11 (Acrylic)**: Invoke `DwmSetWindowAttribute` with the attribute code `38` (`DWMWA_SYSTEMBACKDROP_TYPE`) set to `3` (`DWMSBT_TRANSIENTWINDOW`) to activate official Acrylic blurring. Extend client frames completely using `DwmExtendFrameIntoClientArea` with margins `{-1, -1, -1, -1}`.
- **Windows 10 (Aero Blur)**: Load `user32.dll` dynamically and locate `SetWindowCompositionAttribute`. Configure the accent policy to `ACCENT_ENABLE_BLURBEHIND` = 3. 
- **Top Margin Hack**: To prevent duplicate border rendering on Windows 10, extend DWM frames by only 1 pixel at the top (margins `{0, 0, 1, 0}`) instead of `-1`. Send `WM_NCACTIVATE` messages to force non-client frame updates.

### 3. Custom Title Bar Layout in Flutter (Dart)
Since native OS borders are extended or customized, the title bar itself should be drawn in the Dart layer to match the glassmorphic aesthetics:
1. **Top Container**: Place a header container (e.g., `32px` to `40px` high) at the top of the main widget layout.
2. **Drag Region**: You can utilize packages like `bitsdojo_window` to make this region draggable, or configure standard Win32 message handlers (`WM_NCHITTEST`) to return `HTCAPTION` when mouse events occur over the custom title bar area.
3. **Caption Controls**: Render custom minimize, maximize, and close buttons on the top right. Match their hover and click state styling with the application's glassmorphic theme.

### 4. Dynamic Theme Syncing (MethodChannel)
When the user toggles light/dark modes in Dart:
1. Invoke the method `updateTheme` via `MethodChannel("ja_route/theme")`.
2. The C++ listener in [flutter_window.cpp](file:///a:/JA_PROJECT/Project%20_Dart/JA_SSH-PSREMOTE_Monitor/windows/runner/flutter_window.cpp#L69) extracts the boolean `isDark`.
3. Calls the correct theme module (`ApplyThemeWin11` or `ApplyThemeWin10`) to update window tint colors in real-time.

