import 'package:flutter/foundation.dart';

@immutable
sealed class AppError {
  final String message;
  const AppError(this.message);

  const factory AppError.api(String message, [int? statusCode]) = ApiError;
  const factory AppError.network(String message) = NetworkError;
  factory AppError.unexpected(Object error, [StackTrace? stackTrace]) =
      UnexpectedError;
}

final class ApiError extends AppError {
  final int? statusCode;
  const ApiError(super.message, [this.statusCode]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}

final class NetworkError extends AppError {
  const NetworkError(super.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

final class UnexpectedError extends AppError {
  final Object originalError;
  final StackTrace? stackTrace;

  UnexpectedError(this.originalError, [this.stackTrace])
    : super(originalError.toString());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnexpectedError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
