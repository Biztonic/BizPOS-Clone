import '../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class PromotionalSignage extends StatefulWidget {
  const PromotionalSignage({super.key});

  @override
  State<PromotionalSignage> createState() => _PromotionalSignageState();
}

class _PromotionalSignageState extends State<PromotionalSignage> {
  int _currentIndex = 0;
  final List<String> _promos = [
    "Special Offer: 50% OFF on Combos!",
    "Buy 1 Get 1 Free Today Only!",
    "Download our App for Rewards",
    "New Arrival: Spicy Chicken Blast"
  ];
  final List<Color> _colors = [AppColors.error, AppColors.primaryLight, AppColors.primaryLight, AppColors.warning];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSlideshow();
  }

  void _startSlideshow() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _promos.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Promotional Screen"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_colors[_currentIndex].withValues(alpha: 0.8), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.local_offer, size: 100, color: Colors.white.withValues(alpha: 0.8)),
               const SizedBox(height: 48),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 48.0),
                 child: Text(
                   _promos[_currentIndex],
                   textAlign: TextAlign.center,
                   style: const TextStyle(
                       color: Colors.white,
                       fontSize: 64,
                       fontWeight: FontWeight.bold,
                       letterSpacing: 2,
                       shadows: [Shadow(color: Colors.black26, offset: Offset(2,2), blurRadius: 4)]
                   ),
                 ),
               ),
               const SizedBox(height: 24),
               const Text("Visit Counter for details", style: TextStyle(color: Colors.white70, fontSize: 24))
            ],
          ),
        ),
      ),
    );
  }
}
