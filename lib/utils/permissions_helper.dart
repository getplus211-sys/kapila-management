import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  // Media permissions
  static Future<bool> requestMediaPermission() async {
    if (await Permission.photos.isGranted) return true;
    
    final status = await Permission.photos.request();
    return status.isGranted;
  }
  
  // Camera permission
  static Future<bool> requestCameraPermission() async {
    if (await Permission.camera.isGranted) return true;
    
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  // Contacts permission
  static Future<bool> requestContactsPermission() async {
    if (await Permission.contacts.isGranted) return true;
    
    final status = await Permission.contacts.request();
    return status.isGranted;
  }
  
  // Storage permission (Android < 13)
  static Future<bool> requestStoragePermission() async {
    if (await Permission.storage.isGranted) return true;
    
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}