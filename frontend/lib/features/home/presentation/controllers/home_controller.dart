import 'package:get/get.dart';

class HomeController extends GetxController {
  final _counter = 0.obs;

  int get counter => _counter.value;

  void incrementCounter() {
    _counter.value++;
  }
}
