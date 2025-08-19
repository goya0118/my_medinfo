import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../models/drug_info.dart';
import 'drug_api_service.dart';

class BarcodeProcessor {
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(seconds: 3);

  /// ML Kit 바코드 결과를 처리해야 하는지 확인
  bool shouldProcessBarcode(List<Barcode> barcodes) {
    // 바코드 데이터 안전하게 추출
    if (barcodes.isEmpty) return false;
    
    final barcode = barcodes.first;
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

  /// 단일 바코드 문자열 처리 (CameraManager에서 사용)
  bool shouldProcessBarcodeString(String code) {
    if (code.isEmpty) return false;

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

  /// 의약품 정보 조회
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

  /// ML Kit 바코드 리스트에서 첫 번째 바코드 값 추출
  String? extractBarcodeValue(List<Barcode> barcodes) {
    if (barcodes.isEmpty) return null;
    
    final barcode = barcodes.first;
    return barcode.rawValue;
  }

  /// 바코드 타입 정보 추출 (디버깅용)
  String getBarcodeTypeInfo(List<Barcode> barcodes) {
    if (barcodes.isEmpty) return 'No barcode';
    
    final barcode = barcodes.first;
    
    // 간단하고 안전한 방식으로 타입 정보 반환
    return '${barcode.type.toString().split('.').last} (${barcode.format.toString().split('.').last})';
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

  /// 스캔 쿨다운 시간 설정 (필요시)
  void setScanCooldown(Duration cooldown) {
    // 현재는 상수로 되어있지만, 필요시 동적으로 변경 가능하도록 확장
  }
}