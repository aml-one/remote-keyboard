/// USB HID keyboard usage IDs (boot protocol).
class Hid {
  static const leftCtrl = 0x01;
  static const leftShift = 0x02;
  static const leftAlt = 0x04;
  static const leftGui = 0x08;

  static const a = 0x04;
  static const b = 0x05;
  static const c = 0x06;
  static const d = 0x07;
  static const e = 0x08;
  static const f = 0x09;
  static const g = 0x0A;
  static const h = 0x0B;
  static const i = 0x0C;
  static const j = 0x0D;
  static const k = 0x0E;
  static const l = 0x0F;
  static const m = 0x10;
  static const n = 0x11;
  static const o = 0x12;
  static const p = 0x13;
  static const q = 0x14;
  static const r = 0x15;
  static const s = 0x16;
  static const t = 0x17;
  static const u = 0x18;
  static const v = 0x19;
  static const w = 0x1A;
  static const x = 0x1B;
  static const y = 0x1C;
  static const z = 0x1D;
  static const n1 = 0x1E;
  static const n2 = 0x1F;
  static const n3 = 0x20;
  static const n4 = 0x21;
  static const n5 = 0x22;
  static const n6 = 0x23;
  static const n7 = 0x24;
  static const n8 = 0x25;
  static const n9 = 0x26;
  static const n0 = 0x27;
  static const enter = 0x28;
  static const escape = 0x29;
  static const backspace = 0x2A;
  static const tab = 0x2B;
  static const space = 0x2C;
  static const minus = 0x2D;
  static const equals = 0x2E;
  static const lbracket = 0x2F;
  static const rbracket = 0x30;
  static const backslash = 0x31;
  static const semicolon = 0x33;
  static const quote = 0x34;
  static const grave = 0x35;
  static const comma = 0x36;
  static const period = 0x37;
  static const slash = 0x38;
  static const caps = 0x39;
  static const f1 = 0x3A;
  static const delete = 0x4C;
  static const right = 0x4F;
  static const left = 0x50;
  static const down = 0x51;
  static const up = 0x52;

  static int letter(String ch, {bool azerty = false}) {
    final c = ch.toLowerCase();
    if (c.length != 1) return 0;
    if (azerty) return _azertyHid[c] ?? 0;
    final code = c.codeUnitAt(0);
    if (code >= 97 && code <= 122) return a + (code - 97);
    return 0;
  }

  /// French AZERTY Windows maps US HID positions to these letters.
  /// Send the US usage that types [ch] on that layout.
  static const _azertyHid = {
    'a': q,
    'z': w,
    'e': e,
    'r': r,
    't': t,
    'y': y,
    'u': u,
    'i': i,
    'o': o,
    'p': p,
    'q': a,
    's': s,
    'd': d,
    'f': f,
    'g': g,
    'h': h,
    'j': j,
    'k': k,
    'l': l,
    'm': semicolon,
    'w': z,
    'x': x,
    'c': c,
    'v': v,
    'b': b,
    'n': n,
  };
}

class KeySpec {
  const KeySpec(
    this.label, {
    this.hid = 0,
    this.flex = 1,
    this.withShift = false,
    this.hint,
    this.kind = KeyKind.letter,
    this.mod = 0,
    this.sequence,
  });

  final String label;
  final int hid;
  /// Send Left Shift with [hid] (US punctuation such as `@` or `:`).
  final bool withShift;
  final double flex;
  final String? hint;
  final KeyKind kind;
  final int mod;
  final List<int>? sequence;

  bool get isShiftedLetter => kind == KeyKind.letter && label.length == 1;
}

enum KeyKind {
  letter,
  shift,
  backspace,
  delete,
  enter,
  space,
  symbols,
  moreSymbols,
  abc,
  modifier,
  shortcut,
  xd,
}

/// HID reports that type "xD": unshifted x, then Shift+d.
List<({int hid, int modifiers})> xdKeyReports({int modifiers = 0}) {
  final base = modifiers & ~Hid.leftShift;
  return [
    (hid: Hid.x, modifiers: base),
    (hid: Hid.d, modifiers: base | Hid.leftShift),
  ];
}

KeySpec _sym(String label, int hid, {bool shift = false, double flex = 1}) {
  return KeySpec(label, hid: hid, withShift: shift, flex: flex);
}

class KeyPage {
  const KeyPage(this.rows);
  final List<List<KeySpec>> rows;
}

