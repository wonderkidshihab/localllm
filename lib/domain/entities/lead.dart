class Lead {
  final String id;
  final String businessName;
  final String contactInfo;
  final String marketingGaps;
  final String source;

  Lead({
    required this.id,
    required this.businessName,
    required this.contactInfo,
    required this.marketingGaps,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessName': businessName,
      'contactInfo': contactInfo,
      'marketingGaps': marketingGaps,
      'source': source,
    };
  }

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'] ?? '',
      businessName: map['businessName'] ?? '',
      contactInfo: map['contactInfo'] ?? '',
      marketingGaps: map['marketingGaps'] ?? '',
      source: map['source'] ?? '',
    );
  }
  
  List<dynamic> toSheetRow() {
    return [businessName, contactInfo, marketingGaps, source, DateTime.now().toIso8601String()];
  }
}
