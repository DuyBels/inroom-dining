import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../web_helpers/web_isolation.dart';

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
  final String overtime;
  final String finishIn;
  final String startIn;
  final String cookNow;
  final String waitPrimary;
  final String orderNo;
  final String atTime;

  // Admin Panel Strings
  final String adminPanelTitle;
  final String accountsTab;
  final String stationsTab;
  final String categoriesTab;
  final String menuTab;
  final String tagsTab;
  final String adminHistoryTab;
  final String qrCodeTab;
  final String generateQrTitle;
  final String selectRoom;
  final String selectDuration;
  final String generateQrBtn;
  final String qrCodeCreated;
  final String qrExpiresAt;
  final String printQr;
  final String copyQrLink;
  final String revokeQr;
  final String qrExpiredTitle;
  final String qrExpiredMessage;
  final String addAccount;
  final String addStation;
  final String addCategory;
  final String addItem;
  final String addTag;
  final String manageAccounts;
  final String manageStations;
  final String manageCategories;
  final String manageMenu;
  final String manageTags;
  final String adminRole;
  final String roomRole;
  final String stationRole;
  final String waiterRole;
  final String displayName;
  final String roleLabel;
  final String actionsLabel;
  final String allTab;
  final String descriptionLabel;
  final String statusLabel;
  final String infoLabel;
  final String systemHistoryTitle;
  final String ordersTab;
  final String kitchenTab;
  final String staffTab;
  final String timeLabel;
  final String deliveryPersonLabel;
  final String performerLabel;
  final String requestedAtLabel;
  final String completedAtLabel;
  final String orderDetailsTitle;

  // ========== NEWLY ADDED KEYS ==========

  // Common UI
  final String save;
  final String delete;
  final String edit;
  final String errorPrefix;
  final String unknownError;
  final String confirmDeleteTitle;
  final String pleaseLogin;
  final String noPermission;
  final String confirmDeleteBtn;
  final String noNameSet;
  final String notePrefix;

  // Login Screen
  final String systemTitle;
  final String username;
  final String password;
  final String loginButton;
  final String debugMode;

  // Account Form Dialog
  final String addAccountTitle;
  final String editAccountTitle;
  final String loginEmail;
  final String passwordMinLength;
  final String validEmail;
  final String validPassword;
  final String validName;
  final String validRoom;
  final String validStation;
  final String serverError;
  final String roomNumberInput;
  final String selectStationLabel;
  final String changePasswordLabel;
  final String changePasswordHelper;
  final String deleteAccountConfirm;
  final String deleteAccountSuccess;
  final String systemError;
  final String roomDeviceLabel;

  // Room Checkout
  final String checkoutRoomTitle;
  final String checkoutRoomConfirm;
  final String checkoutRoomSuccess;
  final String confirmCheckoutBtn;
  final String editAccountTooltip;
  final String deleteAccountTooltip;
  final String checkoutRoomTooltip;

  // Category Form
  final String editCategory;
  final String categoryNameLang;
  final String descriptionLang;
  final String deleteCategoryConfirm;
  final String cannotDeleteCategory;

  // Station Form
  final String editStation;
  final String stationNameLang;
  final String validStationName;
  final String aiTranslateTooltip;
  final String deleteStationConfirm;
  final String stationDeleted;
  final String cannotDeleteStation;
  final String editStationTooltip;
  final String deleteStationTooltip;

  // Tag Form
  final String editTag;
  final String tagNameLang;
  final String tagTypeLabel;
  final String allergyType;
  final String weatherType;
  final String timeType;
  final String tasteType;
  final String deleteTagConfirm;

  // Menu Form
  final String addItemTitle;
  final String editItem;
  final String itemNameLang;
  final String priceLabel;
  final String cookTimeLabel;
  final String categoryLabel;
  final String stationLabel;
  final String descriptionFieldLang;
  final String attachTag;
  final String availabilityStatus;
  final String chooseImage;
  final String saveItem;
  final String deleteItemConfirm;
  final String manageToppingTooltip;

  // Modifier Management Dialog
  final String customization;
  final String addNewGroup;
  final String noCustomizations;
  final String requiredYes;
  final String requiredNo;
  final String maxSelect;
  final String addOption;
  final String addGroupTitle;
  final String editGroupTitle;
  final String groupNameLang;
  final String minSelectLabel;
  final String maxSelectLabel;
  final String addOptionTitle;
  final String editOptionTitle;
  final String optionNameLang;
  final String extraPrice;
  final String deleteGroupTitle;
  final String deleteGroupConfirm;
  final String deleteOptionTitle;
  final String deleteOptionConfirm;
  final String errorSaveGroup;
  final String errorDeleteGroup;
  final String errorSaveOption;
  final String errorDeleteOption;

  // Kitchen Screen
  final String updateError;
  final String stationNotAssigned;
  final String stationNotExist;
  final String loadStationError;
  final String empty;
  final String warningTitle;
  final String notCookingTime;
  final String primaryNotDone;
  final String continueQuestion;
  final String stillCook;

  // Waiter Screen
  final String deliverySuccess;
  final String taskDone;
  final String viewAction;
  final String dishReady;
  final String roomServiceNotify;
  final String authError;
  final String loadDataError;
  final String noRequests;
  final String noHistory;

  // Room Menu / Cart
  final String specialInstructions;
  final String loadMenuError;
  final String supportQuestion;
  final String supportHint;
  final String roomCleaningCalled;
  final String staffCalled;
  final String roomServiceLabel;
  final String menuItemFallback;
  final String errorTranslate;

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
    required this.adminPanelTitle,
    required this.accountsTab,
    required this.stationsTab,
    required this.categoriesTab,
    required this.menuTab,
    required this.tagsTab,
    required this.adminHistoryTab,
    required this.qrCodeTab,
    required this.generateQrTitle,
    required this.selectRoom,
    required this.selectDuration,
    required this.generateQrBtn,
    required this.qrCodeCreated,
    required this.qrExpiresAt,
    required this.printQr,
    required this.copyQrLink,
    required this.revokeQr,
    required this.qrExpiredTitle,
    required this.qrExpiredMessage,
    required this.addAccount,
    required this.addStation,
    required this.addCategory,
    required this.addItem,
    required this.addTag,
    required this.manageAccounts,
    required this.manageStations,
    required this.manageCategories,
    required this.manageMenu,
    required this.manageTags,
    required this.adminRole,
    required this.roomRole,
    required this.stationRole,
    required this.waiterRole,
    required this.displayName,
    required this.roleLabel,
    required this.actionsLabel,
    required this.allTab,
    required this.descriptionLabel,
    required this.statusLabel,
    required this.infoLabel,
    required this.systemHistoryTitle,
    required this.ordersTab,
    required this.kitchenTab,
    required this.staffTab,
    required this.timeLabel,
    required this.deliveryPersonLabel,
    required this.performerLabel,
    required this.requestedAtLabel,
    required this.completedAtLabel,
    required this.orderDetailsTitle,
    // New keys
    required this.save,
    required this.delete,
    required this.edit,
    required this.errorPrefix,
    required this.unknownError,
    required this.confirmDeleteTitle,
    required this.pleaseLogin,
    required this.noPermission,
    required this.confirmDeleteBtn,
    required this.noNameSet,
    required this.notePrefix,
    required this.systemTitle,
    required this.username,
    required this.password,
    required this.loginButton,
    required this.debugMode,
    required this.addAccountTitle,
    required this.editAccountTitle,
    required this.loginEmail,
    required this.passwordMinLength,
    required this.validEmail,
    required this.validPassword,
    required this.validName,
    required this.validRoom,
    required this.validStation,
    required this.serverError,
    required this.roomNumberInput,
    required this.selectStationLabel,
    required this.changePasswordLabel,
    required this.changePasswordHelper,
    required this.deleteAccountConfirm,
    required this.deleteAccountSuccess,
    required this.systemError,
    required this.roomDeviceLabel,
    required this.checkoutRoomTitle,
    required this.checkoutRoomConfirm,
    required this.checkoutRoomSuccess,
    required this.confirmCheckoutBtn,
    required this.editAccountTooltip,
    required this.deleteAccountTooltip,
    required this.checkoutRoomTooltip,
    required this.editCategory,
    required this.categoryNameLang,
    required this.descriptionLang,
    required this.deleteCategoryConfirm,
    required this.cannotDeleteCategory,
    required this.editStation,
    required this.stationNameLang,
    required this.validStationName,
    required this.aiTranslateTooltip,
    required this.deleteStationConfirm,
    required this.stationDeleted,
    required this.cannotDeleteStation,
    required this.editStationTooltip,
    required this.deleteStationTooltip,
    required this.editTag,
    required this.tagNameLang,
    required this.tagTypeLabel,
    required this.allergyType,
    required this.weatherType,
    required this.timeType,
    required this.tasteType,
    required this.deleteTagConfirm,
    required this.addItemTitle,
    required this.editItem,
    required this.itemNameLang,
    required this.priceLabel,
    required this.cookTimeLabel,
    required this.categoryLabel,
    required this.stationLabel,
    required this.descriptionFieldLang,
    required this.attachTag,
    required this.availabilityStatus,
    required this.chooseImage,
    required this.saveItem,
    required this.deleteItemConfirm,
    required this.manageToppingTooltip,
    required this.customization,
    required this.addNewGroup,
    required this.noCustomizations,
    required this.requiredYes,
    required this.requiredNo,
    required this.maxSelect,
    required this.addOption,
    required this.addGroupTitle,
    required this.editGroupTitle,
    required this.groupNameLang,
    required this.minSelectLabel,
    required this.maxSelectLabel,
    required this.addOptionTitle,
    required this.editOptionTitle,
    required this.optionNameLang,
    required this.extraPrice,
    required this.deleteGroupTitle,
    required this.deleteGroupConfirm,
    required this.deleteOptionTitle,
    required this.deleteOptionConfirm,
    required this.errorSaveGroup,
    required this.errorDeleteGroup,
    required this.errorSaveOption,
    required this.errorDeleteOption,
    required this.updateError,
    required this.stationNotAssigned,
    required this.stationNotExist,
    required this.loadStationError,
    required this.empty,
    required this.warningTitle,
    required this.notCookingTime,
    required this.primaryNotDone,
    required this.continueQuestion,
    required this.stillCook,
    required this.deliverySuccess,
    required this.taskDone,
    required this.viewAction,
    required this.dishReady,
    required this.roomServiceNotify,
    required this.authError,
    required this.loadDataError,
    required this.noRequests,
    required this.noHistory,
    required this.specialInstructions,
    required this.loadMenuError,
    required this.supportQuestion,
    required this.supportHint,
    required this.roomCleaningCalled,
    required this.staffCalled,
    required this.roomServiceLabel,
    required this.menuItemFallback,
    required this.errorTranslate,
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
  adminPanelTitle: "Bảng Điều Khiển Admin",
  accountsTab: "Tài khoản",
  stationsTab: "Trạm bếp",
  categoriesTab: "Danh mục",
  menuTab: "Thực đơn",
  tagsTab: "Thẻ dữ liệu",
  adminHistoryTab: "Lịch sử",
  qrCodeTab: "Mã QR Phòng",
  generateQrTitle: "Tạo Mã QR Tự Đăng Nhập",
  selectRoom: "Chọn số phòng",
  selectDuration: "Thời gian sử dụng mã QR",
  generateQrBtn: "Tạo mã QR",
  qrCodeCreated: "Mã QR cho phòng",
  qrExpiresAt: "Hạn sử dụng",
  printQr: "In mã QR",
  copyQrLink: "Sao chép Link",
  revokeQr: "Vô hiệu hóa QR",
  qrExpiredTitle: "Mã QR đã hết hạn",
  qrExpiredMessage: "Thời gian sử dụng mã QR phòng này đã kết thúc. Vui lòng liên hệ lễ tân để nhận mã QR mới.",
  addAccount: "Thêm Tài Khoản",
  addStation: "Thêm Trạm Bếp",
  addCategory: "Thêm Danh Mục",
  addItem: "Thêm Món Mới",
  addTag: "Thêm Thẻ Mới",
  manageAccounts: "Quản lý Tài khoản",
  manageStations: "Quản lý Trạm Bếp",
  manageCategories: "Quản lý Danh mục",
  manageMenu: "Quản lý Thực đơn",
  manageTags: "Quản lý Thẻ",
  adminRole: "Quản trị",
  roomRole: "Phòng",
  stationRole: "Bếp",
  waiterRole: "Phục vụ",
  displayName: "Tên hiển thị",
  roleLabel: "Phân quyền",
  actionsLabel: "Hành động",
  allTab: "Tất cả",
  descriptionLabel: "Mô tả",
  statusLabel: "Trạng thái",
  infoLabel: "Thông tin",
  systemHistoryTitle: "Lịch Sử Hoạt Động Toàn Hệ Thống",
  ordersTab: "Đơn hàng (Phòng)",
  kitchenTab: "Bếp (Món ăn)",
  staffTab: "Nhân viên (Dịch vụ)",
  timeLabel: "Thời gian",
  deliveryPersonLabel: "Người giao",
  performerLabel: "Người thực hiện",
  requestedAtLabel: "Yêu cầu lúc",
  completedAtLabel: "Hoàn tất lúc",
  orderDetailsTitle: "Chi tiết Đơn hàng",
  // New keys - Vietnamese
  save: "Lưu",
  delete: "Xóa",
  edit: "Sửa",
  errorPrefix: "Lỗi",
  unknownError: "Đã xảy ra lỗi không xác định.",
  confirmDeleteTitle: "Xác nhận xóa",
  pleaseLogin: "Vui lòng đăng nhập.",
  noPermission: "Bạn không có quyền quản trị.",
  confirmDeleteBtn: "Xác nhận Xóa",
  noNameSet: "Chưa đặt tên",
  notePrefix: "Ghi chú",
  systemTitle: "HỆ THỐNG GỌI MÓN TẠI PHÒNG",
  username: "Tên đăng nhập",
  password: "Mật khẩu",
  loginButton: "ĐĂNG NHẬP",
  debugMode: "Chế độ Debug (Đăng nhập nhanh)",
  addAccountTitle: "Thêm Tài Khoản Mới",
  editAccountTitle: "Sửa Tài Khoản",
  loginEmail: "Email đăng nhập",
  passwordMinLength: "Mật khẩu (Tối thiểu 6 ký tự)",
  validEmail: "Vui lòng nhập email hợp lệ",
  validPassword: "Mật khẩu phải từ 6 ký tự trở lên",
  validName: "Vui lòng nhập tên",
  validRoom: "Vui lòng nhập số phòng",
  validStation: "Vui lòng chọn trạm",
  serverError: "Lỗi không xác định từ Server",
  roomNumberInput: "Số phòng (VD: 102)",
  selectStationLabel: "Chọn Trạm Bếp",
  changePasswordLabel: "Đổi mật khẩu mới (Để trống nếu không đổi)",
  changePasswordHelper: "Nhập mật khẩu mới nếu nhân viên quên.",
  deleteAccountConfirm: "Bạn có chắc chắn muốn xóa tài khoản này không?",
  deleteAccountSuccess: "Đã xóa tài khoản thành công.",
  systemError: "Lỗi hệ thống",
  roomDeviceLabel: "Thiết bị phòng",
  checkoutRoomTitle: "Trả phòng",
  checkoutRoomConfirm: "Hành động này sẽ xóa toàn bộ lịch sử đơn hàng và yêu cầu dịch vụ của phòng này. Bạn có chắc chắn muốn tiếp tục?",
  checkoutRoomSuccess: "dọn dẹp lịch sử thành công",
  confirmCheckoutBtn: "Xác nhận Trả phòng",
  editAccountTooltip: "Sửa tài khoản",
  deleteAccountTooltip: "Xóa tài khoản",
  checkoutRoomTooltip: "Trả phòng (Xóa lịch sử)",
  editCategory: "Sửa Danh Mục",
  categoryNameLang: "Tên danh mục",
  descriptionLang: "Mô tả",
  deleteCategoryConfirm: "Xóa danh mục này?",
  cannotDeleteCategory: "Không thể xóa! Có món ăn thuộc danh mục này.",
  editStation: "Sửa Trạm Bếp",
  stationNameLang: "Tên trạm",
  validStationName: "Vui lòng nhập tên trạm",
  aiTranslateTooltip: "AI Dịch sang tiếng Anh",
  deleteStationConfirm: "Bạn có chắc muốn xóa Trạm bếp này? Không thể xóa nếu đang có Món ăn hoặc Tài khoản Bếp thuộc về trạm này.",
  stationDeleted: "Đã xóa trạm bếp",
  cannotDeleteStation: "Không thể xóa! Có món ăn hoặc tài khoản đang liên kết với trạm bếp này.",
  editStationTooltip: "Sửa trạm bếp",
  deleteStationTooltip: "Xóa trạm bếp",
  editTag: "Sửa Thông Tin Thẻ",
  tagNameLang: "Tên thẻ",
  tagTypeLabel: "Phân loại",
  allergyType: "Dị ứng",
  weatherType: "Thời tiết",
  timeType: "Buổi trong ngày",
  tasteType: "Khẩu vị",
  deleteTagConfirm: "Xóa thẻ này?",
  addItemTitle: "Thêm Món Mới",
  editItem: "Sửa Món Ăn",
  itemNameLang: "Tên món",
  priceLabel: "Giá tiền",
  cookTimeLabel: "Thời gian nấu (phút)",
  categoryLabel: "Danh mục",
  stationLabel: "Trạm bếp",
  descriptionFieldLang: "Mô tả",
  attachTag: "Gắn Thẻ:",
  availabilityStatus: "Trạng thái mở bán",
  chooseImage: "Chọn ảnh",
  saveItem: "Lưu Món Ăn",
  deleteItemConfirm: "Bạn có chắc chắn muốn xóa món này khỏi Menu?",
  manageToppingTooltip: "Quản lý Topping",
  customization: "Tùy chỉnh",
  addNewGroup: "Thêm nhóm mới",
  noCustomizations: "Chưa có tùy chỉnh nào cho món này.\nNhấn \"Thêm nhóm mới\" để bắt đầu.",
  requiredYes: "Có",
  requiredNo: "Không",
  maxSelect: "Chọn tối đa",
  addOption: "Thêm lựa chọn",
  addGroupTitle: "Thêm Nhóm Tùy Chọn",
  editGroupTitle: "Sửa Nhóm",
  groupNameLang: "Tên nhóm",
  minSelectLabel: "Chọn tối thiểu (1: Bắt buộc, 0: Tùy chọn)",
  maxSelectLabel: "Chọn tối đa",
  addOptionTitle: "Thêm Lựa Chọn",
  editOptionTitle: "Sửa Lựa Chọn",
  optionNameLang: "Tên",
  extraPrice: "Giá cộng thêm",
  deleteGroupTitle: "Xóa Nhóm?",
  deleteGroupConfirm: "Mọi lựa chọn bên trong nhóm này cũng sẽ bị xóa. Bạn chắc chắn chứ?",
  deleteOptionTitle: "Xóa Lựa Chọn?",
  deleteOptionConfirm: "Bạn muốn xóa vĩnh viễn lựa chọn này?",
  errorSaveGroup: "Lỗi khi lưu nhóm",
  errorDeleteGroup: "Lỗi khi xóa nhóm",
  errorSaveOption: "Lỗi khi lưu lựa chọn",
  errorDeleteOption: "Lỗi khi xóa lựa chọn",
  updateError: "Lỗi cập nhật",
  stationNotAssigned: "Tài khoản chưa được gán trạm.",
  stationNotExist: "Trạm không tồn tại.",
  loadStationError: "Lỗi tải trạm",
  empty: "Trống",
  warningTitle: "Cảnh báo",
  notCookingTime: "Chưa đến giờ nấu.",
  primaryNotDone: "Món chính chưa xong.",
  continueQuestion: "Tiếp tục?",
  stillCook: "VẪN NẤU",
  deliverySuccess: "Giao món thành công!",
  taskDone: "Hoàn tất nhiệm vụ!",
  viewAction: "XEM",
  dishReady: "Một món ăn đã nấu xong!",
  roomServiceNotify: "yêu cầu dịch vụ!",
  authError: "Lỗi xác thực.",
  loadDataError: "Lỗi tải dữ liệu",
  noRequests: "Hiện không có yêu cầu nào.",
  noHistory: "Chưa có lịch sử.",
  specialInstructions: "Ghi chú thêm...",
  loadMenuError: "Lỗi tải thực đơn",
  supportQuestion: "Bạn cần hỗ trợ gì?",
  supportHint: "Ví dụ: Mượn thêm máy sấy, hỏng điều hòa...",
  roomCleaningCalled: "Đã gọi dọn phòng!",
  staffCalled: "Đã gọi nhân viên!",
  roomServiceLabel: "Dịch vụ tại phòng:",
  menuItemFallback: "Món ăn",
  errorTranslate: "Lỗi dịch",
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
  adminPanelTitle: "Admin Control Panel",
  accountsTab: "Accounts",
  stationsTab: "Stations",
  categoriesTab: "Categories",
  menuTab: "Menu",
  tagsTab: "Tags",
  adminHistoryTab: "History",
  qrCodeTab: "Room QR Code",
  generateQrTitle: "Generate Auto-Login QR Code",
  selectRoom: "Select Room Number",
  selectDuration: "QR Code Duration",
  generateQrBtn: "Generate QR Code",
  qrCodeCreated: "QR Code for Room",
  qrExpiresAt: "Expires at",
  printQr: "Print QR Code",
  copyQrLink: "Copy Link",
  revokeQr: "Revoke QR",
  qrExpiredTitle: "QR Code Expired",
  qrExpiredMessage: "The usage time for this room QR code has ended. Please contact reception for a new QR code.",
  addAccount: "Add Account",
  addStation: "Add Station",
  addCategory: "Add Category",
  addItem: "Add New Item",
  addTag: "Add New Tag",
  manageAccounts: "Account Management",
  manageStations: "Station Management",
  manageCategories: "Category Management",
  manageMenu: "Menu Management",
  manageTags: "Tag Management",
  adminRole: "Admin",
  roomRole: "Room",
  stationRole: "Kitchen",
  waiterRole: "Waiter",
  displayName: "Display Name",
  roleLabel: "Role",
  actionsLabel: "Actions",
  allTab: "All",
  descriptionLabel: "Description",
  statusLabel: "Status",
  infoLabel: "Information",
  systemHistoryTitle: "System Activity History",
  ordersTab: "Orders (Room)",
  kitchenTab: "Kitchen (Dishes)",
  staffTab: "Staff (Services)",
  timeLabel: "Time",
  deliveryPersonLabel: "Delivery Person",
  performerLabel: "Performer",
  requestedAtLabel: "Requested at",
  completedAtLabel: "Completed at",
  orderDetailsTitle: "Order Details",
  // New keys - English
  save: "Save",
  delete: "Delete",
  edit: "Edit",
  errorPrefix: "Error",
  unknownError: "An unknown error occurred.",
  confirmDeleteTitle: "Confirm Delete",
  pleaseLogin: "Please sign in.",
  noPermission: "You do not have admin permissions.",
  confirmDeleteBtn: "Confirm Delete",
  noNameSet: "No name set",
  notePrefix: "Notes",
  systemTitle: "IN-ROOM DINING SYSTEM",
  username: "Username",
  password: "Password",
  loginButton: "SIGN IN",
  debugMode: "Debug Mode (Quick Login)",
  addAccountTitle: "Add New Account",
  editAccountTitle: "Edit Account",
  loginEmail: "Login Email",
  passwordMinLength: "Password (Minimum 6 characters)",
  validEmail: "Please enter a valid email",
  validPassword: "Password must be at least 6 characters",
  validName: "Please enter a name",
  validRoom: "Please enter a room number",
  validStation: "Please select a station",
  serverError: "Unknown server error",
  roomNumberInput: "Room Number (e.g. 102)",
  selectStationLabel: "Select Station",
  changePasswordLabel: "Change Password (Leave empty to keep current)",
  changePasswordHelper: "Enter new password if staff forgot.",
  deleteAccountConfirm: "Are you sure you want to delete this account?",
  deleteAccountSuccess: "Account deleted successfully.",
  systemError: "System error",
  roomDeviceLabel: "Room Device",
  checkoutRoomTitle: "Checkout Room",
  checkoutRoomConfirm: "This will delete all order history and service requests for this room. Are you sure you want to continue?",
  checkoutRoomSuccess: "history cleared successfully",
  confirmCheckoutBtn: "Confirm Checkout",
  editAccountTooltip: "Edit account",
  deleteAccountTooltip: "Delete account",
  checkoutRoomTooltip: "Checkout Room (Clear history)",
  editCategory: "Edit Category",
  categoryNameLang: "Category Name",
  descriptionLang: "Description",
  deleteCategoryConfirm: "Delete this category?",
  cannotDeleteCategory: "Cannot delete! Menu items belong to this category.",
  editStation: "Edit Station",
  stationNameLang: "Station Name",
  validStationName: "Please enter a station name",
  aiTranslateTooltip: "AI Translate to English",
  deleteStationConfirm: "Are you sure you want to delete this station? Cannot delete if menu items or accounts are linked to it.",
  stationDeleted: "Station deleted",
  cannotDeleteStation: "Cannot delete! Menu items or accounts are linked to this station.",
  editStationTooltip: "Edit station",
  deleteStationTooltip: "Delete station",
  editTag: "Edit Tag",
  tagNameLang: "Tag Name",
  tagTypeLabel: "Type / Classification",
  allergyType: "Allergy",
  weatherType: "Weather",
  timeType: "Time of Day",
  tasteType: "Taste / Cuisine",
  deleteTagConfirm: "Delete this tag?",
  addItemTitle: "Add New Item",
  editItem: "Edit Item",
  itemNameLang: "Item Name",
  priceLabel: "Price",
  cookTimeLabel: "Cook Time (mins)",
  categoryLabel: "Category",
  stationLabel: "Station",
  descriptionFieldLang: "Description",
  attachTag: "Tags:",
  availabilityStatus: "Availability",
  chooseImage: "Choose Image",
  saveItem: "Save Item",
  deleteItemConfirm: "Are you sure you want to remove this item from the menu?",
  manageToppingTooltip: "Manage Toppings",
  customization: "Customization",
  addNewGroup: "Add new group",
  noCustomizations: "No customizations for this item.\nClick \"Add new group\" to start.",
  requiredYes: "Yes",
  requiredNo: "No",
  maxSelect: "Max select",
  addOption: "Add option",
  addGroupTitle: "Add Option Group",
  editGroupTitle: "Edit Group",
  groupNameLang: "Group Name",
  minSelectLabel: "Min select (1: Required, 0: Optional)",
  maxSelectLabel: "Max select",
  addOptionTitle: "Add Option",
  editOptionTitle: "Edit Option",
  optionNameLang: "Name",
  extraPrice: "Extra Price",
  deleteGroupTitle: "Delete Group?",
  deleteGroupConfirm: "All options within this group will also be deleted. Are you sure?",
  deleteOptionTitle: "Delete Option?",
  deleteOptionConfirm: "Do you want to permanently delete this option?",
  errorSaveGroup: "Error saving group",
  errorDeleteGroup: "Error deleting group",
  errorSaveOption: "Error saving option",
  errorDeleteOption: "Error deleting option",
  updateError: "Update error",
  stationNotAssigned: "Account is not assigned to a station.",
  stationNotExist: "Station does not exist.",
  loadStationError: "Error loading station",
  empty: "Empty",
  warningTitle: "Warning",
  notCookingTime: "It's not time to cook yet.",
  primaryNotDone: "Primary dish not done yet.",
  continueQuestion: "Continue?",
  stillCook: "COOK ANYWAY",
  deliverySuccess: "Delivery successful!",
  taskDone: "Task completed!",
  viewAction: "VIEW",
  dishReady: "A dish is ready!",
  roomServiceNotify: "requested service!",
  authError: "Authentication error.",
  loadDataError: "Error loading data",
  noRequests: "No requests at the moment.",
  noHistory: "No history yet.",
  specialInstructions: "Special instructions...",
  loadMenuError: "Error loading menu",
  supportQuestion: "What do you need help with?",
  supportHint: "E.g. Need extra towels, AC not working...",
  roomCleaningCalled: "Room cleaning requested!",
  staffCalled: "Staff called!",
  roomServiceLabel: "Room services:",
  menuItemFallback: "Menu Item",
  errorTranslate: "Translation error",
);

class LocaleNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = getSavedLocale();
    if (saved == 'vi' || saved == 'en') {
      return saved!;
    }
    return 'vi'; // Mặc định là Tiếng Việt
  }

  void setLocale(String code) {
    state = code;
    saveSavedLocale(code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

final l10nProvider = Provider<AppDictionary>((ref) {
  final locale = ref.watch(localeProvider);
  return (locale == 'vi') ? viDict : enDict;
});
