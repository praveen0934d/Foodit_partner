import 'package:foodit_partner/data/repositories/partner_auth_repository.dart';
import 'package:foodit_partner/services/partner_auth_service.dart';
import 'package:foodit_partner/models/partner_model.dart';

class PartnerAuthRepositoryImpl implements PartnerAuthRepository {
  final PartnerAuthService _remoteDataSource;

  PartnerAuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<PartnerUser> signInWithGoogle() => _remoteDataSource.signInWithGoogle();

  @override
  Future<void> logout() => _remoteDataSource.logout();

  @override
  Future<PartnerUser?> validateToken() => _remoteDataSource.validateToken();

  @override
  Future<void> saveUserLocally(PartnerUser user) => _remoteDataSource.saveUserLocally(user);
}
