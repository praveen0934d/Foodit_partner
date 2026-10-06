import 'package:get_it/get_it.dart';
import 'package:foodit_partner/services/partner_auth_service.dart';
import 'package:foodit_partner/services/api_client.dart';
import 'package:foodit_partner/data/repositories/partner_auth_repository.dart';
import 'package:foodit_partner/data/repositories/partner_auth_repository_impl.dart';
import 'package:foodit_partner/data/repositories/config_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Remote Data Source
  sl.registerLazySingleton(() {
    final service = PartnerAuthService();
    ApiClient.onDeepSilentLogin = service.silentReAuth;
    return service;
  });

  // Repository
  sl.registerLazySingleton<PartnerAuthRepository>(
    () => PartnerAuthRepositoryImpl(sl()),
  );
  
  sl.registerLazySingleton<ConfigRepository>(
    () => ConfigRepositoryImpl(),
  );
}
