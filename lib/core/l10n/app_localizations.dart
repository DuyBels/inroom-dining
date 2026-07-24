import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppDictionary {
  final String room;
  final String cart;
  final String orderNow;
  final String checkout;
  final String total;
  final String aiSuggestion;
  final String all;
  final String login;
  final String logout;
  final String pending;
  final String cooking;
  final String done;
  final String ready;
  final String delivery;
  final String callStaff;
  final String cleaning;
  final String history;
  final String price;
  final String prepTime;
  final String notes;
  final String addDelay;
  final String startCooking;
  final String cookingDone;
  final String confirmOrder;
  final String aiAssistant;
  final String aiIntro;
  final String cool;
  final String warm;
  final String estimatedFinish;
  final String includeDelivery;
  final String specialNotes;
  final String requiredLabel;
  final String selectQuantity;
  final String selectFullLabel;
  final String checkOrderList;
  final String changeLabel;
  final String sendRequest;
  final String totalPayment;
  final String orderReceived;
  final String orderPreparing;
  final String orderDelivering;
  final String emptyCart;
  final String extra;
  final String cleaningRequest;
  final String supportRequest;
  final String waitingStaff;
  final String staffProcessing;
  final String allergyWarning;
  final String noOptions;
  final String loadingOptions;
  final String errorLoading;
  final String minute;
  final String close;
  final String confirm;
  final String cancel;
  final String orderSuccess;
  final String enjoyMeal;
  final String kitchenTitle;
  final String pendingColumn;
  final String cookingColumn;
  final String waiterTitle;
  final String staffLabel;
  final String cleaningTask;
  final String supportTask;
  final String takeTask;
  final String confirmDone;
  final String alreadyTaken;
  final String historyTitle;
  final String deliveryTab;
  final String cleaningTab;
  final String totalBill;
  final String totalItem;
  final String chatGroup;
  final String typeMessage;
  final String searchHint;
  final String searchTypewriter;
  // New phrases for Kitchen and History
  final String overtime;
  final String finishIn;
  final String startIn;
  final String cookNow;
  final String waitPrimary;
  final String orderNo;
  final String atTime;

  AppDictionary({
    required this.room,
    required this.cart,
    required this.orderNow,
    required this.checkout,
    required this.total,
    required this.aiSuggestion,
    required this.all,
    required this.login,
    required this.logout,
    required this.pending,
    required this.cooking,
    required this.done,
    required this.ready,
    required this.delivery,
    required this.callStaff,
    required this.cleaning,
    required this.history,
    required this.price,
    required this.prepTime,
    required this.notes,
    required this.addDelay,
    required this.startCooking,
    required this.cookingDone,
    required this.confirmOrder,
    required this.aiAssistant,
    required this.aiIntro,
    required this.cool,
    required this.warm,
    required this.estimatedFinish,
    required this.includeDelivery,
    required this.specialNotes,
    required this.requiredLabel,
    required this.selectQuantity,
    required this.selectFullLabel,
    required this.checkOrderList,
    required this.changeLabel,
    required this.sendRequest,
    required this.totalPayment,
    required this.orderReceived,
    required this.orderPreparing,
    required this.orderDelivering,
    required this.emptyCart,
    required this.extra,
    required this.cleaningRequest,
    required this.supportRequest,
    required this.waitingStaff,
    required this.staffProcessing,
    required this.allergyWarning,
    required this.noOptions,
    required this.loadingOptions,
    required this.errorLoading,
    required this.minute,
    required this.close,
    required this.confirm,
    required this.cancel,
    required this.orderSuccess,
    required this.enjoyMeal,
    required this.kitchenTitle,
    required this.pendingColumn,
    required this.cookingColumn,
    required this.waiterTitle,
    required this.staffLabel,
    required this.cleaningTask,
    required this.supportTask,
    required this.takeTask,
    required this.confirmDone,
    required this.alreadyTaken,
    required this.historyTitle,
    required this.deliveryTab,
    required this.cleaningTab,
    required this.totalBill,
    required this.totalItem,
    required this.chatGroup,
    required this.typeMessage,
    required this.searchHint,
    required this.searchTypewriter,
    required this.overtime,
    required this.finishIn,
    required this.startIn,
    required this.cookNow,
    required this.waitPrimary,
    required this.orderNo,
    required this.atTime,
  });
}

