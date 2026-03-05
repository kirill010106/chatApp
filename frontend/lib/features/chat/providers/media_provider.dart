import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/media_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) {
  final dioClient = ref.read(dioClientProvider);
  return MediaService(dioClient.dio);
});
