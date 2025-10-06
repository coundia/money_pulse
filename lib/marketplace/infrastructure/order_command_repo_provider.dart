// Riverpod provider for OrderCommandRepository (inject baseUri).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_command_repository.dart';

final orderCommandRepoProvider =
    Provider.family<OrderCommandRepository, String>((ref, baseUri) {
      return OrderCommandRepository(baseUri: baseUri);
    });
