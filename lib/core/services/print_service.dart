import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/l10n_utils.dart';

class PrintService {
  static Future<void> printOrderBill({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> tickets,
    required List<dynamic> menuItems,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    double totalBill = 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(thickness: 2),
              pw.Center(
                child: pw.Text('KHÁCH SẠN INROOM DINING', style: pw.TextStyle(font: fontBold, fontSize: 16)),
              ),
              pw.Center(
                child: pw.Text('123 Ninh Kiều, TP. Cần Thơ', style: pw.TextStyle(font: font, fontSize: 12)),
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text('PHIẾU TẠM TÍNH', style: pw.TextStyle(font: fontBold, fontSize: 14)),
              ),
              pw.Center(
                child: pw.Text('(IN-ROOM DINING)', style: pw.TextStyle(font: font, fontSize: 12)),
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Text('Số HĐ: #${order['id'].toString().substring(0, 8).toUpperCase()}', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Text('Ngày : ${DateFormat('HH:mm:ss dd/MM/yyyy').format(DateTime.parse(order['created_at']).toLocal())}', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Text('Phòng: ${order['room_number']}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              if (order['notes'] != null && order['notes'].toString().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text('Ghi chú: ${order['notes']}', style: pw.TextStyle(font: font, fontSize: 12)),
                ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              // Header Row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('TÊN MÓN', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                  pw.Expanded(flex: 1, child: pw.Text('SL', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 11))),
                  pw.Expanded(flex: 3, child: pw.Text('Đơn Giá', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 11))),
                  pw.Expanded(flex: 3, child: pw.Text('Thành tiền', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 11))),
                ],
              ),
              pw.SizedBox(height: 4),
              // List of items
              ...tickets.map((t) {
                final match = menuItems.where((m) => m.id == t['item_id']);
                final menuItem = match.isNotEmpty ? match.first : null;
                
                String itemName = 'Unknown';
                double basePrice = 0;

                if (menuItem != null) {
                  itemName = menuItem.nameMap['vi'] ?? menuItem.nameMap['en'] ?? 'Unknown';
                  basePrice = menuItem.price;
                } else if (t['menu_items'] != null) {
                  itemName = L10nUtils.getL10n(t['menu_items']['name'], 'vi');
                  basePrice = double.tryParse(t['menu_items']['price']?.toString() ?? '0') ?? 0.0;
                }
                
                final List mods = t['selected_modifiers'] as List? ?? [];
                double modPrice = 0;
                for (var m in mods) {
                  modPrice += double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;
                }
                
                final double itemPrice = basePrice + modPrice;
                final double itemTotal = itemPrice * (t['quantity'] as int? ?? 1);
                totalBill += itemTotal;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(flex: 4, child: pw.Text(itemName, style: pw.TextStyle(font: font, fontSize: 11))),
                          pw.Expanded(flex: 1, child: pw.Text('${t['quantity']}', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 11))),
                          pw.Expanded(flex: 3, child: pw.Text(NumberFormat('#,###', 'vi_VN').format(itemPrice), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 11))),
                          pw.Expanded(flex: 3, child: pw.Text(NumberFormat('#,###', 'vi_VN').format(itemTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 11))),
                        ],
                      ),
                      if (mods.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, top: 2),
                          child: pw.Text('+ ${mods.map((m) => m['modifier_name'] ?? m['rawModifier']).join(', ')}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        ),
                      if (t['notes'] != null && t['notes'].toString().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, top: 2),
                          child: pw.Text('(${t['notes']})', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
                        ),
                    ],
                  ),
                );
              }),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TỔNG THANH TOÁN:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  pw.Text(NumberFormat('#,###', 'vi_VN').format(totalBill), style: pw.TextStyle(font: fontBold, fontSize: 14)),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Hình thức TT: ', style: pw.TextStyle(font: font, fontSize: 11)),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('[ ] Tiền mặt   [ ] Thẻ', style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text('[ ] Tính vào tiền phòng', style: pw.TextStyle(font: font, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text('XÁC NHẬN CỦA KHÁCH HÀNG', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              ),
              pw.Center(
                child: pw.Text('(Vui lòng ký và ghi rõ họ tên nếu chọn\nhình thức tính vào tiền phòng)', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 11)),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Tên khách: ...........................................', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text('Số phòng: ............................................', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text('Chữ ký:', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 40),
              pw.Text('......................................................', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Cảm ơn & Chúc quý khách ngon miệng!', style: pw.TextStyle(font: font, fontSize: 11, fontStyle: pw.FontStyle.italic)),
              ),
              pw.Divider(thickness: 2),
            ],
          );
        },
      ),
    );

    // Bắt đầu in
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Order_${order['room_number']}_${order['id']}',
      format: PdfPageFormat.roll80,
    );
  }
}
