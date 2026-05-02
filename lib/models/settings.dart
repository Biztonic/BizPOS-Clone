class StoreSettings {
  final String id;
  final String storeName;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final ReceiptSettings receipt;
  final ModuleSettings modules;
  final DashboardSettings dashboard;
  final SyncSettings syncSettings;
  final List<String> counters;
  final KdsSettings kds;
  final PaymentSettings payment;

  StoreSettings({
    required this.id,
    required this.storeName,
    this.address,
    this.phone,
    this.logoUrl,
    required this.receipt,
    required this.modules,
    required this.dashboard,
    required this.syncSettings,
    this.counters = const ['Main Counter'],
    required this.kds,
    required this.payment,
  });

  factory StoreSettings.fromMap(Map<String, dynamic> data, String id) {
    return StoreSettings(
      id: id,
      storeName: data['storeName'] ?? '',
      address: data['address'],
      phone: data['phone'],
      logoUrl: data['logoUrl'],
      receipt: ReceiptSettings.fromMap(data['receipt'] ?? {}),
      modules: ModuleSettings.fromMap(data['modules'] ?? {}),
      dashboard: DashboardSettings.fromMap(data['dashboard'] ?? {}),
      syncSettings: SyncSettings.fromMap(data['syncSettings'] ?? {}),
      counters: (data['counters'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? ['Main Counter'],
      kds: KdsSettings.fromMap(data['kds'] ?? {}),
      payment: PaymentSettings.fromMap(data['payment'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'address': address,
      'phone': phone,
      'logoUrl': logoUrl,
      'receipt': receipt.toMap(),
      'modules': modules.toMap(),
      'dashboard': dashboard.toMap(),
      'syncSettings': syncSettings.toMap(),
      'counters': counters,
      'kds': kds.toMap(),
      'payment': payment.toMap(),
    };
  }

  StoreSettings copyWith({
    String? id,
    String? storeName,
    String? address,
    String? phone,
    String? logoUrl,
    ReceiptSettings? receipt,
    ModuleSettings? modules,
    DashboardSettings? dashboard,
    SyncSettings? syncSettings,
    List<String>? counters,
    KdsSettings? kds,
    String? storeType,
    PaymentSettings? payment,
  }) {
    return StoreSettings(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      receipt: receipt ?? this.receipt,
      modules: modules ?? this.modules,
      dashboard: dashboard ?? this.dashboard,
      syncSettings: syncSettings ?? this.syncSettings,
      counters: counters ?? this.counters,
      kds: kds ?? this.kds,
      payment: payment ?? this.payment,
    );
  }
}

class ReceiptTextStyle {
  final int size; // 0=Small, 1=Normal, 2=Large
  final bool isBold;
  // final bool isItalic; // Removed

  const ReceiptTextStyle({
    this.size = 1,
    this.isBold = false,
    // this.isItalic = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'isBold': isBold,
      // 'isItalic': isItalic,
    };
  }

  factory ReceiptTextStyle.fromMap(Map map) {
    return ReceiptTextStyle(
      size: map['size'] ?? 1,
      isBold: map['isBold'] ?? false,
      // isItalic: map['isItalic'] ?? false, // Removed
    );
  }
}

class ReceiptSettings {
  final String header;
  final String footer;
  final bool showLogo;
  final bool showTaxDetails;
  final bool showTokenNo;
  final int receiptWidth; // 58 or 80
  
  // Advanced Visibility Toggles
  final bool showStoreName;
  final bool showAddress;
  final bool showPhone;
  final bool showOrderNo; // Bill No
  final bool showDiscount;
  final bool showFooter;
  final bool showQr;
  final String upsellMessage; // "Try our new x!"
  final String customHeaderMessage;
  final String qrData;
  final String printAction; // 'Main', 'KDS', 'Both'

  // Typography
  final ReceiptTextStyle prominentStyle;
  final ReceiptTextStyle headerStyle;
  final ReceiptTextStyle regularStyle;

  ReceiptSettings({
    this.header = '',
    this.footer = '',
    this.showLogo = true,
    this.showTaxDetails = true,
    this.showTokenNo = true,
    this.receiptWidth = 58,
    this.showStoreName = true,
    this.showAddress = true,
    this.showPhone = true,
    this.showOrderNo = true,
    this.showDiscount = true,
    this.showFooter = true,
    this.showQr = false,
    this.upsellMessage = '',
    this.customHeaderMessage = '',
    this.qrData = '',
    this.printAction = 'Main',
    this.prominentStyle = const ReceiptTextStyle(size: 0, isBold: false),
    this.headerStyle = const ReceiptTextStyle(size: 0, isBold: false),
    this.regularStyle = const ReceiptTextStyle(size: 0),
  });

  factory ReceiptSettings.fromMap(Map data) {
    return ReceiptSettings(
      header: data['header'] ?? '',
      footer: data['footer'] ?? '',
      showLogo: data['showLogo'] ?? true,
      showTaxDetails: data['showTaxDetails'] ?? true,
      showTokenNo: data['showTokenNo'] ?? true,
      receiptWidth: data['receiptWidth'] ?? 58,
      showStoreName: data['showStoreName'] ?? true,
      showAddress: data['showAddress'] ?? true,
      showPhone: data['showPhone'] ?? true,
      showOrderNo: data['showOrderNo'] ?? true,
      showDiscount: data['showDiscount'] ?? true,
      showFooter: data['showFooter'] ?? true,
      showQr: data['showQr'] ?? false,
      upsellMessage: data['upsellMessage'] ?? '',
      customHeaderMessage: data['customHeaderMessage'] ?? '',
      qrData: data['qrData'] ?? '',
      printAction: data['printAction'] ?? 'Main',
      prominentStyle: data['prominentStyle'] != null 
          ? ReceiptTextStyle.fromMap(data['prominentStyle']) 
          : const ReceiptTextStyle(size: 0, isBold: false),
      headerStyle: data['headerStyle'] != null 
          ? ReceiptTextStyle.fromMap(data['headerStyle']) 
          : const ReceiptTextStyle(size: 0, isBold: false),
      regularStyle: data['regularStyle'] != null 
          ? ReceiptTextStyle.fromMap(data['regularStyle']) 
          : const ReceiptTextStyle(size: 0),
    );
  }

  Map<String, dynamic> toMap() => {
    'header': header,
    'footer': footer,
    'showLogo': showLogo,
    'showTaxDetails': showTaxDetails,
    'showTokenNo': showTokenNo,
    'receiptWidth': receiptWidth,
    'showStoreName': showStoreName,
    'showAddress': showAddress,
    'showPhone': showPhone,
    'showOrderNo': showOrderNo,
    'showDiscount': showDiscount,
    'showFooter': showFooter,
    'showQr': showQr,
    'upsellMessage': upsellMessage,
    'customHeaderMessage': customHeaderMessage,
    'qrData': qrData,
    'printAction': printAction,
    'prominentStyle': prominentStyle.toMap(),
    'headerStyle': headerStyle.toMap(),
    'regularStyle': regularStyle.toMap(),
  };

  ReceiptSettings copyWith({
    String? header,
    String? footer,
    bool? showLogo,
    bool? showTaxDetails,
    bool? showTokenNo,
    int? receiptWidth,
    bool? showStoreName,
    bool? showAddress,
    bool? showPhone,
    bool? showOrderNo,
    bool? showDiscount,
    bool? showFooter,
    bool? showQr,
    String? upsellMessage,
    String? customHeaderMessage,
    String? qrData,
    String? printAction,
    ReceiptTextStyle? prominentStyle,
    ReceiptTextStyle? headerStyle,
    ReceiptTextStyle? regularStyle,
  }) {
    return ReceiptSettings(
      header: header ?? this.header,
      footer: footer ?? this.footer,
      showLogo: showLogo ?? this.showLogo,
      showTaxDetails: showTaxDetails ?? this.showTaxDetails,
      showTokenNo: showTokenNo ?? this.showTokenNo,
      receiptWidth: receiptWidth ?? this.receiptWidth,
      showStoreName: showStoreName ?? this.showStoreName,
      showAddress: showAddress ?? this.showAddress,
      showPhone: showPhone ?? this.showPhone,
      showOrderNo: showOrderNo ?? this.showOrderNo,
      showDiscount: showDiscount ?? this.showDiscount,
      showFooter: showFooter ?? this.showFooter,
      showQr: showQr ?? this.showQr,
      upsellMessage: upsellMessage ?? this.upsellMessage,
      customHeaderMessage: customHeaderMessage ?? this.customHeaderMessage,
      qrData: qrData ?? this.qrData,
      printAction: printAction ?? this.printAction,
      prominentStyle: prominentStyle ?? this.prominentStyle,
      headerStyle: headerStyle ?? this.headerStyle,
      regularStyle: regularStyle ?? this.regularStyle,
    );
  }
}

class ModuleSettings {
  final bool pos;
  final bool kds;
  final bool tableManagement;
  final bool inventory;
  final bool customers;
  final bool reports;

  ModuleSettings({
    this.pos = true,
    this.kds = false,
    this.tableManagement = false,
    this.inventory = true,
    this.customers = true,
    this.reports = true,
  });

  factory ModuleSettings.fromMap(Map data) {
    return ModuleSettings(
      pos: data['pos'] ?? true,
      kds: data['kds'] ?? false,
      tableManagement: data['tableManagement'] ?? false,
      inventory: data['inventory'] ?? true,
      customers: data['customers'] ?? true,
      reports: data['reports'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'pos': pos,
    'kds': kds,
    'tableManagement': tableManagement,
    'inventory': inventory,
    'customers': customers,
    'reports': reports,
  };
}

class DashboardSettings {
  final String theme;

  DashboardSettings({this.theme = 'classic'});

  factory DashboardSettings.fromMap(Map data) {
    return DashboardSettings(
      theme: data['theme'] ?? 'classic',
    );
  }

  Map<String, dynamic> toMap() => {'theme': theme};
}

class SyncSettings {
  final String interval; // 'Immediate', '1 Day', '7 Days'
  final bool autoSync;

  SyncSettings({this.interval = 'Immediate', this.autoSync = true});

  factory SyncSettings.fromMap(Map data) {
    return SyncSettings(
      interval: data['interval'] ?? 'Immediate',
      autoSync: data['autoSync'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'interval': interval,
    'autoSync': autoSync,
  };
}

class KdsSettings {
  final bool soundEnabled;
  final double fontSize;
  final String layout; // 'Grid', 'List'
  final List<String> categoryFilters;

  KdsSettings({
    this.soundEnabled = true,
    this.fontSize = 16.0,
    this.layout = 'Grid',
    this.categoryFilters = const [],
  });

  factory KdsSettings.fromMap(Map data) {
    return KdsSettings(
      soundEnabled: data['soundEnabled'] ?? true,
      fontSize: (data['fontSize'] ?? 16.0).toDouble(),
      layout: data['layout'] ?? 'Grid',
      categoryFilters: (data['categoryFilters'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() => {
    'soundEnabled': soundEnabled,
    'fontSize': fontSize,
    'layout': layout,
    'categoryFilters': categoryFilters,
  };

  KdsSettings copyWith({
    bool? soundEnabled,
    double? fontSize,
    String? layout,
    List<String>? categoryFilters,
  }) {
    return KdsSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      fontSize: fontSize ?? this.fontSize,
      layout: layout ?? this.layout,
      categoryFilters: categoryFilters ?? this.categoryFilters,
    );
  }
}

class PaymentSettings {
  final String upiId;
  final String upiName;

  PaymentSettings({
    this.upiId = '',
    this.upiName = '',
  });

  factory PaymentSettings.fromMap(Map data) {
    return PaymentSettings(
      upiId: data['upiId'] ?? '',
      upiName: data['upiName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'upiId': upiId,
    'upiName': upiName,
  };
  
  PaymentSettings copyWith({
    String? upiId,
    String? upiName,
  }) {
    return PaymentSettings(
      upiId: upiId ?? this.upiId,
      upiName: upiName ?? this.upiName,
    );
  }
}

