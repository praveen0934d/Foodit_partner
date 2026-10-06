import 'package:foodit_partner/models/partner_model.dart';

abstract class PartnerAuthRepository {
  Future<PartnerUser> signInWithGoogle();
  Future<void> logout();
  Future<PartnerUser?> validateToken();
  Future<void> saveUserLocally(PartnerUser user);
}
