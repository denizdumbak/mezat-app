import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'auction_failure.dart';

/// A photo chosen on the device, ready to upload.
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;

  /// One of the types the auction-images bucket accepts.
  final String contentType;
  final String extension;
}

/// Content types the auction-images bucket accepts, by file extension.
const _contentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

/// The bucket's content type for [fileName], or null if it is not accepted.
String? photoContentType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _contentTypes[fileName.substring(dot + 1).toLowerCase()];
}

/// Behind a provider so widget tests can pick a photo without a gallery.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => const GalleryPhotoPicker(),
);

abstract interface class PhotoPicker {
  /// Null when the user closes the picker without choosing. Throws
  /// [AuctionFailure.unsupportedImage] for a file type the bucket refuses.
  Future<PickedPhoto?> pick();
}

class GalleryPhotoPicker implements PhotoPicker {
  const GalleryPhotoPicker();

  @override
  Future<PickedPhoto?> pick() async {
    // Scaled down on the phone: a 12 MP camera photo would exceed the 5 MB
    // bucket limit and is far larger than any screen shows it. (Desktop
    // platforms ignore these options; the bucket limit still applies.)
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    final contentType = photoContentType(file.name);
    if (contentType == null) throw AuctionFailure.unsupportedImage;
    return PickedPhoto(
      bytes: await file.readAsBytes(),
      contentType: contentType,
      extension: file.name
          .substring(file.name.lastIndexOf('.') + 1)
          .toLowerCase(),
    );
  }
}