KeyPage lettersPage({
  required bool azerty,
  required bool xd,
  bool hideSymbols = false,
}) {
  List<KeySpec> row(String chars) {
    return [
      for (final ch in chars.split(''))
        KeySpec(ch, hid: Hid.letter(ch, azerty: azerty)),
    ];
  }

  final r1 = azerty ? row('azertyuiop') : row('qwertyuiop');
  final r2 = azerty ? row('qsdfghjklm') : row('asdfghjkl');
  final r3Core = azerty ? row('wxcvbn') : row('zxcvbnm');
  // Leftover columns go to Shift. Letters stay one-key wide; backspace stays
  // two keys on the right. Do not inset this row with side spacers.
  final shiftFlex = 10 - r3Core.length - 2;
  return KeyPage([
    r1,
    r2,
    [
      KeySpec('⇧', flex: shiftFlex.toDouble(), kind: KeyKind.shift),
      ...r3Core,
      const KeySpec(
        '⌫',
        flex: 2,
        hid: Hid.backspace,
        kind: KeyKind.backspace,
      ),
    ],
    _bottomRow(
      leading: hideSymbols ? null : _symbolsKey,
      beforeSpace: azerty
          ? const KeySpec(',', hid: Hid.m)
          : const KeySpec(',', hid: Hid.comma),
      xd: xd,
      afterXd: azerty
          ? const KeySpec('.', hid: Hid.comma, withShift: true)
          : const KeySpec('.', hid: Hid.period),
    ),
  ]);
}

/// QWERTY home row is 9 keys. Split the leftover 10th column so `asdfghjkl`
/// sits centered under `qwertyuiop`. AZERTY `qsdfghjklm` is already 10 keys.
({int lead, int trail})? qwertyHomeRowGutters(List<KeySpec> row) {
  if (row.map((k) => k.label).join() != 'asdfghjkl') return null;
  var used = 0;
  for (final key in row) {
    used += (key.flex * 10).round().clamp(1, 80);
  }
  const tenKeys = 100;
  final unused = used >= tenKeys ? 0 : tenKeys - used;
  final lead = unused ~/ 2;
  return (lead: lead, trail: unused - lead);
}

const _backspace = KeySpec(
  '⌫',
  flex: 2,
  hid: Hid.backspace,
  kind: KeyKind.backspace,
);

const _moreToggle = KeySpec(
  r'=\<',
  kind: KeyKind.moreSymbols,
);

/// ABC, ?123, and Enter stay this wide on every page. Space takes leftover.
const kActionKeyFlex = 1.4;

KeySpec _spaceKey(double flex) {
  return KeySpec(' ', flex: flex, hid: Hid.space, kind: KeyKind.space);
}

const _enterKey = KeySpec(
  '⏎',
  flex: kActionKeyFlex,
  hid: Hid.enter,
  kind: KeyKind.enter,
);

const _abcKey = KeySpec('ABC', flex: kActionKeyFlex, kind: KeyKind.abc);
const _symbolsKey = KeySpec('?123', flex: kActionKeyFlex, kind: KeyKind.symbols);

double _flexSum(Iterable<KeySpec> keys) {
  var n = 0.0;
  for (final key in keys) {
    n += key.flex;
  }
  return n;
}

/// Bottom row always fills 10 key-units. Toggle and Enter never change width.
List<KeySpec> _bottomRow({
  KeySpec? leading,
  KeySpec? beforeSpace,
  bool xd = false,
  KeySpec? afterXd,
}) {
  final before = <KeySpec>[
    if (leading != null) leading,
    if (beforeSpace != null) beforeSpace,
  ];
  final after = <KeySpec>[
    if (xd) const KeySpec('xD', kind: KeyKind.xd, sequence: [Hid.x, Hid.d]),
    if (afterXd != null) afterXd,
    _enterKey,
  ];
  final spaceFlex = (10 - _flexSum(before) - _flexSum(after)).clamp(1.0, 8.0);
  return [...before, _spaceKey(spaceFlex), ...after];
}

const _deleteKey = KeySpec('Del', flex: 2, hid: Hid.delete, kind: KeyKind.delete);

List<KeySpec> _digitRow() => [
      _sym('1', Hid.n1),
      _sym('2', Hid.n2),
      _sym('3', Hid.n3),
      _sym('4', Hid.n4),
      _sym('5', Hid.n5),
      _sym('6', Hid.n6),
      _sym('7', Hid.n7),
      _sym('8', Hid.n8),
      _sym('9', Hid.n9),
      _sym('0', Hid.n0),
    ];

