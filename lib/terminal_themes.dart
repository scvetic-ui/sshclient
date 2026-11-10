import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

TerminalTheme _make(int bg, int fg, List<int> c) => TerminalTheme(
      cursor: Color(fg),
      selection: Color(fg).withAlpha(90),
      foreground: Color(fg),
      background: Color(bg),
      black: Color(c[0]),
      red: Color(c[1]),
      green: Color(c[2]),
      yellow: Color(c[3]),
      blue: Color(c[4]),
      magenta: Color(c[5]),
      cyan: Color(c[6]),
      white: Color(c[7]),
      brightBlack: Color(c[8]),
      brightRed: Color(c[9]),
      brightGreen: Color(c[10]),
      brightYellow: Color(c[11]),
      brightBlue: Color(c[12]),
      brightMagenta: Color(c[13]),
      brightCyan: Color(c[14]),
      brightWhite: Color(c[15]),
      searchHitBackground: const Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: const Color(0xFF31FF26),
      searchHitForeground: const Color(0xFF000000),
    );

final terminalThemes = <String, TerminalTheme>{
  'Solarized Dark': _make(0xFF07333F, 0xFFE6E8E6, const [
    0xFF073642, 0xFFDC322F, 0xFF859900, 0xFFB58900, 0xFF268BD2, 0xFFD33682, 0xFF2AA198, 0xFFEEE8D5,
    0xFF586E75, 0xFFCB4B16, 0xFF93A800, 0xFFD5A000, 0xFF4BA3E3, 0xFF6C71C4, 0xFF4DC4B8, 0xFFFDF6E3,
  ]),
  'Dark': _make(0xFF000000, 0xFFD0D0D0, const [
    0xFF000000, 0xFFCD3131, 0xFF0DBC79, 0xFFE5E510, 0xFF2472C8, 0xFFBC3FBC, 0xFF11A8CD, 0xFFE5E5E5,
    0xFF666666, 0xFFF14C4C, 0xFF23D18B, 0xFFF5F543, 0xFF3B8EEA, 0xFFD670D6, 0xFF29B8DB, 0xFFFFFFFF,
  ]),
  'Monokai': _make(0xFF272822, 0xFFF8F8F2, const [
    0xFF272822, 0xFFF92672, 0xFFA6E22E, 0xFFF4BF75, 0xFF66D9EF, 0xFFAE81FF, 0xFFA1EFE4, 0xFFF8F8F2,
    0xFF75715E, 0xFFF92672, 0xFFA6E22E, 0xFFF4BF75, 0xFF66D9EF, 0xFFAE81FF, 0xFFA1EFE4, 0xFFF9F8F5,
  ]),
  'Light': _make(0xFFFDFDFD, 0xFF202020, const [
    0xFF000000, 0xFFC91B00, 0xFF00A600, 0xFF999900, 0xFF0225C7, 0xFFCA30C7, 0xFF00A6B2, 0xFFBFBFBF,
    0xFF686868, 0xFFFF6E67, 0xFF00C200, 0xFFB2B200, 0xFF6871FF, 0xFFFF77FF, 0xFF00C5C7, 0xFF7F7F7F,
  ]),
};

TerminalTheme themeByName(String name) =>
    terminalThemes[name] ?? terminalThemes.values.first;
