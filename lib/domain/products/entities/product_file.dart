// Entity for product_file row persisted in local database.
class ProductFile {
  final String id;
  final String productId;
  final String? remoteId;
  final String? localId;
  final String fileName;
  final String? mimeType;
  final String? filePath;
  final int? fileSize;
  final int isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final String? createdBy;
  final int version;
  final int isDirty;

  const ProductFile({
    required this.id,
    required this.productId,
    this.remoteId,
    this.localId,
    required this.fileName,
    this.mimeType,
    this.filePath,
    this.fileSize,
    this.isDefault = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.createdBy,
    this.version = 0,
    this.isDirty = 1,
  });

  Map<String, Object?> toMap() {
    String dt(DateTime? d) => d == null ? '' : d.toIso8601String();
    return {
      'id': id,
      'productId': productId,
      'remoteId': remoteId,
      'localId': localId,
      'fileName': fileName,
      'mimeType': mimeType,
      'filePath': filePath,
      'fileSize': fileSize,
      'isDefault': isDefault,
      'createdAt': dt(createdAt),
      'updatedAt': dt(updatedAt),
      'deletedAt': dt(deletedAt),
      'syncAt': dt(syncAt),
      'createdBy': createdBy,
      'version': version,
      'isDirty': isDirty,
    };
  }
}
