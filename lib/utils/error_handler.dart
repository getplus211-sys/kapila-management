import 'package:flutter/material.dart';
import 'app_constants.dart';

class AppError {
  final String message;
  final String? code;
  final dynamic originalError;

  AppError(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

class ErrorHandler {
  static AppError handleError(dynamic error) {
    if (error is AppError) return error;
    
    String message = AppConstants.serverError;
    String? code;

    if (error.toString().contains('Network')) {
      message = AppConstants.networkError;
      code = 'NETWORK_ERROR';
    } else if (error.toString().contains('auth')) {
      message = AppConstants.authError;
      code = 'AUTH_ERROR';
    } else if (error.toString().contains('upload')) {
      message = AppConstants.uploadError;
      code = 'UPLOAD_ERROR';
    }

    return AppError(message, code: code, originalError: error);
  }

  static void showError(BuildContext context, AppError error) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}