final viDict = AppDictionary(
  room: "PHÒNG",
  cart: "GIỎ HÀNG",
  orderNow: "ĐẶT MÓN NGAY",
  checkout: "Thanh toán",
  total: "TỔNG CỘNG",
  aiSuggestion: "AI GỢI Ý",
  all: "Tất cả",
  login: "Đăng nhập",
  logout: "Đăng xuất",
  pending: "Đang chờ",
  cooking: "Đang nấu",
  done: "Hoàn tất",
  ready: "SẴN SÀNG",
  delivery: "Đang giao",
  callStaff: "GỌI NV",
  cleaning: "DỌN BÀN",
  history: "Lịch sử",
  price: "Giá",
  prepTime: "T.Gian",
  notes: "Ghi chú",
  addDelay: "Delay",
  startCooking: "BẮT ĐẦU NẤU",
  cookingDone: "NẤU XONG",
  confirmOrder: "Xác nhận Đặt món",
  aiAssistant: "Trợ lý ảo AI",
  aiIntro: "Chào bạn! Để AI gợi ý món phù hợp nhất, hôm nay bạn thấy thế nào?",
  cool: "Thanh mát",
  warm: "Ấm nóng",
  estimatedFinish: "Dự kiến hoàn thành sau khoảng",
  includeDelivery: "Bao gồm thời gian nấu & 5 phút giao hàng",
  specialNotes: "GHI CHÚ ĐẶC BIỆT",
  requiredLabel: "BẮT BUỘC",
  selectQuantity: "Chọn lựa chọn",
  selectFullLabel: "VUI LÒNG CHỌN ĐỦ",
  checkOrderList: "Kiểm tra lại danh sách món ăn",
  changeLabel: "Thay đổi",
  sendRequest: "Gửi yêu cầu",
  totalPayment: "Tổng thanh toán",
  orderReceived: "Nhà bếp đã nhận đơn hàng của bạn.",
  orderPreparing: "Đầu bếp đang cẩn thận chế biến...",
  orderDelivering: "Nhân viên đang mang đồ lên phòng bạn!",
  emptyCart: "Giỏ hàng trống",
  extra: "Thêm",
  cleaningRequest: "Yêu cầu dọn bàn",
  supportRequest: "Yêu cầu hỗ trợ",
  waitingStaff: "Đang chờ nhân viên nhận...",
  staffProcessing: "Nhân viên đang xử lý",
  allergyWarning: "CẢNH BÁO DỊ ỨNG",
  noOptions: "Món ăn này không có tùy chọn thêm.",
  loadingOptions: "Đang tải tùy chọn...",
  errorLoading: "Lỗi tải dữ liệu. Vui lòng thử lại.",
  minute: "phút",
  close: "ĐÓNG",
  confirm: "XÁC NHẬN",
  cancel: "HỦY",
  orderSuccess: "Đặt món thành công!",
  enjoyMeal: "Chúc ngon miệng! Đơn hàng đã được giao.",
  kitchenTitle: "BẾP",
  pendingColumn: "CHỜ CHẾ BIẾN",
  cookingColumn: "ĐANG NẤU",
  waiterTitle: "ĐIỀU PHỐI CÔNG VIỆC",
  staffLabel: "Nhân viên",
  cleaningTask: "CẦN DỌN DẸP",
  supportTask: "KHÁCH CẦN HỖ TRỢ",
  takeTask: "NHẬN NHIỆM VỤ",
  confirmDone: "XÁC NHẬN XONG",
  alreadyTaken: "ĐÃ CÓ NGƯỜI NHẬN",
  historyTitle: "LỊCH SỬ",
  deliveryTab: "GIAO MÓN",
  cleaningTab: "DỌN BÀN",
  totalBill: "TỔNG BILL",
  totalItem: "TỔNG MÓN",
  chatGroup: "NHÓM PHỤC VỤ",
  typeMessage: "Nhập tin nhắn...",
  searchHint: "Tìm kiếm món ăn...",
  searchTypewriter: "Bạn thích những món nào...",
  overtime: "QUÁ GIỜ",
  finishIn: "Xong sau",
  startIn: "Bắt đầu sau",
  cookNow: "NẤU NGAY!",
  waitPrimary: "Chờ món chính...",
  orderNo: "Đơn hàng",
  atTime: "Lúc",
);

