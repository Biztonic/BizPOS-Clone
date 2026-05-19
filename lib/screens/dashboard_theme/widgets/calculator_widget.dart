import '../../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:math_expressions/math_expressions.dart' as math;
import '../../../utils/car_dashboard_theme.dart';

class CalculatorWidget extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onClose;
  // POS Data Callbacks
  final double? todaysSale;
  final int? totalOrders;
  final double? cashInHand;

  const CalculatorWidget({
    super.key, 
    required this.isDarkMode,
    this.onClose,
    this.todaysSale,
    this.totalOrders,
    this.cashInHand,
  });

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  // --- CALCULATOR STATE ---
  String _input = '0';
  String _result = '';
  
  // --- CONVERTER STATE ---
  String _selectedCategory = 'Length';
  String _fromUnit = 'Meter';
  String _toUnit = 'Centimeter';
  final TextEditingController _converterController = TextEditingController();
  String _conversionResult = '';

  // Data Definitions
  final Map<String, List<String>> _units = {
    'Length': ['Meter', 'Centimeter', 'Kilometer', 'Mile', 'Inch', 'Foot'],
    'Weight': ['Kilogram', 'Gram', 'Milligram', 'Pound', 'Ounce'],
    'Volume': ['Liter', 'Milliliter', 'Gallon', 'Cup'],
    'Temperature': ['Celsius', 'Fahrenheit', 'Kelvin'],
    'Speed': ['Km/h', 'Mph', 'Meter/s'],
    'Area': ['Sq Meter', 'Sq Kilometer', 'Sq Foot', 'Acre', 'Hectare'],
  };

  final Map<String, Map<String, double>> _factors = {
     'Length': { 'Meter': 1, 'Centimeter': 0.01, 'Kilometer': 1000, 'Mile': 1609.34, 'Inch': 0.0254, 'Foot': 0.3048 },
     'Weight': { 'Kilogram': 1000, 'Gram': 1, 'Milligram': 0.001, 'Pound': 453.592, 'Ounce': 28.3495 },
     'Volume': { 'Liter': 1000, 'Milliliter': 1, 'Gallon': 3785.41, 'Cup': 236.588 },
     'Speed':  { 'Km/h': 1, 'Mph': 1.60934, 'Meter/s': 3.6 }, 
     'Area':   { 'Sq Meter': 1, 'Sq Kilometer': 1000000, 'Sq Foot': 0.092903, 'Acre': 4046.86, 'Hectare': 10000 },
  };

  @override
  void initState() {
    super.initState();
    _converterController.addListener(_convert);
  }

  @override
  void dispose() {
    _converterController.dispose();
    super.dispose();
  }

  void _convert() {
     if (!mounted) return;
     if (_converterController.text.isEmpty) {
        setState(() => _conversionResult = '');
        return;
     }

     double val = double.tryParse(_converterController.text) ?? 0;
     double res = 0;
     
     // Safety Checks
     if (!_units.containsKey(_selectedCategory)) return;

     if (_selectedCategory == 'Temperature') {
        if (_fromUnit == 'Celsius') {
           if (_toUnit == 'Fahrenheit') {
             res = (val * 9/5) + 32;
           } else if (_toUnit == 'Kelvin') res = val + 273.15;
           else res = val;
        } else if (_fromUnit == 'Fahrenheit') {
           if (_toUnit == 'Celsius') {
             res = (val - 32) * 5/9;
           } else if (_toUnit == 'Kelvin') res = (val - 32) * 5/9 + 273.15;
           else res = val;
        } else if (_fromUnit == 'Kelvin') {
           if (_toUnit == 'Celsius') {
             res = val - 273.15;
           } else if (_toUnit == 'Fahrenheit') res = (val - 273.15) * 9/5 + 32;
           else res = val;
        }
     } else {
        final catFactors = _factors[_selectedCategory];
        if (catFactors == null) return;
        
        final fromF = catFactors[_fromUnit];
        final toF = catFactors[_toUnit];
        
        if (fromF == null || toF == null) return;

        double toBase = val * fromF;
        res = toBase / toF;
     }

     setState(() {
        _conversionResult = res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(4);
        if (_conversionResult.contains('.') && double.tryParse(_conversionResult) != null) {
           _conversionResult = double.parse(_conversionResult).toString(); 
        }
     });
  }

  // --- CALCULATOR LOGIC ---
  void _onBtnTap(String text) {
     setState(() {
        if (_input == '0' && text != '.') _input = '';
        _input += text;
     });
  }

  void _clear() {
     setState(() {
        _input = '0';
        _result = '';
     });
  }

  void _delete() {
     setState(() {
        if (_input.isNotEmpty) {
           _input = _input.substring(0, _input.length - 1);
           if (_input.isEmpty) _input = '0';
        }
     });
  }

  void _insertValue(String val) {
     setState(() {
        if (_input == '0') _input = '';
        _input += val;
     });
  }

  void _evaluate() {
     try {
       String finalInput = _input.replaceAll('x', '*').replaceAll('÷', '/');
       
       // --- NATIVE PERCENTAGE LOGIC ---
       // 1. Handle "X + Y%" pattern -> "X + (X * Y / 100)"
       // Using Regex to find numbers followed by operators followed by percentage
       final regex = RegExp(r'(\d+\.?\d*)\s*([\+\-\*\/])\s*(\d+\.?\d*)\s*%');
       while (regex.hasMatch(finalInput)) {
          final match = regex.firstMatch(finalInput)!;
          final x = match.group(1);
          final op = match.group(2);
          final y = match.group(3);
          final replacement = "$x $op ($x * $y / 100)";
          finalInput = finalInput.replaceFirst(match.group(0)!, replacement);
       }
       
       // 2. Handle standalone percentages "10%" -> "10/100"
       finalInput = finalInput.replaceAllMapped(RegExp(r'(\d+\.?\d*)\s*%'), (m) => "(${m.group(1)}/100)");

       math.Parser p = math.Parser();
       math.Expression exp = p.parse(finalInput);
       math.ContextModel cm = math.ContextModel();
       double eval = exp.evaluate(math.EvaluationType.REAL, cm);
       
       setState(() {
          _result = _input;
          if (eval % 1 == 0) {
             _input = eval.toInt().toString();
          } else {
             // Avoid long decimals
             if (eval.toString().split('.').last.length > 4) {
                _input = eval.toStringAsFixed(4);
             } else {
                _input = eval.toString();
             }
          }
          // Remove trailing .0 if present
          if (_input.endsWith('.0')) _input = _input.substring(0, _input.length - 2);
       });
     } catch (e) {
       setState(() {
          _result = "Error";
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = CarDashboardTheme.textColor(widget.isDarkMode);
    final bgColor = CarDashboardTheme.backgroundColor(widget.isDarkMode);
    final panelColor = CarDashboardTheme.panelColor(widget.isDarkMode);
    final primary = CarDashboardTheme.primaryColor(widget.isDarkMode);
    final isDark = widget.isDarkMode;

    // LIVE DATA FROM PROVIDER
    final provider = context.watch<DashboardProvider>();
    final orders = provider.orders;
    
    // 1. Last Sale
    final lastOrder = orders.isNotEmpty ? orders.last : null; 
    final lastSaleAmount = lastOrder != null ? "₹${lastOrder.total.toStringAsFixed(0)}" : "₹0";

    // 2. Orders (Today)
    final now = DateTime.now();
    final todayOrders = orders.where((o) {
       return o.date.year == now.year && o.date.month == now.month && o.date.day == now.day;
    }).toList();
    final ordersCount = todayOrders.length.toString();

    // 3. Cash (Today)
    final cashOrders = todayOrders.where((o) => o.paymentMethod == 'Cash').toList();
    final cashTotal = cashOrders.fold(0.0, (sum, o) => sum + o.total);
    final cashDisplay = "₹${cashTotal.toStringAsFixed(0)}";


    return Scaffold(
      backgroundColor: bgColor, 
      body: SafeArea(
        child: Column(
          children: [
             // HEADER: Title + Close Button
             Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Text(AppLocalizations.t(context, 'Tools & Calculator'), style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      // CLOSE BUTTON
                      InkWell(
                         onTap: () => Navigator.pop(context),
                         child: Container(
                            width: 36, 
                            height: 36,
                            decoration: const BoxDecoration(
                               color: AppColors.error,
                               borderRadius: BorderRadius.zero,
                            ),
                            child: const Icon(Icons.close, color: AppColors.surfaceLight, size: 20),
                         ),
                      )
                   ],
                ),
             ),
             
             // MAIN BODY
             Expanded(
                child: Row(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                      // LEFT COLUMN (Flex 4) -> Contains Display, Quick Data, Converter
                      Expanded(
                         flex: 4,
                         child: Container(
                            padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.lg, right: 12),
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: [
                                  // 1. DISPLAY
                                  Expanded(
                                     flex: 3,
                                     child: Container(
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        decoration: BoxDecoration(
                                           color: isDark ? AppColors.textHintLight : AppColors.textSecondary(context),
                                           borderRadius: BorderRadius.zero,
                                           border: Border.all(color: AppColors.textSecondary(context).withValues(alpha: 0.1))
                                        ),
                                        child: Column(
                                           mainAxisAlignment: MainAxisAlignment.end,
                                           crossAxisAlignment: CrossAxisAlignment.end,
                                           children: [
                                              Text(_result, style: TextStyle(fontSize: 20, color: textColor.withValues(alpha: 0.5))),
                                              // FITTED BOX to prevent overflow
                                              Flexible(
                                                 child: FittedBox(
                                                    fit: BoxFit.scaleDown, 
                                                    alignment: Alignment.bottomRight,
                                                    child: Text(_input, style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: textColor))
                                                 ),
                                              ),
                                           ],
                                        ),
                                     ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),

                                  // 2. QUICK DATA (Live)
                                  SizedBox(
                                     height: 70, // Fixed height
                                     child: Row(
                                        children: [
                                           _buildSmartKey("Last Sale", lastSaleAmount, AppColors.success),
                                           const SizedBox(width: AppSpacing.sm),
                                           _buildSmartKey("Orders", ordersCount, AppColors.warning),
                                           const SizedBox(width: AppSpacing.sm),
                                           _buildSmartKey("Cash", cashDisplay, AppColors.primaryLight),
                                        ],
                                     ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),

                                  // 3. CONVERTER (WHEEL PICKER STYLE)
                                  Expanded(
                                     flex: 4,
                                     child: Container(
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        decoration: BoxDecoration(
                                           color: panelColor,
                                           borderRadius: BorderRadius.zero,
                                           border: Border.all(color: CarDashboardTheme.borderColor(isDark))
                                        ),
                                        child: Column(
                                           children: [
                                              // Categories List
                                              SingleChildScrollView(
                                                 scrollDirection: Axis.horizontal,
                                                 child: Row(
                                                    children: _units.keys.map((String cat) => Padding(
                                                       padding: const EdgeInsets.only(right: AppSpacing.sm),
                                                       child: ChoiceChip(
                                                          label: Text(cat, style: const TextStyle(fontSize: 12)),
                                                          selected: _selectedCategory == cat,
                                                          onSelected: (bool sel) {
                                                             if (sel) {
                                                               setState(() { 
                                                                _selectedCategory = cat; 
                                                                List<String>? newUnits = _units[cat];
                                                                if (newUnits != null && newUnits.isNotEmpty) {
                                                                   _fromUnit = newUnits.first;
                                                                   _toUnit = newUnits.length > 1 ? newUnits[1] : newUnits[0];
                                                                }
                                                                _convert();
                                                             });
                                                             }
                                                          },
                                                          selectedColor: primary,
                                                          labelStyle: TextStyle(color: _selectedCategory == cat ? AppColors.surfaceLight : textColor),
                                                          backgroundColor: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context),
                                                          side: BorderSide.none,
                                                          visualDensity: VisualDensity.compact,
                                                       ),
                                                    )).toList(),
                                                 ),
                                              ),
                                              const SizedBox(height: AppSpacing.md),
                                              
                                              // WHEEL PICKER UI
                                              Expanded(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        // COL 1: FROM UNIT (Distinct Card + Shadow Overlay)
                                                        Expanded(
                                                          child: Container(
                                                            margin: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF1E1E1E) : AppColors.surfaceLight,
                                                              borderRadius: BorderRadius.zero,
                                                            ),
                                                            child: Stack(
                                                              children: [
                                                                // The Wheel - RED
                                                                _buildWheelPicker(
                                                                  _units[_selectedCategory] ?? [], 
                                                                  _fromUnit, 
                                                                  AppColors.error, 
                                                                  (val) {
                                                                    setState(() { _fromUnit = val; _convert(); });
                                                                  }
                                                                ),
                                                                // Shadow Gradient Overlay
                                                                IgnorePointer(
                                                                  child: Container(
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius.zero,
                                                                      gradient: LinearGradient(
                                                                        begin: Alignment.topCenter,
                                                                        end: Alignment.bottomCenter,
                                                                        colors: [
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.9), 
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.0), 
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.0), 
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.9)
                                                                        ],
                                                                        stops: const [0.0, 0.3, 0.7, 1.0],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        
                                                        // COL 2: INPUT / RESULT (Floating Middle)
                                                        Expanded(
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              TextField(
                                                                 controller: _converterController,
                                                                 textAlign: TextAlign.center,
                                                                 style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.8)),
                                                                 keyboardType: TextInputType.number,
                                                                 decoration: InputDecoration(
                                                                    hintText: "0", hintStyle: TextStyle(fontSize: 32, color: textColor.withValues(alpha: 0.1)),
                                                                    border: InputBorder.none, isDense: true,
                                                                    contentPadding: EdgeInsets.zero
                                                                 ),
                                                              ),
                                                              Container(
                                                                height: 2, 
                                                                width: 50, 
                                                                color: primary.withValues(alpha: 0.4), 
                                                                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm)
                                                              ),
                                                              FittedBox(
                                                                child: Text(
                                                                   _conversionResult.isEmpty ? "0" : _conversionResult,
                                                                   style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primary),
                                                                ),
                                                              )
                                                            ],
                                                          ),
                                                        ),

                                                        // COL 3: TO UNIT (Distinct Card + Shadow Overlay)
                                                        Expanded(
                                                          child: Container(
                                                            margin: const EdgeInsets.fromLTRB(4, 0, 8, 0),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF1E1E1E) : AppColors.surfaceLight,
                                                              borderRadius: BorderRadius.zero,
                                                            ),
                                                            child: Stack(
                                                              children: [
                                                                // The Wheel - BLUE
                                                                _buildWheelPicker(
                                                                  _units[_selectedCategory] ?? [], 
                                                                  _toUnit,
                                                                  AppColors.primaryLightAccent, // Right is Blue (Wait prompt said "blue color to right wheel")
                                                                  (val) {
                                                                    setState(() { _toUnit = val; _convert(); });
                                                                  }
                                                                ),
                                                                // Shadow Gradient Overlay
                                                                IgnorePointer(
                                                                  child: Container(
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius.zero,
                                                                      gradient: LinearGradient(
                                                                        begin: Alignment.topCenter,
                                                                        end: Alignment.bottomCenter,
                                                                        colors: [
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.9), 
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.0), 
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.0), 
                                                                           (isDark ? AppColors.textPrimaryLight : AppColors.surfaceLight).withValues(alpha: 0.9)
                                                                        ],
                                                                        stops: const [0.0, 0.3, 0.7, 1.0],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                           ],
                                        ),
                                     ),
                                  )
                               ],
                            ),
                         ),
                      ),
                      
                      // RIGHT COLUMN (Flex 5)
                      Expanded(
                         flex: 5,
                         child: Container(
                            padding: const EdgeInsets.only(right: AppSpacing.lg, bottom: AppSpacing.lg, top: 0, left: 12),
                            child: Row(
                              children: [
                                 // NUMPAD (Flex 3)
                                 Expanded(
                                   flex: 3,
                                   child: Column(
                                     children: [
                                       Expanded(child: Row(children: [ Expanded(child: _buildBtn('C', AppColors.error, AppColors.error)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('âŒ«', AppColors.warning, AppColors.warning)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('%', isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), textColor)) ])),
                                       const SizedBox(height: AppSpacing.md),
                                       Expanded(child: Row(children: [ Expanded(child: _buildBtn('7', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('8', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('9', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)) ])),
                                       const SizedBox(height: AppSpacing.md),
                                       Expanded(child: Row(children: [ Expanded(child: _buildBtn('4', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('5', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('6', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)) ])),
                                       const SizedBox(height: AppSpacing.md),
                                       Expanded(child: Row(children: [ Expanded(child: _buildBtn('1', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('2', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), const SizedBox(width: AppSpacing.sm), Expanded(child: _buildBtn('3', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)) ])),
                                       const SizedBox(height: AppSpacing.md),
                                       // ROW 5: 0, ., = (Moved = here)
                                       Expanded(child: Row(children: [ 
                                          Expanded(child: _buildBtn('0', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), 
                                          const SizedBox(width: AppSpacing.sm), 
                                          Expanded(child: _buildBtn('.', isDark ? AppColors.textSecondary(context) : AppColors.surfaceLight, textColor)), 
                                          const SizedBox(width: AppSpacing.sm), 
                                          Expanded(child: _buildBtn('=', AppColors.success, AppColors.surfaceLight)),
                                       ])),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(width: AppSpacing.md),
                                 // OPERATORS (Flex 1)
                                 Expanded(
                                   flex: 1,
                                   child: Column(
                                     children: [
                                       Expanded(child: _buildBtn('÷', primary.withValues(alpha: 0.2), primary)),
                                       const SizedBox(height: AppSpacing.md),
                                       Expanded(child: _buildBtn('x', primary.withValues(alpha: 0.2), primary)),
                                       const SizedBox(height: AppSpacing.md),
                                       Expanded(child: _buildBtn('-', primary.withValues(alpha: 0.2), primary)),
                                       const SizedBox(height: AppSpacing.md),
                                       // TALL PLUS BUTTON
                                       Expanded(
                                         flex: 2, 
                                         child: _buildBtn('+', primary.withValues(alpha: 0.2), primary, fontSize: 56),
                                       ),
                                     ], 
                                   ),
                                 ),
                              ],
                            ),
                            // OLD GRID WAS HERE
                         ),
                      )
                   ],
                ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildSmartKey(String label, String value, Color color) {
     return Expanded(
        child: InkWell(
           onTap: () => _insertValue(value.replaceAll(RegExp(r'[^0-9.]'), '')), 
           borderRadius: BorderRadius.zero,
           child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                 color: color.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.zero,
                 border: Border.all(color: color.withValues(alpha: 0.3))
              ),
              child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                 ],
              ),
           ),
        ),
     );
  }
  
  // NEW: Wheel Picker Helper
  Widget _buildWheelPicker(List<String> items, String selected, Color selectedColor, Function(String) onChanged) {
     final itemIndex = items.indexOf(selected);
     return ListWheelScrollView.useDelegate(
        itemExtent: 50,
        perspective: 0.003,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        controller: FixedExtentScrollController(initialItem: itemIndex != -1 ? itemIndex : 0),
        onSelectedItemChanged: (index) {
           if (index >= 0 && index < items.length) {
              onChanged(items[index]);
           }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
             final isSelected = items[index] == selected;
             final color = isSelected ? selectedColor : AppColors.textSecondary(context);
             return Center(
               child: Text(
                 items[index],
                 style: TextStyle(
                    fontSize: isSelected ? 20 : 14, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: color
                 ),
               ),
             );
          },
          childCount: items.length,
        ),
     );
  }

  Widget _buildBtn(String text, Color bg, Color txtColor, {double? fontSize}) {
     return Material(
        color: AppColors.transparent,
        child: InkWell(
           onTap: () {
              if (text == 'C') {
                _clear();
              } else if (text == 'âŒ«') _delete();
              else if (text == '=') _evaluate();
              else _onBtnTap(text);
           },
           borderRadius: BorderRadius.zero,
           child: Container(
              decoration: BoxDecoration(
                 color: bg,
                 borderRadius: BorderRadius.zero,
              ),
              child: Center(
                 child: Text(text, style: TextStyle(fontSize: fontSize ?? 28, fontWeight: FontWeight.w600, color: txtColor)),
              ),
           ),
        ),
     );
  }
}

