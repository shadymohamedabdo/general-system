import 'package:get/get.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/employees_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/login_controller.dart';
import 'controllers/monthly_report_controller.dart';
import 'controllers/products_controller.dart';
import 'controllers/profit_controller.dart';
import 'controllers/sales_controller.dart';
import 'controllers/shift_manage_controller.dart';
import 'controllers/shift_report_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginController>(() => LoginController());
  }
}

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}

class EmployeesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeesController>(() => EmployeesController(), fenix: true);
  }
}

class ProductsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductsController>(() => ProductsController(), fenix: true);
  }
}

class ShiftBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShiftsController>(() => ShiftsController(), fenix: true);
  }
}

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(() => DashboardController(), fenix: true);
  }
}

class MonthlyReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MonthlyReportController>(() => MonthlyReportController(), fenix: true);
  }
}

class CalculatorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfitController>(() => ProfitController(), fenix: true);
  }
}

class ShiftReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShiftReportController>(() => ShiftReportController(), fenix: true);
  }
}

class AddSaleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SalesController>(() => SalesController(), fenix: true);
  }
}