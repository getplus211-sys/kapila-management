import 'dart:io';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class MediaUtil {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        return await Permission.photos.request().isGranted;
      }
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return false;
  }

  static Future<bool> saveImageToGallery(String path) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) return false;
      
      await Gal.putImage(path);
      return true;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return false;
    }
  }

  static Future<bool> saveVideoToGallery(String path) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) return false;
      
      await Gal.putVideo(path);
      return true;
    } catch (e) {
      debugPrint('Error saving video: $e');
      return false;
    }
  }

  static String getMediaType(String? url) {
    if (url == null) return 'unknown';
    
    final extension = url.split('.').last.toLowerCase();
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'image';
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
      return 'video';
    } else if (['mp3', 'wav', 'm4a', 'aac'].contains(extension)) {
      return 'audio';
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(extension)) {
      return 'document';
    }
    
    return 'file';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}