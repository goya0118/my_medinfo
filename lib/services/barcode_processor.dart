import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../models/drug_info.dart';
import 'drug_api_service.dart';

class BarcodeProcessor {
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(seconds: 3);

  bool shouldProcessBarcode(BarcodeCapture capture) {
    // 바코드 데이터 안전하게 추출
    if (capture.barcodes.isEmpty) return false;
    
    final barcode = capture.barcodes.first;
    final code = barcode.rawValue;
    
    if (code == null || code.isEmpty) return false;

    // 중복 스캔 방지
    final now = DateTime.now();
    if (_lastScannedBarcode == code && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!) < _scanCooldown) {
      return false;
    }

    _lastScannedBarcode = code;
    _lastScanTime = now;
    
    print('바코드 스캔됨: $code');
    return true;
  }

  String? get lastScannedBarcode => _lastScannedBarcode;

  Future<DrugInfo?> fetchDrugInfo(String barcode) async {
    try {
      print('API 호출 시작: $barcode');
      final drugInfo = await DrugApiService.getDrugInfo(barcode);
      
      if (drugInfo != null) {
        _showToast("의약품 정보를 찾았습니다!", Colors.green);
      } else {
        _showToast("의약품 정보를 찾을 수 없습니다", Colors.orange);
      }
      
      return drugInfo;
    } catch (e) {
      print('API 호출 오류: $e');
      _showToast("API 호출 중 오류가 발생했습니다", Colors.red);
      rethrow;
    }
  }

  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
    );
  }

  void reset() {
    _lastScannedBarcode = null;
    _lastScanTime = null;
  }
}