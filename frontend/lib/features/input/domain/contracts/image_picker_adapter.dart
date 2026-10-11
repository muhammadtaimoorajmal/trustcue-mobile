import 'package:image_picker/image_picker.dart';

/// Contract abstracting platform image picking and lost data retrieval.
abstract class ImagePickerAdapter {
  /// Invokes the system photo picker to select a single image.
  Future<XFile?> pickImage();

  /// Retrieves any pending picker result that was interrupted by Android process death.
  Future<LostDataResponse?> retrieveLostData();
}
