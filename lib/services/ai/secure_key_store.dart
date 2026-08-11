import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// API Key 安全存储抽象。
///
/// 生产环境使用 [WindowsDpapiKeyStore]（Windows DPAPI），
/// 测试环境可注入内存实现，避免依赖原生加密。
abstract class SecureKeyStore {
  /// 判断 [stored] 是否为已加密的存储值。
  bool isEncrypted(String stored);

  /// 加密明文并返回可落盘的字符串。
  String protect(String plain);

  /// 解密存储值；若是未加密的旧数据则原样返回。
  String unprotect(String stored);
}

/// 不加密的空实现：用于测试或无法使用系统加密的环境。
class NoopSecureKeyStore implements SecureKeyStore {
  const NoopSecureKeyStore();

  @override
  bool isEncrypted(String stored) => false;

  @override
  String protect(String plain) => plain;

  @override
  String unprotect(String stored) => stored;
}

class SecureKeyStoreException implements Exception {
  const SecureKeyStoreException(this.message);

  final String message;

  @override
  String toString() => 'SecureKeyStoreException: $message';
}

/// Windows DPAPI 加密存储。
///
/// 使用 crypt32.dll 的 CryptProtectData / CryptUnprotectData，
/// 密文仅可由“当前 Windows 用户 + 当前机器”解密，适合本机敏感配置。
class WindowsDpapiKeyStore implements SecureKeyStore {
  WindowsDpapiKeyStore()
      : _crypt32 = DynamicLibrary.open('crypt32.dll'),
        _kernel32 = DynamicLibrary.open('kernel32.dll') {
    _cryptProtectData = _crypt32
        .lookupFunction<CryptProtectDataNative, CryptProtectDataDart>(
          'CryptProtectData',
        );
    _cryptUnprotectData = _crypt32
        .lookupFunction<CryptUnprotectDataNative, CryptUnprotectDataDart>(
          'CryptUnprotectData',
        );
    _getLastError = _kernel32
        .lookupFunction<GetLastErrorNative, GetLastErrorDart>(
          'GetLastError',
        );
    _localFree = _kernel32
        .lookupFunction<LocalFreeNative, LocalFreeDart>('LocalFree');
  }

  /// 存储值前缀：`dpapi:v1:<base64>`。
  static const String prefix = 'dpapi:v1:';

  /// CRYPTPROTECT_UI_FORBIDDEN：禁止弹出系统 UI，静默加解密。
  static const int _uiForbidden = 0x01;

  final DynamicLibrary _crypt32;
  final DynamicLibrary _kernel32;
  late final CryptProtectDataDart _cryptProtectData;
  late final CryptUnprotectDataDart _cryptUnprotectData;
  late final GetLastErrorDart _getLastError;
  late final LocalFreeDart _localFree;

  @override
  bool isEncrypted(String stored) => stored.startsWith(prefix);

  @override
  String protect(String plain) {
    if (plain.isEmpty) return '';
    final protected = _protect(utf8.encode(plain));
    return '$prefix${base64Encode(protected)}';
  }

  @override
  String unprotect(String stored) {
    if (!isEncrypted(stored)) return stored; // 旧版明文数据原样返回
    final raw = base64Decode(stored.substring(prefix.length));
    return utf8.decode(_unprotect(raw));
  }

  Uint8List _protect(List<int> input) {
    final inBlob = calloc<DataBlob>();
    final outBlob = calloc<DataBlob>();
    final inBytes = calloc<Uint8>(input.length);
    try {
      inBytes.asTypedList(input.length).setAll(0, input);
      inBlob.ref
        ..cbData = input.length
        ..pbData = inBytes;
      final ok = _cryptProtectData(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _uiForbidden,
        outBlob,
      );
      if (ok == 0) {
        throw SecureKeyStoreException(
          'CryptProtectData 失败（Win32 错误码 ${_getLastError()}）',
        );
      }
      return Uint8List.fromList(
        outBlob.ref.pbData.asTypedList(outBlob.ref.cbData),
      );
    } finally {
      if (outBlob.ref.pbData != nullptr) {
        _localFree(outBlob.ref.pbData.cast<Void>());
      }
      calloc.free(inBytes);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  Uint8List _unprotect(List<int> input) {
    if (input.isEmpty) return Uint8List(0);
    final inBlob = calloc<DataBlob>();
    final outBlob = calloc<DataBlob>();
    final inBytes = calloc<Uint8>(input.length);
    try {
      inBytes.asTypedList(input.length).setAll(0, input);
      inBlob.ref
        ..cbData = input.length
        ..pbData = inBytes;
      final ok = _cryptUnprotectData(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _uiForbidden,
        outBlob,
      );
      if (ok == 0) {
        throw SecureKeyStoreException(
          'CryptUnprotectData 失败（Win32 错误码 ${_getLastError()}）',
        );
      }
      return Uint8List.fromList(
        outBlob.ref.pbData.asTypedList(outBlob.ref.cbData),
      );
    } finally {
      if (outBlob.ref.pbData != nullptr) {
        _localFree(outBlob.ref.pbData.cast<Void>());
      }
      calloc.free(inBytes);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }
}

/// Windows DATA_BLOB（x64：DWORD 后按 8 字节对齐指针，偏移 8）。
final class DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef CryptProtectDataNative = Int32 Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef CryptProtectDataDart = int Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef CryptUnprotectDataNative = Int32 Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef CryptUnprotectDataDart = int Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef GetLastErrorNative = Uint32 Function();
typedef GetLastErrorDart = int Function();

typedef LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);
