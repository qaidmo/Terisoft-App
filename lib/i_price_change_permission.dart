import 'package:get/get.dart';

abstract class IPriceChangePermission {
  RxBool get canUserChangePrice;
}