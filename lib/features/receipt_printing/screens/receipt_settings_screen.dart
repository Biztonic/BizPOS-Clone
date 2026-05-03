import '../../../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../models/settings.dart';
import '../../../../models/store.dart';
import '../../../../utils/responsive.dart';
import '../models/receipt_config.dart';
import '../models/receipt_content.dart';
import '../widgets/receipt_preview_widget.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  late ReceiptSettings _settings;
  bool _isInit = true;
  final TextEditingController _upsellController = TextEditingController();
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _qrController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = Provider.of<DashboardProvider>(context, listen: false).activeStore;
      if (store != null) {
        _settings = store.receipt;
        _upsellController.text = _settings.upsellMessage;
        _headerController.text = _settings.customHeaderMessage; 
        _qrController.text = _settings.qrData;
      } else {
        _settings = ReceiptSettings();
      }
      _isInit = false;
    }
  }
  
  @override
  void dispose() {
    _upsellController.dispose();
    _headerController.dispose();
    _qrController.dispose();
    super.dispose();
  }

  void _updateSetting(ReceiptSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
  }

  Future<void> _saveSettings() async {
    // Commit text field values
    final finalSettings = _settings.copyWith(
      upsellMessage: _upsellController.text,
      customHeaderMessage: _headerController.text,
      qrData: _qrController.text,
    );
    
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final store = provider.activeStore;
    if (store != null) {
      final updatedStore = store.copyWith(receipt: finalSettings);
      await provider.updateStoreSettings(updatedStore);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receipt Settings Saved")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<DashboardProvider>(context).activeStore;
    
    if (store == null) {
      return const Scaffold(body: Center(child: Text("No Active Store")));
    }

    // Build Content
    final liveSettings = _settings.copyWith(
      upsellMessage: _upsellController.text,
      customHeaderMessage: _headerController.text,
      qrData: _qrController.text,
    );
    final previewContent = _buildPreviewContent(store, liveSettings);
    final config = _settings.receiptWidth == 58 ? ReceiptConfig.mm58() : ReceiptConfig.mm80();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Receipt Configuration"),
        actions: [
          TextButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text("Save"),
          ),
        ],
      ),
      body: Responsive(
        mobile: _buildMobileLayout(previewContent, config, liveSettings),
        desktop: _buildDesktopLayout(previewContent, config, liveSettings),
        tablet: _buildDesktopLayout(previewContent, config, liveSettings),
      ),
    );
  }
  
  // Dummy Content Builder
  ReceiptContent _buildPreviewContent(Store store, ReceiptSettings settings) {
    // Mock Totals
    double grandTotal = 444.15;
    
    // Dynamic QR Logic (Mirroring UniversalPrinterService)
    String? effectiveQrData;
    if (settings.showQr) {
      if (store.payment.upiId.isNotEmpty) { 
        final String pa = store.payment.upiId;
        final String pn = Uri.encodeComponent(store.payment.upiName.isNotEmpty ? store.payment.upiName : store.name);
        final String am = grandTotal.toStringAsFixed(2);
        effectiveQrData = "upi://pay?pa=$pa&pn=$pn&am=$am&cu=INR";
      } else if (settings.qrData.isNotEmpty) {
        effectiveQrData = settings.qrData;
      }
    }

     return ReceiptContent(
       header: ReceiptHeader(
         storeName: settings.showStoreName ? store.name : '',
         address: settings.showAddress ? (store.address ?? '') : null,
         phone: settings.showPhone ? (store.phone ?? '') : null,
         gstin: settings.showTaxDetails ? '27ABCDE1234F1Z5' : null,
         customMessage: settings.customHeaderMessage.isNotEmpty ? settings.customHeaderMessage : null,
       ),
       billInfo: ReceiptBillInfo(
         billNo: settings.showOrderNo ? '1001' : '',
         date: DateTime.now(),
         cashierName: 'Admin',
         tokenNo: settings.showTokenNo ? '12' : null,
       ),
       items: [
         ReceiptItem(name: "Chicken Burger", quantity: 2, price: 150.00, amount: 300.00),
         ReceiptItem(name: "Coke Zero (300ml)", quantity: 1, price: 50.00, amount: 50.00),
         ReceiptItem(name: "French Fries Lrg", quantity: 1, price: 120.00, amount: 120.00),
       ],
       summary: ReceiptKeyValSummary(rows: [
         ReceiptKeyVal(label: 'Subtotal', value: '470.00'),
         if (settings.showDiscount)
            ReceiptKeyVal(label: 'Discount (10%)', value: '-47.00'),
         if (settings.showTaxDetails) ...[
            ReceiptKeyVal(label: 'CGST (2.5%)', value: '10.58'),
            ReceiptKeyVal(label: 'SGST (2.5%)', value: '10.58'),
         ],
       ], grandTotal: ReceiptKeyVal(label: 'Grand Total', value: grandTotal.toStringAsFixed(2), isLarge: true)),
       payment: ReceiptKeyValSummary(rows: [
          ReceiptKeyVal(label: 'Cash', value: '500.00'),
          ReceiptKeyVal(label: 'Change', value: '55.85'),
       ]),
       footer: settings.showFooter ? ReceiptFooter(
         message: settings.upsellMessage.isNotEmpty ? settings.upsellMessage : "Thank You Visit Again !!!",
         poweredBy: "Powered by Biztonic",
         qrData: effectiveQrData,
       ) : null,
     );
  }

  Widget _buildDesktopLayout(ReceiptContent content, ReceiptConfig config, ReceiptSettings settings) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            color: Theme.of(context).cardColor,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: _buildControlList(),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            color: AppColors.textSecondary(context),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: ReceiptPreviewWidget(
                content: content,
                config: config,
                settings: settings,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ReceiptContent content, ReceiptConfig config, ReceiptSettings settings) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Settings"),
              Tab(text: "Live Preview"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(padding: const EdgeInsets.all(16), children: _buildControlList()),
                Container(
                   color: AppColors.textSecondary(context),
                   alignment: Alignment.topCenter,
                   child: SingleChildScrollView(
                     padding: const EdgeInsets.all(20),
                     child: ReceiptPreviewWidget(
                        content: content,
                        config: config,
                        settings: settings,
                     ),
                   ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildControlList() {
    return [
      const Text('Layout & Dimensions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
      const SizedBox(height: 10),
      ListTile(
        title: const Text("Printer Width"),
        trailing: DropdownButton<int>(
          value: _settings.receiptWidth,
          onChanged: (val) {
            if (val != null) _updateSetting(_settings.copyWith(receiptWidth: val));
          },
          items: const [
            DropdownMenuItem(value: 58, child: Text("58mm")),
            DropdownMenuItem(value: 80, child: Text("80mm")),
          ],
        ),
      ),
      
      const Divider(height: 30),
      const Text('Print Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
      const SizedBox(height: 10),
      ListTile(
        title: const Text("Print Action"),
        subtitle: const Text("Choose which receipts to print automatically"),
        trailing: DropdownButton<String>(
          value: _settings.printAction, 
          onChanged: (val) {
             if (val != null) _updateSetting(_settings.copyWith(printAction: val));
          },
          items: const [
            DropdownMenuItem(value: 'Main', child: Text("Main Receipt Only")),
            DropdownMenuItem(value: 'KDS', child: Text("KDS Receipt Only")),
            DropdownMenuItem(value: 'Both', child: Text("Both (Main + KDS)")),
          ],
        ),
      ),



      const Divider(height: 30),
      const Text('Header & Branding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
      const SizedBox(height: 10),
      SwitchListTile(
        title: const Text("Show Store Name"),
        value: _settings.showStoreName,
        onChanged: (val) => _updateSetting(_settings.copyWith(showStoreName: val)),
      ),
      SwitchListTile(
        title: const Text("Show Address"),
        value: _settings.showAddress,
        onChanged: (val) => _updateSetting(_settings.copyWith(showAddress: val)),
      ),
      SwitchListTile(
        title: const Text("Show Phone Number"),
        value: _settings.showPhone,
        onChanged: (val) => _updateSetting(_settings.copyWith(showPhone: val)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
           controller: _headerController,
           decoration: const InputDecoration(labelText: "Custom Header Message"),
           onChanged: (val) {
              setState(() {});
           },
        ),
      ),

      const Divider(height: 30),
      const Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
      const SizedBox(height: 10),
      SwitchListTile(
        title: const Text("Show Bill/Order Number"),
        value: _settings.showOrderNo,
        onChanged: (val) => _updateSetting(_settings.copyWith(showOrderNo: val)),
      ),
      SwitchListTile(
        title: const Text("Show Token Number (Big)"),
        subtitle: const Text("Useful for QSR/Counter Service"),
        value: _settings.showTokenNo,
        onChanged: (val) => _updateSetting(_settings.copyWith(showTokenNo: val)),
      ),
      
      const Divider(height: 30),
      const Text('Financials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
      const SizedBox(height: 10),
      SwitchListTile(
        title: const Text("Show Tax Breakdown"),
        value: _settings.showTaxDetails,
        onChanged: (val) => _updateSetting(_settings.copyWith(showTaxDetails: val)),
      ),
      SwitchListTile(
        title: const Text("Show Discount"),
        value: _settings.showDiscount,
        onChanged: (val) => _updateSetting(_settings.copyWith(showDiscount: val)),
      ),

      const Divider(height: 30),
      const Text('Footer & Marketing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
      const SizedBox(height: 10),
      SwitchListTile(
        title: const Text("Show Footer Message"),
        value: _settings.showFooter,
        onChanged: (val) => _updateSetting(_settings.copyWith(showFooter: val)),
      ),
      if (_settings.showFooter)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
             controller: _upsellController,
             decoration: const InputDecoration(labelText: "Custom Footer Message"),
             onChanged: (val) {
                // Force rebuild to update preview
                setState(() {});
             },
          ),
        ),
      
      SwitchListTile(
        title: const Text("Show QR Code"),
        value: _settings.showQr,
        onChanged: (val) => _updateSetting(_settings.copyWith(showQr: val)),
      ),
      if (_settings.showQr)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
             controller: _qrController,
             decoration: const InputDecoration(labelText: "QR Data / Link"),
             onChanged: (val) {
                setState(() {});
             },
          ),
        ),
      
      const SizedBox(height: 40),
    ];
  }
}
