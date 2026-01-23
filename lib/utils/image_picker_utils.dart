import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerUtils {
  static final ImagePicker _picker = ImagePicker();

  /// Simple direct method to pick an image using file_picker for gallery and image_picker for camera
  static Future<File?> pickImageSimple(ImageSource source) async {
    try {
      // For gallery - use file_picker which handles permissions internally
      if (source == ImageSource.gallery) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          allowCompression: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = File(result.files.single.path!);
          print('✅ Image picked successfully from gallery: ${file.path}');
          return file;
        }
      } else if (source == ImageSource.camera) {
        // For camera, we still need to check camera permission and use image_picker
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          print('❌ Camera permission denied');
          return null;
        }

        // Use image_picker for camera
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          print('✅ Image picked successfully from camera: ${file.path}');
          return file;
        }
      }
    } catch (e) {
      print('❌ Error in pickImageSimple: $e');
    }
    return null;
  }

  /// Show a bottom sheet to select image source
  static Future<File?> showImageSourceBottomSheet(BuildContext context) async {
    final File? selectedImage = await showModalBottomSheet<File?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        final theme = Theme.of(context);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar at top
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Text(
                    'Select Image Source',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gallery option
                  InkWell(
                    onTap: () async {
                      final File? pickedImage = await pickImageSimple(
                        ImageSource.gallery,
                      );
                      Navigator.pop(context, pickedImage);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.photo_library_rounded,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Photo Gallery',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Select from your saved photos',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Camera option
                  InkWell(
                    onTap: () async {
                      // Check camera permission
                      final status = await Permission.camera.request();
                      if (status.isDenied || status.isPermanentlyDenied) {
                        Navigator.pop(context, null);
                        _showPermissionDialog(context, 'camera');
                        return;
                      }

                      final File? pickedImage = await pickImageSimple(
                        ImageSource.camera,
                      );
                      Navigator.pop(context, pickedImage);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camera',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Take a new photo',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );

    return selectedImage;
  }

  /// Show permission denied dialog
  static void _showPermissionDialog(
    BuildContext context,
    String permissionType,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text('Please grant $permissionType permission to continue.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Pick image directly from gallery without bottom sheet
  static Future<File?> pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        print('✅ Image picked successfully from gallery: ${file.path}');
        return file;
      }
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
    }
    return null;
  }

  /// Pick image directly from camera without bottom sheet
  static Future<File?> pickImageFromCamera() async {
    try {
      // Check camera permission
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        print('❌ Camera permission denied');
        return null;
      }

      // Use image_picker for camera
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        print('✅ Image picked successfully from camera: ${file.path}');
        return file;
      }
    } catch (e) {
      print('❌ Error picking image from camera: $e');
    }
    return null;
  }
}
