// Request model for posting an order (API v1 /commands/order). Only non-null fields are sent.

class OrderCommandRequest {
  final String productId;
  final String? userId;
  final String identifiant;
  final String? telephone;
  final String? mail;
  final String? ville;
  final String? remoteId;
  final String? localId;
  final String? status;
  final String? buyerName;
  final String? address;
  final String? notes;
  final String? message;
  final String? typeOrder;
  final String? paymentMethod;
  final String? deliveryMethod;
  final num amountCents; // API sample shows a number (can be int/decimal)
  final int quantity;
  final DateTime dateCommand;

  const OrderCommandRequest({
    required this.productId,
    required this.identifiant,
    required this.amountCents,
    required this.quantity,
    required this.dateCommand,
    this.userId,
    this.telephone,
    this.mail,
    this.ville,
    this.remoteId,
    this.localId,
    this.status,
    this.buyerName,
    this.address,
    this.notes,
    this.message,
    this.typeOrder,
    this.paymentMethod,
    this.deliveryMethod,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'productId': productId,
      'identifiant': identifiant,
      'amountCents': amountCents,
      'quantity': quantity,
      'dateCommand': dateCommand.toUtc().toIso8601String(),
      if (userId != null) 'userId': userId,
      if (telephone != null) 'telephone': telephone,
      if (mail != null) 'mail': mail,
      if (ville != null) 'ville': ville,
      if (remoteId != null) 'remoteId': remoteId,
      if (localId != null) 'localId': localId,
      if (status != null) 'status': status,
      if (buyerName != null) 'buyerName': buyerName,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      if (message != null) 'message': message,
      if (typeOrder != null) 'typeOrder': typeOrder,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
    };
    return m;
  }
}
