import 'package:flutter/material.dart';

// ============================================================================
// ROULETTE CONSTANTS & CONFIGURATION
// ============================================================================

class RouletteConstants {
  // Wheel configuration
  static const int totalNumbers = 37; // 0-36
  static const double wheelRadius = 140.0;
  static const double ballRadius = 8.0;
  static const double pocketHeight = 30.0;

  // Layout
  static const double chipSize = 50.0;
  static const double numberCellSize = 45.0;
  static const double tableMargin = 20.0;

  // Animation
  static const int minSpinDuration = 4000; // ms
  static const int maxSpinDuration = 6000; // ms
  static const int ballRevolutions = 8;

  // Betting
  static const int defaultChipValue = 10;
  static const int startingBalance = 1000;

  // Visual
  static const double glowBlur = 20.0;
  static const double shadowBlur = 8.0;
}

class RouletteText {
  static const String placeBets = 'PLACE YOUR BETS';
  static const String spinning = 'SPINNING...';
  static const String winner = 'WINNER!';
  static const String balance = 'BALANCE';
  static const String bet = 'BET';
  static const String clear = 'CLEAR';
  static const String spin = 'SPIN';
  static const String noBalance = 'INSUFFICIENT FUNDS';
  static const String noBets = 'PLACE A BET FIRST';
}

class RouletteNumbers {
  // European roulette wheel order (clockwise from 0)
  static const List<int> wheelOrder = [
    0,
    32,
    15,
    19,
    4,
    21,
    2,
    25,
    17,
    34,
    6,
    27,
    13,
    36,
    11,
    30,
    8,
    23,
    10,
    5,
    24,
    16,
    33,
    1,
    20,
    14,
    31,
    9,
    22,
    18,
    29,
    7,
    28,
    12,
    35,
    3,
    26,
  ];

  // Black numbers (in European roulette, others are red - we'll make them white)
  static const Set<int> blackNumbers = {
    2,
    4,
    6,
    8,
    10,
    11,
    13,
    15,
    17,
    20,
    22,
    24,
    26,
    28,
    29,
    31,
    33,
    35,
  };

  static bool isBlack(int number) {
    if (number == 0) {
      return false; // Green in real roulette, we'll make it special
    }
    return blackNumbers.contains(number);
  }

  static bool isWhite(int number) {
    if (number == 0) return false;
    return !blackNumbers.contains(number);
  }

  static Color getNumberColor(int number) {
    if (number == 0) return const Color(0xFF059669); // Green for 0
    return isBlack(number) ? Colors.black : Colors.white;
  }

  static Color getNumberTextColor(int number) {
    if (number == 0) return Colors.white; // White text on green
    return isBlack(number) ? Colors.white : Colors.black;
  }

  // Betting zones
  static const List<List<int>> columns = [
    [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34],
    [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35],
    [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36],
  ];

  static const List<List<int>> dozens = [
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
    [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36],
  ];

  static List<int> getLowNumbers() => List.generate(18, (i) => i + 1);
  static List<int> getHighNumbers() => List.generate(18, (i) => i + 19);
  static List<int> getEvenNumbers() => List.generate(18, (i) => (i + 1) * 2);
  static List<int> getOddNumbers() => List.generate(18, (i) => i * 2 + 1);
  static List<int> getBlackNumbers() => blackNumbers.toList();
  static List<int> getWhiteNumbers() => List.generate(
    36,
    (i) => i + 1,
  ).where((n) => !blackNumbers.contains(n)).toList();
}

class BetType {
  final String name;
  final List<int> numbers;
  final int payout; // Multiplier

  const BetType({
    required this.name,
    required this.numbers,
    required this.payout,
  });

  static BetType straight(int number) =>
      BetType(name: 'Straight $number', numbers: [number], payout: 35);

  static BetType black() => BetType(
    name: 'Black',
    numbers: RouletteNumbers.getBlackNumbers(),
    payout: 1,
  );

  static BetType white() => BetType(
    name: 'White',
    numbers: RouletteNumbers.getWhiteNumbers(),
    payout: 1,
  );

  static BetType low() => BetType(
    name: 'Low (1-18)',
    numbers: RouletteNumbers.getLowNumbers(),
    payout: 1,
  );

  static BetType high() => BetType(
    name: 'High (19-36)',
    numbers: RouletteNumbers.getHighNumbers(),
    payout: 1,
  );

  static BetType even() => BetType(
    name: 'Even',
    numbers: RouletteNumbers.getEvenNumbers(),
    payout: 1,
  );

  static BetType odd() =>
      BetType(name: 'Odd', numbers: RouletteNumbers.getOddNumbers(), payout: 1);

  static BetType column(int col) => BetType(
    name: 'Column ${col + 1}',
    numbers: RouletteNumbers.columns[col],
    payout: 2,
  );

  static BetType dozen(int doz) => BetType(
    name: 'Dozen ${doz + 1}',
    numbers: RouletteNumbers.dozens[doz],
    payout: 2,
  );
}
