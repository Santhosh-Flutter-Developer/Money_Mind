import 'package:get/get.dart';

/// Lets long-lived controllers clear their data when the user logs out.
class AppEvents extends GetxService {
  final logoutTick = 0.obs;
  void loggedOut() => logoutTick.value++;
}
