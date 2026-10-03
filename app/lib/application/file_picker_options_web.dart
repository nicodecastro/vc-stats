import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

WebOptions portableImportWebOptions() =>
    const FilePickerWebOptions(withData: true, cancelUploadOnWindowBlur: false);
