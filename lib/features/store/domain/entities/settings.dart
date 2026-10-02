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
  final CustomerAddonSettings customerSettings;

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
    this.customerSettings = const CustomerAddonSettings(),
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
      counters: (data['counters'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .toList() ??
          ['Main Counter'],
      kds: KdsSettings.fromMap(data['kds'] ?? {}),
      payment: PaymentSettings.fromMap(data['payment'] ?? {}),
      customerSettings:
          CustomerAddonSettings.fromMap(data['customerSettings'] ?? {}),
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
      'customerSettings': customerSettings.toMap(),
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
    CustomerAddonSettings? customerSettings,
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
      customerSettings: customerSettings ?? this.customerSettings,
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
      categoryFilters: (data['categoryFilters'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .toList() ??
          [],
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

class SeasonalCoupon {
  final String id;
  final String code;
  final String title;
  final String season;
  final String discountType; // 'percentage' or 'flat'
  final double discountValue; // percentage (e.g. 20) or flat amount (e.g. 100)
  final double minOrderValue;
  final double maxDiscount; // 0 for no cap
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  const SeasonalCoupon({
    required this.id,
    required this.code,
    required this.title,
    this.season = 'General',
    this.discountType = 'percentage',
    required this.discountValue,
    this.minOrderValue = 0.0,
    this.maxDiscount = 0.0,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  bool get isExpired {
    if (endDate != null) {
      final now = DateTime.now();
      final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      if (now.isAfter(endOfDay)) return true;
    }
    return false;
  }

  bool get isStarted {
    if (startDate != null) {
      final now = DateTime.now();
      final startOfDay = DateTime(startDate!.year, startDate!.month, startDate!.day, 0, 0, 0);
      if (now.isBefore(startOfDay)) return false;
    }
    return true;
  }

  bool get isValid => isActive && !isExpired && isStarted;

  double calculateDiscount(double orderTotal) {
    if (!isValid || orderTotal < minOrderValue) return 0.0;
    if (discountType == 'percentage') {
      double disc = orderTotal * (discountValue / 100.0);
      if (maxDiscount > 0 && disc > maxDiscount) {
        disc = maxDiscount;
      }
      return disc > orderTotal ? orderTotal : disc;
    } else {
      return discountValue > orderTotal ? orderTotal : discountValue;
    }
  }

  factory SeasonalCoupon.fromMap(Map data) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString());
    }

    return SeasonalCoupon(
      id: data['id']?.toString() ?? '',
      code: (data['code']?.toString() ?? '').toUpperCase().trim(),
      title: data['title']?.toString() ?? '',
      season: data['season']?.toString() ?? 'General',
      discountType: data['discountType']?.toString() ?? 'percentage',
      discountValue: (data['discountValue'] ?? 0.0).toDouble(),
      minOrderValue: (data['minOrderValue'] ?? 0.0).toDouble(),
      maxDiscount: (data['maxDiscount'] ?? 0.0).toDouble(),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'title': title,
        'season': season,
        'discountType': discountType,
        'discountValue': discountValue,
        'minOrderValue': minOrderValue,
        'maxDiscount': maxDiscount,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isActive': isActive,
      };

  SeasonalCoupon copyWith({
    String? id,
    String? code,
    String? title,
    String? season,
    String? discountType,
    double? discountValue,
    double? minOrderValue,
    double? maxDiscount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) {
    return SeasonalCoupon(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      season: season ?? this.season,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
    );
  }
}

class CustomerAddonSettings {
  // --- Udhari (Khata / Credit) Settings ---
  final bool enableUdhari;
  final double defaultCreditLimit;
  final bool allowPartialUdhari;
  final bool blockWhenLimitExceeded;
  final bool enableWhatsAppReminders;

  // --- Loyalty Points Program Settings ---
  final bool enableLoyalty;
  final double earnRateSpendAmount;
  final int earnRatePoints;
  final double pointRedemptionValue;
  final int minPointsToRedeem;
  final double maxBillDiscountPercent;
  final int pointsValidityDays;

  // --- Membership & Customer Tiers ---
  final bool enableMembership;
  final double silverMinSpend;
  final double silverMultiplier;
  final double goldMinSpend;
  final double goldMultiplier;
  final double platinumMinSpend;
  final double platinumMultiplier;

  // --- Coupons & Welcome Rewards ---
  final bool enableCoupons;
  final int welcomeBonusPoints;
  final List<SeasonalCoupon> seasonalCoupons;

  static List<SeasonalCoupon> get defaultSeasonalCoupons => [
        const SeasonalCoupon(
          id: 'coupon_festive_diwali',
          code: 'DIWALI20',
          title: 'Diwali Festive Dhamaka',
          season: 'Diwali / Festive',
          discountType: 'percentage',
          discountValue: 20.0,
          minOrderValue: 500.0,
          maxDiscount: 200.0,
          isActive: true,
        ),
        const SeasonalCoupon(
          id: 'coupon_summer_special',
          code: 'SUMMER50',
          title: 'Summer Chilled Savings',
          season: 'Summer',
          discountType: 'flat',
          discountValue: 50.0,
          minOrderValue: 300.0,
          maxDiscount: 50.0,
          isActive: true,
        ),
      ];

  const CustomerAddonSettings({
    this.enableUdhari = true,
    this.defaultCreditLimit = 5000.0,
    this.allowPartialUdhari = true,
    this.blockWhenLimitExceeded = false,
    this.enableWhatsAppReminders = true,
    this.enableLoyalty = true,
    this.earnRateSpendAmount = 100.0,
    this.earnRatePoints = 1,
    this.pointRedemptionValue = 1.0,
    this.minPointsToRedeem = 50,
    this.maxBillDiscountPercent = 50.0,
    this.pointsValidityDays = 365,
    this.enableMembership = true,
    this.silverMinSpend = 2000.0,
    this.silverMultiplier = 1.2,
    this.goldMinSpend = 5000.0,
    this.goldMultiplier = 1.5,
    this.platinumMinSpend = 10000.0,
    this.platinumMultiplier = 2.0,
    this.enableCoupons = true,
    this.welcomeBonusPoints = 50,
    this.seasonalCoupons = const [],
  });

  factory CustomerAddonSettings.fromMap(Map data) {
    List<SeasonalCoupon> parsedCoupons = [];
    if (data['seasonalCoupons'] is List) {
      parsedCoupons = (data['seasonalCoupons'] as List)
          .where((e) => e is Map)
          .map((e) => SeasonalCoupon.fromMap(e as Map))
          .toList();
    }
    if (parsedCoupons.isEmpty && data['enableCoupons'] == null) {
      // First time initialization
      parsedCoupons = CustomerAddonSettings.defaultSeasonalCoupons;
    }

    return CustomerAddonSettings(
      enableUdhari: data['enableUdhari'] ?? true,
      defaultCreditLimit:
          (data['defaultCreditLimit'] ?? 5000.0).toDouble(),
      allowPartialUdhari: data['allowPartialUdhari'] ?? true,
      blockWhenLimitExceeded: data['blockWhenLimitExceeded'] ?? false,
      enableWhatsAppReminders: data['enableWhatsAppReminders'] ?? true,
      enableLoyalty: data['enableLoyalty'] ?? true,
      earnRateSpendAmount:
          (data['earnRateSpendAmount'] ?? 100.0).toDouble(),
      earnRatePoints: (data['earnRatePoints'] ?? 1).toInt(),
      pointRedemptionValue:
          (data['pointRedemptionValue'] ?? 1.0).toDouble(),
      minPointsToRedeem: (data['minPointsToRedeem'] ?? 50).toInt(),
      maxBillDiscountPercent:
          (data['maxBillDiscountPercent'] ?? 50.0).toDouble(),
      pointsValidityDays: (data['pointsValidityDays'] ?? 365).toInt(),
      enableMembership: data['enableMembership'] ?? true,
      silverMinSpend: (data['silverMinSpend'] ?? 2000.0).toDouble(),
      silverMultiplier: (data['silverMultiplier'] ?? 1.2).toDouble(),
      goldMinSpend: (data['goldMinSpend'] ?? 5000.0).toDouble(),
      goldMultiplier: (data['goldMultiplier'] ?? 1.5).toDouble(),
      platinumMinSpend: (data['platinumMinSpend'] ?? 10000.0).toDouble(),
      platinumMultiplier: (data['platinumMultiplier'] ?? 2.0).toDouble(),
      enableCoupons: data['enableCoupons'] ?? true,
      welcomeBonusPoints: (data['welcomeBonusPoints'] ?? 50).toInt(),
      seasonalCoupons: parsedCoupons,
    );
  }

  Map<String, dynamic> toMap() => {
        'enableUdhari': enableUdhari,
        'defaultCreditLimit': defaultCreditLimit,
        'allowPartialUdhari': allowPartialUdhari,
        'blockWhenLimitExceeded': blockWhenLimitExceeded,
        'enableWhatsAppReminders': enableWhatsAppReminders,
        'enableLoyalty': enableLoyalty,
        'earnRateSpendAmount': earnRateSpendAmount,
        'earnRatePoints': earnRatePoints,
        'pointRedemptionValue': pointRedemptionValue,
        'minPointsToRedeem': minPointsToRedeem,
        'maxBillDiscountPercent': maxBillDiscountPercent,
        'pointsValidityDays': pointsValidityDays,
        'enableMembership': enableMembership,
        'silverMinSpend': silverMinSpend,
        'silverMultiplier': silverMultiplier,
        'goldMinSpend': goldMinSpend,
        'goldMultiplier': goldMultiplier,
        'platinumMinSpend': platinumMinSpend,
        'platinumMultiplier': platinumMultiplier,
        'enableCoupons': enableCoupons,
        'welcomeBonusPoints': welcomeBonusPoints,
        'seasonalCoupons': seasonalCoupons.map((c) => c.toMap()).toList(),
      };

  CustomerAddonSettings copyWith({
    bool? enableUdhari,
    double? defaultCreditLimit,
    bool? allowPartialUdhari,
    bool? blockWhenLimitExceeded,
    bool? enableWhatsAppReminders,
    bool? enableLoyalty,
    double? earnRateSpendAmount,
    int? earnRatePoints,
    double? pointRedemptionValue,
    int? minPointsToRedeem,
    double? maxBillDiscountPercent,
    int? pointsValidityDays,
    bool? enableMembership,
    double? silverMinSpend,
    double? silverMultiplier,
    double? goldMinSpend,
    double? goldMultiplier,
    double? platinumMinSpend,
    double? platinumMultiplier,
    bool? enableCoupons,
    int? welcomeBonusPoints,
    List<SeasonalCoupon>? seasonalCoupons,
  }) {
    return CustomerAddonSettings(
      enableUdhari: enableUdhari ?? this.enableUdhari,
      defaultCreditLimit: defaultCreditLimit ?? this.defaultCreditLimit,
      allowPartialUdhari: allowPartialUdhari ?? this.allowPartialUdhari,
      blockWhenLimitExceeded:
          blockWhenLimitExceeded ?? this.blockWhenLimitExceeded,
      enableWhatsAppReminders:
          enableWhatsAppReminders ?? this.enableWhatsAppReminders,
      enableLoyalty: enableLoyalty ?? this.enableLoyalty,
      earnRateSpendAmount: earnRateSpendAmount ?? this.earnRateSpendAmount,
      earnRatePoints: earnRatePoints ?? this.earnRatePoints,
      pointRedemptionValue:
          pointRedemptionValue ?? this.pointRedemptionValue,
      minPointsToRedeem: minPointsToRedeem ?? this.minPointsToRedeem,
      maxBillDiscountPercent:
          maxBillDiscountPercent ?? this.maxBillDiscountPercent,
      pointsValidityDays: pointsValidityDays ?? this.pointsValidityDays,
      enableMembership: enableMembership ?? this.enableMembership,
      silverMinSpend: silverMinSpend ?? this.silverMinSpend,
      silverMultiplier: silverMultiplier ?? this.silverMultiplier,
      goldMinSpend: goldMinSpend ?? this.goldMinSpend,
      goldMultiplier: goldMultiplier ?? this.goldMultiplier,
      platinumMinSpend: platinumMinSpend ?? this.platinumMinSpend,
      platinumMultiplier: platinumMultiplier ?? this.platinumMultiplier,
      enableCoupons: enableCoupons ?? this.enableCoupons,
      welcomeBonusPoints: welcomeBonusPoints ?? this.welcomeBonusPoints,
      seasonalCoupons: seasonalCoupons ?? this.seasonalCoupons,
    );
  }
}