/// MessageMe / Secure Keyboard ?123 page (Gboard). `=\<` opens more symbols.
KeyPage symbolsPage() {
  return KeyPage([
    _digitRow(),
    [
      _sym('@', Hid.n2, shift: true),
      _sym('#', Hid.n3, shift: true),
      _sym(r'$', Hid.n4, shift: true),
      _sym('_', Hid.minus, shift: true),
      _sym('&', Hid.n7, shift: true),
      _sym('-', Hid.minus),
      _sym('+', Hid.equals, shift: true),
      _sym('(', Hid.n9, shift: true),
      _sym(')', Hid.n0, shift: true),
      _sym('/', Hid.slash),
    ],
    [
      _moreToggle,
      _sym('*', Hid.n8, shift: true),
      _sym('"', Hid.quote, shift: true),
      _sym("'", Hid.quote),
      _sym(':', Hid.semicolon, shift: true),
      _sym(';', Hid.semicolon),
      _sym('!', Hid.n1, shift: true),
      _sym('?', Hid.slash, shift: true),
      _backspace,
    ],
    _bottomRow(leading: _abcKey),
  ]);
}

/// MessageMe / Secure Keyboard second symbols page. `?123` returns.
KeyPage symbolsMorePage() {
  return KeyPage([
    [
      _sym('~', Hid.grave, shift: true),
      _sym('`', Hid.grave),
      _sym('|', Hid.backslash, shift: true),
      _sym('•', 0),
      _sym('√', 0),
      _sym('π', 0),
      _sym('÷', 0),
      _sym('×', 0),
      _sym('<', Hid.comma, shift: true),
      _sym('>', Hid.period, shift: true),
    ],
    [
      _sym('£', 0),
      _sym('¢', 0),
      _sym('€', 0),
      _sym('¥', 0),
      _sym('^', Hid.n6, shift: true),
      _sym('°', 0),
      _sym('=', Hid.equals),
      _sym('{', Hid.lbracket, shift: true),
      _sym('}', Hid.rbracket, shift: true),
      _sym(r'\', Hid.backslash),
    ],
    [
      const KeySpec('?123', kind: KeyKind.symbols),
      _sym('%', Hid.n5, shift: true),
      _sym('©', 0),
      _sym('®', 0),
      _sym('™', 0),
      _sym('✓', 0),
      _sym('[', Hid.lbracket),
      _sym(']', Hid.rbracket),
      _backspace,
    ],
    _bottomRow(leading: _abcKey),
  ]);
}

/// Extended bank above letters. Del sits on the left of the punct row
/// at two-key width so the row matches the 10-key digit row.
/// Backspace stays on the letter row.
List<List<KeySpec>> numberLayoutRows({bool more = false}) {
  final page = more ? symbolsMorePage() : symbolsPage();
  final punct = page.rows[2]
      .where((k) => k.kind != KeyKind.backspace)
      .toList();
  return [
    page.rows[0],
    page.rows[1],
    [_deleteKey, ...punct],
  ];
}

const _cutCopyPaste = <KeySpec>[
  KeySpec('Cut', hid: Hid.x, mod: Hid.leftCtrl, kind: KeyKind.shortcut),
  KeySpec('Copy', hid: Hid.c, mod: Hid.leftCtrl, kind: KeyKind.shortcut),
  KeySpec('Paste', hid: Hid.v, mod: Hid.leftCtrl, kind: KeyKind.shortcut),
];

List<KeySpec> clipboardStrip() => _cutCopyPaste;

List<KeySpec> modifierStrip({bool clipboard = false}) => [
      const KeySpec('Tab', hid: Hid.tab, flex: 1),
      const KeySpec('Esc', hid: Hid.escape, flex: 1),
      const KeySpec('Ctrl', kind: KeyKind.modifier, mod: Hid.leftCtrl, flex: 1),
      const KeySpec('Alt', kind: KeyKind.modifier, mod: Hid.leftAlt, flex: 1),
      const KeySpec('Win', kind: KeyKind.modifier, mod: Hid.leftGui, flex: 1),
      if (clipboard) ..._cutCopyPaste,
    ];

/// Landscape split: left vs right of letter/symbol rows. Never copies the
/// space / ?123 row — that stays once across the bottom.
({List<List<KeySpec>> left, List<List<KeySpec>> right}) splitLetters(
  KeyPage page,
) {
  final left = <List<KeySpec>>[];
  final right = <List<KeySpec>>[];
  for (final row in page.rows) {
    if (row.any((k) => k.kind == KeyKind.space)) continue;
    final mid = (row.length / 2).ceil();
    left.add(row.sublist(0, mid));
    right.add(row.sublist(mid));
  }
  return (left: left, right: right);
}
