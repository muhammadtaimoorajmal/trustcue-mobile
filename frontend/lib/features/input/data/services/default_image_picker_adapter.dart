import 'package:image_picker/image_picker.dart';

import '../../domain/contracts/image_picker_adapter.dart';

/// Default production implementation of [ImagePickerAdapter] using [ImagePicker].
class DefaultImagePickerAdapter implements ImagePickerAdapter {
  final ImagePicker _picker;

  DefaultImagePickerAdapter({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  @override
  Future<XFile?> pickImage() {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  @override
  Future<LostDataResponse?> retrieveLostData() {
    return _picker.retrieveLostData();
  }
}
