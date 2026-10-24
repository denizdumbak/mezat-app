import 'money.dart';

// Case endings after an amount, as in "₺2.000'den ₺2.160'a". Turkish picks
// the ending by how the number is read aloud: its last word ("bin",
// "altmış") decides the vowel (vowel harmony) and whether "d" turns into "t"
// after a hard consonant.

/// "₺2.000'den", "₺2.160'tan", "₺3'ten", "₺6'dan".
String withAblative(Money amount) {
  final word = _lastWord(amount);
  final consonant = _hardConsonants.contains(word[word.length - 1]) ? 't' : 'd';
  return "${amount.format()}'$consonant${_isBack(word) ? 'an' : 'en'}";
}

/// "₺2.160'a", "₺2.000'e", "₺6'ya", "₺2'ye".
String withDative(Money amount) {
  final word = _lastWord(amount);
  final buffer = _vowels.contains(word[word.length - 1]) ? 'y' : '';
  return "${amount.format()}'$buffer${_isBack(word) ? 'a' : 'e'}";
}

const _vowels = 'aeıioöuü';
const _backVowels = 'aıou';
const _hardConsonants = 'fstkçşhp';

/// Whether the last vowel of [word] is a back vowel (a, ı, o, u).
bool _isBack(String word) {
  for (var i = word.length - 1; i >= 0; i--) {
    if (_vowels.contains(word[i])) return _backVowels.contains(word[i]);
  }
  return false;
}

/// The last word of the amount read aloud: the kuruş when there are any
/// ("₺1.250,50" ends in "elli"), otherwise the lira.
String _lastWord(Money amount) {
  final kurus = amount.kurus % 100;
  return _lastWordOf(kurus != 0 ? kurus : amount.kurus ~/ 100);
}

String _lastWordOf(int n) {
  if (n == 0) return 'sıfır';
  if (n % 10 != 0) return _ones[n % 10];
  if (n % 100 != 0) return _tens[n % 100 ~/ 10];
  if (n % 1000 != 0) return 'yüz';
  if (n % 1000000 != 0) return 'bin';
  if (n % 1000000000 != 0) return 'milyon';
  return 'milyar';
}

const _ones = [
  '',
  'bir',
  'iki',
  'üç',
  'dört',
  'beş',
  'altı',
  'yedi',
  'sekiz',
  'dokuz',
];
const _tens = [
  '',
  'on',
  'yirmi',
  'otuz',
  'kırk',
  'elli',
  'altmış',
  'yetmiş',
  'seksen',
  'doksan',
];