final enDict = AppDictionary(
  room: "ROOM",
  cart: "CART",
  orderNow: "ORDER NOW",
  checkout: "Checkout",
  total: "TOTAL",
  aiSuggestion: "AI SUGGESTIONS",
  all: "All",
  login: "Login",
  logout: "Logout",
  pending: "Pending",
  cooking: "Cooking",
  done: "Done",
  ready: "READY",
  delivery: "Delivery",
  callStaff: "CALL STAFF",
  cleaning: "CLEANING",
  history: "History",
  price: "Price",
  prepTime: "Prep Time",
  notes: "Notes",
  addDelay: "Delay",
  startCooking: "START COOKING",
  cookingDone: "FINISHED",
  confirmOrder: "Confirm Order",
  aiAssistant: "AI Assistant",
  aiIntro: "Hi! To help AI suggest the best meal, how do you feel today?",
  cool: "Cool",
  warm: "Warm",
  estimatedFinish: "Estimated completion in about",
  includeDelivery: "Includes prep time & 5 mins delivery",
  specialNotes: "SPECIAL NOTES",
  requiredLabel: "REQUIRED",
  selectQuantity: "Select options",
  selectFullLabel: "PLEASE SELECT ALL",
  checkOrderList: "Please check your order list",
  changeLabel: "Change",
  sendRequest: "Send Request",
  totalPayment: "Total Payment",
  orderReceived: "The kitchen has received your order.",
  orderPreparing: "The chef is carefully preparing...",
  orderDelivering: "Staff is bringing food to your room!",
  emptyCart: "Cart is empty",
  extra: "Extra",
  cleaningRequest: "Cleaning Request",
  supportRequest: "Support Request",
  waitingStaff: "Waiting for staff...",
  staffProcessing: "Staff is processing",
  allergyWarning: "ALLERGY WARNING",
  noOptions: "This item has no extra options.",
  loadingOptions: "Loading options...",
  errorLoading: "Error loading data. Please try again.",
  minute: "mins",
  close: "CLOSE",
  confirm: "CONFIRM",
  cancel: "CANCEL",
  orderSuccess: "Order placed successfully!",
  enjoyMeal: "Enjoy your meal! Order has been delivered.",
  kitchenTitle: "KITCHEN",
  pendingColumn: "PENDING",
  cookingColumn: "COOKING",
  waiterTitle: "JOB COORDINATION",
  staffLabel: "Staff",
  cleaningTask: "CLEANING NEEDED",
  supportTask: "SUPPORT NEEDED",
  takeTask: "ACCEPT TASK",
  confirmDone: "MARK AS DONE",
  alreadyTaken: "TAKEN",
  historyTitle: "HISTORY",
  deliveryTab: "DELIVERY",
  cleaningTab: "CLEANING",
  totalBill: "TOTAL BILL",
  totalItem: "ITEM TOTAL",
  chatGroup: "STAFF GROUP",
  typeMessage: "Type a message...",
  searchHint: "Search dishes...",
  searchTypewriter: "What would you like to eat...",
  overtime: "OVERTIME",
  finishIn: "Finish in",
  startIn: "Start in",
  cookNow: "COOK NOW!",
  waitPrimary: "Wait for primary...",
  orderNo: "Order",
  atTime: "At",
);

class LocaleNotifier extends Notifier<String> {
  @override
  String build() => 'vi'; // Mặc định là Tiếng Việt

  void setLocale(String code) {
    state = code;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

final l10nProvider = Provider<AppDictionary>((ref) {
  final locale = ref.watch(localeProvider);
  return (locale == 'vi') ? viDict : enDict;
});
